using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Drivers;
using Nexo.Api.Entitites;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/admin/drivers")]
    [Authorize(Roles = "Admin")]
    public class AdminDriversController : ControllerBase
    {
        private readonly AppDbContext _db;

        public AdminDriversController(AppDbContext db)
        {
            _db = db;
        }

        [HttpGet]
        public async Task<IActionResult> GetDrivers(CancellationToken cancellationToken)
        {
            var drivers = await _db.Users
                .AsNoTracking()
                .Where(u => u.Role == UserRole.Driver)
                .OrderBy(u => u.DriverApprovalStatus)
                .ThenBy(u => u.Name)
                .Select(u => new DriverApplicationResponse
                {
                    UserId = u.Id,
                    Name = u.Name,
                    Email = u.Email,
                    FullName = u.DriverFullName,
                    Phone = u.DriverPhone,
                    VehicleType = u.DriverVehicleType,
                    VehicleMakeModel = u.DriverVehicleMakeModel,
                    VehicleColor = u.DriverVehicleColor,
                    VehiclePlate = u.DriverVehiclePlate,
                    LicenseType = u.DriverLicenseType,
                    LicenseNumber = u.DriverLicenseNumber,
                    IdentityType = u.DriverIdentityType,
                    IdentityDocument = u.DriverIdentityDocument,
                    ApprovalStatus = u.DriverApprovalStatus
                })
                .ToListAsync(cancellationToken);

            return Ok(drivers);
        }

        [HttpPatch("{userId}/approval")]
        public async Task<IActionResult> UpdateApproval(
            int userId,
            [FromBody] UpdateDriverApprovalRequest request,
            CancellationToken cancellationToken)
        {
            var status = request.Status.Trim().ToLower();
            if (status != "approved" && status != "rejected" && status != "pending")
                return BadRequest("Estado de aprobacion invalido.");

            var driver = await _db.Users
                .FirstOrDefaultAsync(
                    u => u.Id == userId && u.Role == UserRole.Driver,
                    cancellationToken);

            if (driver == null)
                return NotFound("Repartidor no encontrado.");

            if (status != "approved")
            {
                var hasActiveOrders = await _db.Orders.AnyAsync(
                    o => o.DriverUserId == userId &&
                         o.Status != "delivered" &&
                         o.Status != "cancelled",
                    cancellationToken);

                if (hasActiveOrders)
                    return BadRequest("No puedes suspender o rechazar a un repartidor con entregas activas.");
            }

            driver.DriverApprovalStatus = status;
            await _db.SaveChangesAsync(cancellationToken);
            return NoContent();
        }
    }
}
