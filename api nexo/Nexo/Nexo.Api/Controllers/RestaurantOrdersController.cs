using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nexo.Api.Dtos.Orders;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/restaurant/orders")]
    [Authorize(Roles = "Restaurant,Admin")]
    public class RestaurantOrdersController : ControllerBase
    {
        private readonly IOrderService _orderService;
        private readonly IOrderRealtimeService _realtimeService;

        public RestaurantOrdersController(
            IOrderService orderService,
            IOrderRealtimeService realtimeService)
        {
            _orderService = orderService;
            _realtimeService = realtimeService;
        }

        [HttpGet]
        public async Task<IActionResult> GetOrders(CancellationToken cancellationToken)
        {
            var orders = await _orderService.GetRestaurantOrdersAsync(
                GetAuthenticatedUserId()!.Value,
                IsAdmin(),
                cancellationToken);

            return Ok(orders);
        }

        [HttpGet("{orderId}")]
        public async Task<IActionResult> GetById(string orderId, CancellationToken cancellationToken)
        {
            var order = await _orderService.GetRestaurantOrderByPublicIdAsync(
                orderId,
                GetAuthenticatedUserId()!.Value,
                IsAdmin(),
                cancellationToken);

            return order == null ? NotFound("Pedido no encontrado") : Ok(order);
        }

        [HttpPatch("{orderId}/status")]
        public async Task<IActionResult> UpdateStatus(
            string orderId,
            [FromBody] UpdateRestaurantOrderStatusRequest request,
            CancellationToken cancellationToken)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Status))
                return BadRequest("El status es obligatorio");

            try
            {
                var updated = await _orderService.UpdateRestaurantOrderStatusAsync(
                    orderId,
                    GetAuthenticatedUserId()!.Value,
                    IsAdmin(),
                    request.Status,
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

            await foreach (var message in _realtimeService.SubscribeRestaurantAsync(
                userId.Value,
                IsAdmin(),
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

        private bool IsAdmin()
        {
            return string.Equals(
                User.FindFirstValue(ClaimTypes.Role),
                "Admin",
                StringComparison.OrdinalIgnoreCase);
        }
    }
}
