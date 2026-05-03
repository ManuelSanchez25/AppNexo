using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nexo.Api.Dtos.Orders;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/orders")]
    [Authorize]
    public class OrdersController : ControllerBase
    {
        private readonly IOrderService _orderService;

        public OrdersController(IOrderService orderService)
        {
            _orderService = orderService;
        }

        [HttpPost]
        public async Task<IActionResult> Create(
            [FromBody] CreateOrderRequest request,
            CancellationToken cancellationToken)
        {
            try
            {
                var response = await _orderService.CreateAsync(
                    request,
                    GetAuthenticatedUserId(),
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

        private int? GetAuthenticatedUserId()
        {
            var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User.FindFirstValue("sub");

            return int.TryParse(claimValue, out var userId) ? userId : null;
        }
    }
}
