using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Push;
using Nexo.Api.Entities;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/push/devices")]
    [Authorize]
    public class PushNotificationsController : ControllerBase
    {
        private readonly AppDbContext _db;

        public PushNotificationsController(AppDbContext db) => _db = db;

        [HttpPost]
        public async Task<IActionResult> RegisterDevice([FromBody] RegisterPushDeviceRequest request)
        {
            var userIdValue = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!int.TryParse(userIdValue, out var userId)) return Unauthorized();
            if (request == null || string.IsNullOrWhiteSpace(request.Token) || request.Token.Length > 4096)
                return BadRequest("Token de dispositivo no válido.");

            var token = request.Token.Trim();
            var platform = request.Platform.Trim().ToLowerInvariant();
            if (platform is not ("android" or "ios"))
                return BadRequest("Plataforma no válida.");

            var device = await _db.PushDevices.FirstOrDefaultAsync(d => d.Token == token);
            if (device == null)
            {
                _db.PushDevices.Add(new PushDevice { UserId = userId, Token = token, Platform = platform });
            }
            else
            {
                device.UserId = userId;
                device.Platform = platform;
                device.UpdatedAt = DateTime.UtcNow;
            }

            await _db.SaveChangesAsync();
            return NoContent();
        }
    }
}
