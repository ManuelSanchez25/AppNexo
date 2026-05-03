using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Businesses;
using Nexo.Api.Entities;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/businesses")]
    public class BusinessesController : ControllerBase
    {
        private readonly AppDbContext _db;

        public BusinessesController(AppDbContext db)
        {
            _db = db;
        }

        [HttpGet]
        public IActionResult Get()
        {
            var businesses = _db.Businesses
                .OrderBy(b => b.Name)
                .Select(b => new BusinessResponse
                {
                    Id = b.Id,
                    Name = b.Name,
                    Description = b.Description,
                    Rating = b.Rating,
                    Time = b.Time,
                    ImageUrl = b.ImageUrl,
                    AddressText = b.AddressText,
                    Latitude = b.Latitude,
                    Longitude = b.Longitude,
                    DeliveryRadiusKm = b.DeliveryRadiusKm
                })
                .ToList();

            return Ok(businesses);
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpGet("owned")]
        public IActionResult GetOwned()
        {
            var userId = GetCurrentUserId();
            if (userId == null)
                return Unauthorized();

            var businesses = _db.Businesses
                .Where(b => IsAdmin() || b.OwnerUserId == userId.Value)
                .OrderBy(b => b.Name)
                .Select(b => new BusinessResponse
                {
                    Id = b.Id,
                    Name = b.Name,
                    Description = b.Description,
                    Rating = b.Rating,
                    Time = b.Time,
                    ImageUrl = b.ImageUrl,
                    AddressText = b.AddressText,
                    Latitude = b.Latitude,
                    Longitude = b.Longitude,
                    DeliveryRadiusKm = b.DeliveryRadiusKm
                })
                .ToList();

            return Ok(businesses);
        }

        [HttpGet("{id:int}")]
        public IActionResult GetById(int id)
        {
            var business = _db.Businesses
                .Where(b => b.Id == id)
                .Select(b => new BusinessResponse
                {
                    Id = b.Id,
                    Name = b.Name,
                    Description = b.Description,
                    Rating = b.Rating,
                    Time = b.Time,
                    ImageUrl = b.ImageUrl,
                    AddressText = b.AddressText,
                    Latitude = b.Latitude,
                    Longitude = b.Longitude,
                    DeliveryRadiusKm = b.DeliveryRadiusKm
                })
                .FirstOrDefault();

            if (business == null)
                return NotFound("No existe el negocio");

            return Ok(business);
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPost]
        public IActionResult Create([FromBody] CreateBusinessRequest request)
        {
            var userId = GetCurrentUserId();
            if (userId == null)
                return Unauthorized();

            if (request == null)
                return BadRequest("El negocio es requerido");

            if (string.IsNullOrWhiteSpace(request.Name))
                return BadRequest("El nombre del negocio es obligatorio");

            if (string.IsNullOrWhiteSpace(request.Description))
                return BadRequest("La descripción es obligatoria");

            if (string.IsNullOrWhiteSpace(request.Time))
                return BadRequest("El tiempo estimado es obligatorio");

            if (request.Rating < 0 || request.Rating > 5)
                return BadRequest("El rating debe estar entre 0 y 5");
            if (string.IsNullOrWhiteSpace(request.AddressText))
                return BadRequest("La ubicacion del negocio es obligatoria");
            if (request.Latitude.HasValue && (request.Latitude < -90 || request.Latitude > 90))
                return BadRequest("La latitud del negocio no es valida");
            if (request.Longitude.HasValue && (request.Longitude < -180 || request.Longitude > 180))
                return BadRequest("La longitud del negocio no es valida");
            if (request.DeliveryRadiusKm < 0.5 || request.DeliveryRadiusKm > 50)
                return BadRequest("El radio de entrega debe estar entre 0.5 y 50 km");

            var normalizedName = request.Name.Trim().ToLower();
            var exists = _db.Businesses.Any(b => b.Name.ToLower() == normalizedName);

            if (exists)
                return Conflict("Ya existe un negocio con ese nombre");

            var business = new Business
            {
                OwnerUserId = userId.Value,
                Name = request.Name.Trim(),
                Description = request.Description.Trim(),
                Time = request.Time.Trim(),
                Rating = request.Rating,
                ImageUrl = request.ImageUrl?.Trim() ?? string.Empty,
                AddressText = request.AddressText.Trim(),
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                DeliveryRadiusKm = request.DeliveryRadiusKm
            };

            _db.Businesses.Add(business);
            _db.SaveChanges();

            var response = new BusinessResponse
            {
                Id = business.Id,
                Name = business.Name,
                Description = business.Description,
                Rating = business.Rating,
                Time = business.Time,
                ImageUrl = business.ImageUrl,
                AddressText = business.AddressText,
                Latitude = business.Latitude,
                Longitude = business.Longitude,
                DeliveryRadiusKm = business.DeliveryRadiusKm
            };

            return CreatedAtAction(nameof(Get), new { id = business.Id }, response);
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPut("{id:int}")]
        public IActionResult Update(int id, [FromBody] CreateBusinessRequest request)
        {
            if (request == null)
                return BadRequest("El negocio es requerido");

            var business = _db.Businesses.FirstOrDefault(b => b.Id == id);
            if (business == null)
                return NotFound("No existe el negocio");

            var userId = GetCurrentUserId();
            if (userId == null)
                return Unauthorized();

            if (!IsAdmin() && business.OwnerUserId != userId.Value)
                return Forbid();

            if (string.IsNullOrWhiteSpace(request.Name))
                return BadRequest("El nombre del negocio es obligatorio");

            if (string.IsNullOrWhiteSpace(request.Description))
                return BadRequest("La descripción es obligatoria");

            if (string.IsNullOrWhiteSpace(request.Time))
                return BadRequest("El tiempo estimado es obligatorio");

            if (request.Rating < 0 || request.Rating > 5)
                return BadRequest("El rating debe estar entre 0 y 5");
            if (string.IsNullOrWhiteSpace(request.AddressText))
                return BadRequest("La ubicacion del negocio es obligatoria");
            if (request.Latitude.HasValue && (request.Latitude < -90 || request.Latitude > 90))
                return BadRequest("La latitud del negocio no es valida");
            if (request.Longitude.HasValue && (request.Longitude < -180 || request.Longitude > 180))
                return BadRequest("La longitud del negocio no es valida");
            if (request.DeliveryRadiusKm < 0.5 || request.DeliveryRadiusKm > 50)
                return BadRequest("El radio de entrega debe estar entre 0.5 y 50 km");

            var normalizedName = request.Name.Trim().ToLower();
            var exists = _db.Businesses.Any(b => b.Id != id && b.Name.ToLower() == normalizedName);

            if (exists)
                return Conflict("Ya existe un negocio con ese nombre");

            business.Name = request.Name.Trim();
            business.Description = request.Description.Trim();
            business.Time = request.Time.Trim();
            business.Rating = request.Rating;
            business.ImageUrl = request.ImageUrl?.Trim() ?? string.Empty;
            business.AddressText = request.AddressText.Trim();
            business.Latitude = request.Latitude;
            business.Longitude = request.Longitude;
            business.DeliveryRadiusKm = request.DeliveryRadiusKm;

            _db.SaveChanges();

            return Ok(new BusinessResponse
            {
                Id = business.Id,
                Name = business.Name,
                Description = business.Description,
                Rating = business.Rating,
                Time = business.Time,
                ImageUrl = business.ImageUrl,
                AddressText = business.AddressText,
                Latitude = business.Latitude,
                Longitude = business.Longitude,
                DeliveryRadiusKm = business.DeliveryRadiusKm
            });
        }

        private int? GetCurrentUserId()
        {
            var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
            return int.TryParse(value, out var userId) ? userId : null;
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
