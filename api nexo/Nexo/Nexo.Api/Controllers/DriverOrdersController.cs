using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nexo.Api.Dtos.Orders;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/driver/orders")]
    [Authorize(Roles = "Driver")]
    public class DriverOrdersController : ControllerBase
    {
        private readonly IOrderService _orderService;
        private readonly IOrderRealtimeService _realtimeService;

        public DriverOrdersController(
            IOrderService orderService,
            IOrderRealtimeService realtimeService)
        {
            _orderService = orderService;
            _realtimeService = realtimeService;
        }

        [HttpGet("available")]
        public async Task<IActionResult> GetAvailable(CancellationToken cancellationToken)
        {
            try
            {
                var orders = await _orderService.GetAvailableDriverOrdersAsync(
                    GetAuthenticatedUserId()!.Value,
                    cancellationToken);

                return Ok(orders);
            }
            catch (InvalidOperationException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ex.Message);
            }
        }

        [HttpGet("active")]
        public async Task<IActionResult> GetActive(CancellationToken cancellationToken)
        {
            try
            {
                var orders = await _orderService.GetActiveDriverOrdersAsync(
                    GetAuthenticatedUserId()!.Value,
                    cancellationToken);

                return Ok(orders);
            }
            catch (InvalidOperationException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ex.Message);
            }
        }

        [HttpGet("stats")]
        public async Task<IActionResult> GetStats(CancellationToken cancellationToken)
        {
            try
            {
                var stats = await _orderService.GetDriverStatsAsync(
                    GetAuthenticatedUserId()!.Value,
                    cancellationToken);

                return Ok(stats);
            }
            catch (InvalidOperationException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ex.Message);
            }
        }

        [HttpPost("{orderId}/accept")]
        public async Task<IActionResult> Accept(string orderId, CancellationToken cancellationToken)
        {
            try
            {
                var updated = await _orderService.AcceptDriverOrderAsync(
                    orderId,
                    GetAuthenticatedUserId()!.Value,
                    cancellationToken);

                return updated ? NoContent() : NotFound("Pedido no disponible");
            }
            catch (InvalidOperationException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, ex.Message);
            }
        }

        [HttpPost("{orderId}/delivered")]
        public async Task<IActionResult> Delivered(
            string orderId,
            [FromBody] CompleteDeliveryRequest request,
            CancellationToken cancellationToken)
        {
            if (request == null)
                return BadRequest("El PIN de entrega es obligatorio.");

            try
            {
                var updated = await _orderService.CompleteDriverOrderAsync(
                    orderId,
                    GetAuthenticatedUserId()!.Value,
                    request.Pin,
                    cancellationToken);

                return updated ? NoContent() : NotFound("Pedido no encontrado");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("stream")]
        public async Task Stream(CancellationToken cancellationToken)
        {
            var userId = GetAuthenticatedUserId();
            if (!userId.HasValue)
            {
                Response.StatusCode = StatusCodes.Status401Unauthorized;
                return;
            }

            Response.Headers.Append("Cache-Control", "no-cache");
            Response.Headers.Append("X-Accel-Buffering", "no");
            Response.ContentType = "text/event-stream";

            await foreach (var message in _realtimeService.SubscribeDriverAsync(
                userId.Value,
                cancellationToken))
            {
                await Response.WriteAsync($"data: {message}\n\n", cancellationToken);
                await Response.Body.FlushAsync(cancellationToken);
            }
        }

        private int? GetAuthenticatedUserId()
        {
            var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User.FindFirstValue("sub");

            return int.TryParse(claimValue, out var userId) ? userId : null;
        }
    }
}
