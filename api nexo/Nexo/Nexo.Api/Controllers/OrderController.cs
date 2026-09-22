using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nexo.Api.Dtos.Orders;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/orders")]
    [Authorize(Roles = "Client")]
    public class OrdersController : ControllerBase
    {
        private readonly IOrderService _orderService;
        private readonly IOrderRealtimeService _realtimeService;
        private readonly ILogger<OrdersController> _logger;

        public OrdersController(
            IOrderService orderService,
            IOrderRealtimeService realtimeService,
            ILogger<OrdersController> logger)
        {
            _orderService = orderService;
            _realtimeService = realtimeService;
            _logger = logger;
        }

        [HttpPost]
        public async Task<IActionResult> Create(
            [FromBody] CreateOrderRequest request,
            CancellationToken cancellationToken)
        {
            try
            {
                var clientRequestId = Request.Headers["Idempotency-Key"].ToString();
                var response = await _orderService.CreateAsync(
                    request,
                    GetAuthenticatedUserId(),
                    clientRequestId,
                    cancellationToken);

                return Ok(response);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
            catch (KeyNotFoundException ex)
            {
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                var rootCause = ex.GetBaseException();
                _logger.LogError(
                    "No se pudo crear un pedido para el usuario {UserId}. Causa: {ErrorType}: {ErrorMessage}",
                    GetAuthenticatedUserId(),
                    rootCause.GetType().Name,
                    rootCause.Message);
                return StatusCode(StatusCodes.Status500InternalServerError,
                    "No pudimos crear el pedido. Inténtalo nuevamente.");
            }
        }

        [HttpGet]
        public async Task<IActionResult> GetHistory(CancellationToken cancellationToken)
        {
            var history = await _orderService.GetHistoryAsync(
                GetAuthenticatedUserId()!.Value,
                cancellationToken);

            return Ok(history);
        }

        [HttpGet("{orderId}")]
        public async Task<IActionResult> GetById(string orderId, CancellationToken cancellationToken)
        {
            var order = await _orderService.GetByPublicIdAsync(
                orderId,
                GetAuthenticatedUserId()!.Value,
                cancellationToken);

            return order == null ? NotFound("Pedido no encontrado") : Ok(order);
        }

        [HttpPost("{orderId}/cancel")]
        public async Task<IActionResult> Cancel(
            string orderId,
            [FromBody] CancelOrderRequest request,
            CancellationToken cancellationToken)
        {
            if (request == null)
                return BadRequest("El motivo de cancelacion es obligatorio.");

            try
            {
                var updated = await _orderService.CancelCustomerOrderAsync(
                    orderId,
                    GetAuthenticatedUserId()!.Value,
                    request.Reason,
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

            await foreach (var message in _realtimeService.SubscribeCustomerAsync(
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
