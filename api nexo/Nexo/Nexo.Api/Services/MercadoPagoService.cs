using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Payments;
using Nexo.Api.Entitites;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Services
{
    public class MercadoPagoService
    {
        private const string ApiUrl = "https://api.mercadopago.com";
        private readonly AppDbContext _db;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly IOrderRealtimeService _realtimeService;
        private readonly ILogger<MercadoPagoService> _logger;

        public MercadoPagoService(
            AppDbContext db,
            IHttpClientFactory httpClientFactory,
            IConfiguration configuration,
            IOrderRealtimeService realtimeService,
            ILogger<MercadoPagoService> logger)
        {
            _db = db;
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _realtimeService = realtimeService;
            _logger = logger;
        }

        public async Task<MercadoPagoCheckoutResponse> CreateCheckoutAsync(
            string publicOrderId,
            int userId,
            CancellationToken cancellationToken)
        {
            var order = await _db.Orders
                .Include(o => o.Items)
                .Include(o => o.User)
                .FirstOrDefaultAsync(o => o.PublicId == publicOrderId && o.UserId == userId, cancellationToken)
                ?? throw new KeyNotFoundException("Pedido no encontrado.");

            if (order.PaymentStatus == "approved")
                throw new InvalidOperationException("Este pedido ya fue pagado.");

            if (!string.IsNullOrWhiteSpace(order.MercadoPagoPreferenceId) &&
                !string.IsNullOrWhiteSpace(order.MercadoPagoCheckoutUrl))
            {
                return new MercadoPagoCheckoutResponse
                {
                    CheckoutUrl = order.MercadoPagoCheckoutUrl,
                    PaymentStatus = order.PaymentStatus
                };
            }

            var accessToken = _configuration["MercadoPago:AccessToken"];
            if (string.IsNullOrWhiteSpace(accessToken))
                throw new InvalidOperationException("Mercado Pago no está configurado todavía.");

            var publicBaseUrl = (_configuration["App:PublicBaseUrl"] ?? "https://appnexo-production.up.railway.app")
                .TrimEnd('/');
            var payload = new
            {
                items = order.Items.Select(item => new
                {
                    title = item.ProductName,
                    quantity = item.Quantity,
                    unit_price = item.UnitPrice,
                    currency_id = "MXN"
                }),
                external_reference = order.PublicId,
                notification_url = $"{publicBaseUrl}/api/payments/mercadopago/webhook",
                back_urls = new
                {
                    success = $"{publicBaseUrl}/api/payments/mercadopago/return",
                    pending = $"{publicBaseUrl}/api/payments/mercadopago/return",
                    failure = $"{publicBaseUrl}/api/payments/mercadopago/return"
                },
                auto_return = "approved"
            };

            using var request = new HttpRequestMessage(HttpMethod.Post, $"{ApiUrl}/checkout/preferences")
            {
                Content = JsonContent.Create(payload)
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
            request.Headers.Add("X-Idempotency-Key", order.PublicId);

            var client = _httpClientFactory.CreateClient();
            using var response = await client.SendAsync(request, cancellationToken);
            var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Mercado Pago rechazó el checkout del pedido {OrderId}: {StatusCode} {Body}",
                    order.PublicId, (int)response.StatusCode, responseBody);
                throw new InvalidOperationException("No se pudo iniciar el pago con Mercado Pago. Intenta nuevamente.");
            }

            using var json = JsonDocument.Parse(responseBody);
            var root = json.RootElement;
            var checkoutUrl = GetString(root, "sandbox_init_point") ?? GetString(root, "init_point");
            var preferenceId = GetString(root, "id");
            if (string.IsNullOrWhiteSpace(checkoutUrl) || string.IsNullOrWhiteSpace(preferenceId))
                throw new InvalidOperationException("Mercado Pago no devolvió un checkout válido.");

            order.MercadoPagoPreferenceId = preferenceId;
            order.MercadoPagoCheckoutUrl = checkoutUrl;
            await _db.SaveChangesAsync(cancellationToken);
            return new MercadoPagoCheckoutResponse { CheckoutUrl = checkoutUrl, PaymentStatus = order.PaymentStatus };
        }

        public async Task ProcessPaymentNotificationAsync(string paymentId, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(paymentId)) return;
            var accessToken = _configuration["MercadoPago:AccessToken"];
            if (string.IsNullOrWhiteSpace(accessToken)) return;

            using var request = new HttpRequestMessage(HttpMethod.Get, $"{ApiUrl}/v1/payments/{Uri.EscapeDataString(paymentId)}");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
            var client = _httpClientFactory.CreateClient();
            using var response = await client.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode) return;

            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellationToken));
            var root = json.RootElement;
            var publicOrderId = GetString(root, "external_reference");
            var paymentStatus = GetString(root, "status")?.ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(publicOrderId) || string.IsNullOrWhiteSpace(paymentStatus)) return;

            var order = await _db.Orders.Include(o => o.Business)
                .FirstOrDefaultAsync(o => o.PublicId == publicOrderId, cancellationToken);
            if (order == null) return;

            order.MercadoPagoPaymentId = paymentId;
            order.PaymentStatus = paymentStatus;
            var paymentWasApproved = paymentStatus == "approved" && order.Status == "pending_payment";
            if (paymentWasApproved)
            {
                order.Status = "received";
            }
            await _db.SaveChangesAsync(cancellationToken);
            if (paymentWasApproved)
            {
                if (order.UserId.HasValue)
                    await _realtimeService.PublishCustomerOrderUpdatedAsync(order.UserId.Value, order.PublicId, order.Status);
                await _realtimeService.PublishRestaurantOrdersUpdatedAsync(order.Business.OwnerUserId, order.PublicId, order.Status);
                await _realtimeService.PublishDriverOrdersUpdatedAsync(order.PublicId, order.Status);
            }
        }

        private static string? GetString(JsonElement element, string propertyName) =>
            element.TryGetProperty(propertyName, out var property) && property.ValueKind == JsonValueKind.String
                ? property.GetString()
                : null;
    }
}
