using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using Nexo.Api.Data;

namespace Nexo.Api.Services
{
    public class PushNotificationService
    {
        private readonly AppDbContext _db;
        private readonly ILogger<PushNotificationService> _logger;
        private readonly FirebaseMessaging? _messaging;

        public PushNotificationService(
            AppDbContext db,
            IConfiguration configuration,
            ILogger<PushNotificationService> logger)
        {
            _db = db;
            _logger = logger;
            var serviceAccountJson = configuration["Firebase:ServiceAccountJson"];
            if (string.IsNullOrWhiteSpace(serviceAccountJson))
            {
                _logger.LogWarning("Firebase no está configurado: las notificaciones push no se enviarán.");
                return;
            }

            try
            {
                var app = FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromJson(serviceAccountJson)
                }, "nexo-push");
                _messaging = FirebaseMessaging.GetMessaging(app);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "No pudimos inicializar Firebase Admin.");
            }
        }

        public async Task SendOrderStatusAsync(int userId, string orderId, string status)
        {
            if (_messaging == null) return;

            var tokens = await _db.PushDevices
                .Where(d => d.UserId == userId)
                .Select(d => d.Token)
                .ToListAsync();
            if (tokens.Count == 0) return;

            var (title, body) = StatusMessage(status);
            try
            {
                var response = await _messaging.SendEachForMulticastAsync(new MulticastMessage
                {
                    Tokens = tokens,
                    Notification = new Notification { Title = title, Body = body },
                    Data = new Dictionary<string, string> { ["orderId"] = orderId, ["status"] = status }
                });

                if (response.FailureCount > 0)
                    _logger.LogWarning("Firebase no entregó {Count} notificaciones del pedido {OrderId}.", response.FailureCount, orderId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "No pudimos enviar la notificación del pedido {OrderId}.", orderId);
            }
        }

        private static (string Title, string Body) StatusMessage(string status) => status switch
        {
            "preparing" => ("Tu pedido está en preparación", "El negocio ya está preparando tu pedido."),
            "ready" => ("Tu pedido está listo", "Un repartidor podrá recogerlo pronto."),
            "driver_assigned" => ("Repartidor asignado", "Tu pedido ya tiene repartidor."),
            "on_the_way" => ("Tu pedido va en camino", "Tu repartidor ya va hacia tu dirección."),
            "delivered" => ("Pedido entregado", "Tu pedido fue entregado. ¡Buen provecho!"),
            "cancelled" => ("Pedido cancelado", "Tu pedido fue cancelado. Revisa el detalle para conocer el motivo."),
            _ => ("Actualización de pedido", "Tu pedido cambió de estado.")
        };
    }
}
