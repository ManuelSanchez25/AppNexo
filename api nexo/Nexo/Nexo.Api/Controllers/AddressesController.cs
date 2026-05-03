using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Addresses;
using Nexo.Api.Entitites;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/addresses")]
    [Authorize]
    public class AddressesController : ControllerBase
    {
        private readonly AppDbContext _db;

        public AddressesController(AppDbContext db)
        {
            _db = db;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll(CancellationToken cancellationToken)
        {
            var userId = GetAuthenticatedUserId();
            if (userId == null) return Unauthorized();

            var addresses = await _db.Addresses
                .AsNoTracking()
                .Where(a => a.UserId == userId.Value)
                .OrderByDescending(a => a.IsDefault)
                .ThenByDescending(a => a.CreatedAt)
                .ToListAsync(cancellationToken);

            return Ok(addresses.Select(ToResponse));
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id, CancellationToken cancellationToken)
        {
            var address = await GetOwnedAddressAsync(id, cancellationToken);
            return address == null ? NotFound("Direccion no encontrada") : Ok(ToResponse(address));
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateAddressRequest request, CancellationToken cancellationToken)
        {
            var userId = GetAuthenticatedUserId();
            if (userId == null) return Unauthorized();

            var validationError = Validate(request);
            if (validationError != null) return BadRequest(validationError);

            if (request.IsDefault)
            {
                await ClearDefaultAsync(userId.Value, cancellationToken);
            }
            else
            {
                var hasAnyAddress = await _db.Addresses.AnyAsync(a => a.UserId == userId.Value, cancellationToken);
                if (!hasAnyAddress)
                {
                    request.IsDefault = true;
                }
            }

            var address = new Address
            {
                UserId = userId.Value,
                Label = request.Label.Trim(),
                RecipientName = request.RecipientName.Trim(),
                Phone = request.Phone.Trim(),
                Street = request.Street.Trim(),
                ExteriorNumber = request.ExteriorNumber.Trim(),
                InteriorNumber = request.InteriorNumber?.Trim() ?? string.Empty,
                Neighborhood = request.Neighborhood.Trim(),
                City = request.City.Trim(),
                State = request.State.Trim(),
                PostalCode = request.PostalCode.Trim(),
                References = request.References?.Trim() ?? string.Empty,
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                IsDefault = request.IsDefault
            };

            _db.Addresses.Add(address);
            await _db.SaveChangesAsync(cancellationToken);

            return Created($"/api/addresses/{address.Id}", ToResponse(address));
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> Update(int id, [FromBody] UpdateAddressRequest request, CancellationToken cancellationToken)
        {
            var address = await GetOwnedAddressAsync(id, cancellationToken);
            if (address == null) return NotFound("Direccion no encontrada");

            var validationError = Validate(request);
            if (validationError != null) return BadRequest(validationError);

            if (request.IsDefault)
            {
                await ClearDefaultAsync(address.UserId, cancellationToken);
            }

            address.Label = request.Label.Trim();
            address.RecipientName = request.RecipientName.Trim();
            address.Phone = request.Phone.Trim();
            address.Street = request.Street.Trim();
            address.ExteriorNumber = request.ExteriorNumber.Trim();
            address.InteriorNumber = request.InteriorNumber?.Trim() ?? string.Empty;
            address.Neighborhood = request.Neighborhood.Trim();
            address.City = request.City.Trim();
            address.State = request.State.Trim();
            address.PostalCode = request.PostalCode.Trim();
            address.References = request.References?.Trim() ?? string.Empty;
            address.Latitude = request.Latitude;
            address.Longitude = request.Longitude;
            address.IsDefault = request.IsDefault;

            await _db.SaveChangesAsync(cancellationToken);
            return Ok(ToResponse(address));
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
        {
            var address = await GetOwnedAddressAsync(id, cancellationToken);
            if (address == null) return NotFound("Direccion no encontrada");

            var wasDefault = address.IsDefault;
            var userId = address.UserId;

            _db.Addresses.Remove(address);
            await _db.SaveChangesAsync(cancellationToken);

            if (wasDefault)
            {
                var nextAddress = await _db.Addresses
                    .Where(a => a.UserId == userId)
                    .OrderByDescending(a => a.CreatedAt)
                    .FirstOrDefaultAsync(cancellationToken);

                if (nextAddress != null)
                {
                    nextAddress.IsDefault = true;
                    await _db.SaveChangesAsync(cancellationToken);
                }
            }

            return NoContent();
        }

        [HttpPatch("{id:int}/default")]
        public async Task<IActionResult> SetDefault(int id, CancellationToken cancellationToken)
        {
            var address = await GetOwnedAddressAsync(id, cancellationToken);
            if (address == null) return NotFound("Direccion no encontrada");

            await ClearDefaultAsync(address.UserId, cancellationToken);
            address.IsDefault = true;
            await _db.SaveChangesAsync(cancellationToken);

            return NoContent();
        }

        private int? GetAuthenticatedUserId()
        {
            var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User.FindFirstValue("sub");

            return int.TryParse(claimValue, out var userId) ? userId : null;
        }

        private async Task<Address?> GetOwnedAddressAsync(int addressId, CancellationToken cancellationToken)
        {
            var userId = GetAuthenticatedUserId();
            if (userId == null) return null;

            return await _db.Addresses
                .FirstOrDefaultAsync(
                    a => a.Id == addressId && a.UserId == userId.Value,
                    cancellationToken);
        }

        private async Task ClearDefaultAsync(int userId, CancellationToken cancellationToken)
        {
            var currentDefaults = await _db.Addresses
                .Where(a => a.UserId == userId && a.IsDefault)
                .ToListAsync(cancellationToken);

            foreach (var item in currentDefaults)
            {
                item.IsDefault = false;
            }
        }

        private static string? Validate(CreateAddressRequest request)
        {
            if (request == null) return "Direccion invalida";
            if (string.IsNullOrWhiteSpace(request.Label)) return "La etiqueta es obligatoria";
            if (string.IsNullOrWhiteSpace(request.RecipientName)) return "El nombre del receptor es obligatorio";
            if (string.IsNullOrWhiteSpace(request.Phone)) return "El telefono es obligatorio";
            if (string.IsNullOrWhiteSpace(request.Street)) return "La calle es obligatoria";
            if (string.IsNullOrWhiteSpace(request.ExteriorNumber) &&
                string.IsNullOrWhiteSpace(request.InteriorNumber))
            {
                return "Debes capturar al menos numero exterior o interior";
            }
            if (string.IsNullOrWhiteSpace(request.Neighborhood)) return "La colonia es obligatoria";
            if (string.IsNullOrWhiteSpace(request.City)) return "La ciudad es obligatoria";
            if (string.IsNullOrWhiteSpace(request.State)) return "El estado es obligatorio";
            if (string.IsNullOrWhiteSpace(request.PostalCode)) return "El codigo postal es obligatorio";
            if (request.Latitude.HasValue && (request.Latitude < -90 || request.Latitude > 90))
                return "La latitud no es valida";
            if (request.Longitude.HasValue && (request.Longitude < -180 || request.Longitude > 180))
                return "La longitud no es valida";
            return null;
        }

        private static AddressResponse ToResponse(Address address)
        {
            return new AddressResponse
            {
                Id = address.Id,
                Label = address.Label,
                RecipientName = address.RecipientName,
                Phone = address.Phone,
                Street = address.Street,
                ExteriorNumber = address.ExteriorNumber,
                InteriorNumber = address.InteriorNumber,
                Neighborhood = address.Neighborhood,
                City = address.City,
                State = address.State,
                PostalCode = address.PostalCode,
                References = address.References,
                Latitude = address.Latitude,
                Longitude = address.Longitude,
                IsDefault = address.IsDefault,
                CreatedAt = address.CreatedAt,
                FullAddress = BuildFullAddress(address)
            };
        }

        private static string BuildFullAddress(Address address)
        {
            var line1 = $"{address.Street} {address.ExteriorNumber}";
            if (!string.IsNullOrWhiteSpace(address.InteriorNumber))
            {
                line1 += $" Int. {address.InteriorNumber}";
            }

            return $"{line1}, {address.Neighborhood}, {address.City}, {address.State}, CP {address.PostalCode}";
        }
    }
}
