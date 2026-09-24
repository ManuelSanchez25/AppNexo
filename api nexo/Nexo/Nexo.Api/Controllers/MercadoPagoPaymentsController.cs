using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nexo.Api.Services;
using System.Security.Claims;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/payments/mercadopago")]
    public class MercadoPagoPaymentsController : ControllerBase
    {
        private readonly MercadoPagoService _mercadoPagoService;
        public MercadoPagoPaymentsController(MercadoPagoService mercadoPagoService) => _mercadoPagoService = mercadoPagoService;

        [Authorize(Roles = "Client")]
        [HttpPost("orders/{orderId}/checkout")]
        public async Task<IActionResult> CreateCheckout(string orderId, CancellationToken cancellationToken)
        {
            var userIdValue = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(userIdValue, out var userId)) return Unauthorized();
            try
            {
                return Ok(await _mercadoPagoService.CreateCheckoutAsync(orderId, userId, cancellationToken));
            }
            catch (KeyNotFoundException ex) { return NotFound(ex.Message); }
            catch (InvalidOperationException ex) { return BadRequest(ex.Message); }
        }

        [AllowAnonymous]
        [HttpPost("webhook")]
        public async Task<IActionResult> Webhook([FromQuery(Name = "data.id")] string? paymentId, [FromQuery] string? id, CancellationToken cancellationToken)
        {
            await _mercadoPagoService.ProcessPaymentNotificationAsync(paymentId ?? id ?? string.Empty, cancellationToken);
            return Ok();
        }

        [AllowAnonymous]
        [HttpGet("return")]
        public IActionResult Return() => Content("El pago fue procesado. Puedes volver a AppNexo.", "text/plain");
    }
}
