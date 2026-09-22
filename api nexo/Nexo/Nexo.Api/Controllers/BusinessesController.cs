using System.Security.Claims;
using System.Text.Json;
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
        private static readonly TimeZoneInfo MexicoCityTimeZone = TimeZoneInfo.FindSystemTimeZoneById("America/Mexico_City");

        private readonly AppDbContext _db;

        public BusinessesController(AppDbContext db)
        {
            _db = db;
        }

        [HttpGet]
        public IActionResult Get()
        {
            var businesses = _db.Businesses
                .Where(b => b.ApprovalStatus == "approved")
                .OrderBy(b => b.Name)
                .AsEnumerable()
                .Select(ToResponse)
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
                .AsEnumerable()
                .Select(ToResponse)
                .ToList();

            return Ok(businesses);
        }

        [HttpGet("{id:int}")]
        public IActionResult GetById(int id)
        {
            var business = _db.Businesses
                .Where(b => b.Id == id && b.ApprovalStatus == "approved")
                .AsEnumerable()
                .Select(ToResponse)
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
            if (!IsValidEstimatedMinutes(request.Time))
                return BadRequest("El tiempo estimado debe ser un numero de minutos entre 5 y 180.");

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
            var scheduleResult = BuildSchedule(request.OperatingHours);
            if (!scheduleResult.IsValid)
                return BadRequest(scheduleResult.Error);

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
                OpenTime = scheduleResult.FirstOpen!.OpenTime,
                CloseTime = scheduleResult.FirstOpen.CloseTime,
                OpenDays = scheduleResult.OpenDays,
                OperatingHoursJson = JsonSerializer.Serialize(scheduleResult.Schedule),
                IsPaused = false,
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                DeliveryRadiusKm = request.DeliveryRadiusKm,
                ApprovalStatus = IsAdmin() ? "approved" : "pending"
            };

            _db.Businesses.Add(business);
            _db.SaveChanges();

            var response = ToResponse(business);

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
            if (!IsValidEstimatedMinutes(request.Time))
                return BadRequest("El tiempo estimado debe ser un numero de minutos entre 5 y 180.");

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
            var scheduleResult = BuildSchedule(request.OperatingHours);
            if (!scheduleResult.IsValid)
                return BadRequest(scheduleResult.Error);

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
            business.OpenTime = scheduleResult.FirstOpen!.OpenTime;
            business.CloseTime = scheduleResult.FirstOpen.CloseTime;
            business.OpenDays = scheduleResult.OpenDays;
            business.OperatingHoursJson = JsonSerializer.Serialize(scheduleResult.Schedule);
            business.IsPaused = false;
            business.Latitude = request.Latitude;
            business.Longitude = request.Longitude;
            business.DeliveryRadiusKm = request.DeliveryRadiusKm;

            _db.SaveChanges();

            return Ok(ToResponse(business));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPatch("{id:int}/availability")]
        public IActionResult UpdateAvailability(int id, [FromBody] BusinessAvailabilityRequest request)
        {
            var business = _db.Businesses.FirstOrDefault(b => b.Id == id);
            if (business == null)
                return NotFound("No existe el negocio");

            var userId = GetCurrentUserId();
            if (userId == null)
                return Unauthorized();

            if (!IsAdmin() && business.OwnerUserId != userId.Value)
                return Forbid();

            business.IsPaused = request.IsPaused;
            _db.SaveChanges();

            return Ok(ToResponse(business));
        }

        [Authorize(Roles = "Admin")]
        [HttpPatch("{id:int}/approval")]
        public IActionResult UpdateApproval(int id, [FromBody] BusinessApprovalRequest request)
        {
            var status = request.Status.Trim().ToLower();
            if (status != "approved" && status != "rejected" && status != "pending")
                return BadRequest("Estado de aprobacion invalido.");

            var business = _db.Businesses.FirstOrDefault(b => b.Id == id);
            if (business == null)
                return NotFound("No existe el negocio");

            business.ApprovalStatus = status;
            _db.SaveChanges();

            return Ok(ToResponse(business));
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

        private static BusinessResponse ToResponse(Business business)
        {
            return new BusinessResponse
            {
                Id = business.Id,
                Name = business.Name,
                Description = business.Description,
                Rating = business.Rating,
                Time = business.Time,
                ImageUrl = business.ImageUrl,
                AddressText = business.AddressText,
                ApprovalStatus = business.ApprovalStatus,
                OpenTime = business.OpenTime,
                CloseTime = business.CloseTime,
                OpenDays = business.OpenDays,
                OperatingHours = GetSchedule(business)
                    .Select(hour => new BusinessOperatingHourResponse
                    {
                        Day = hour.Day,
                        IsOpen = hour.IsOpen,
                        OpenTime = hour.OpenTime,
                        CloseTime = hour.CloseTime
                    })
                    .ToList(),
                IsPaused = business.IsPaused,
                IsOpen = IsOpenNow(business),
                AvailabilityLabel = AvailabilityLabel(business),
                Latitude = business.Latitude,
                Longitude = business.Longitude,
                DeliveryRadiusKm = business.DeliveryRadiusKm
            };
        }

        private static bool IsValidTime(string? value)
        {
            return TimeOnly.TryParseExact(value?.Trim(), "HH:mm", out _);
        }

        private static bool IsValidEstimatedMinutes(string? value)
        {
            return int.TryParse(value?.Trim(), out var minutes) &&
                minutes >= 5 &&
                minutes <= 180;
        }

        private static bool IsOpenNow(Business business)
        {
            if (business.ApprovalStatus != "approved")
                return false;

            var todaySchedule = GetTodaySchedule(business);
            if (todaySchedule == null || !todaySchedule.IsOpen)
                return false;

            var open = TimeOnly.ParseExact(todaySchedule.OpenTime, "HH:mm");
            var close = TimeOnly.ParseExact(todaySchedule.CloseTime, "HH:mm");
            var now = TimeOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, MexicoCityTimeZone));
            return now >= open && now < close;
        }

        private static string AvailabilityLabel(Business business)
        {
            if (business.ApprovalStatus != "approved")
                return "Pendiente de aprobacion";

            var todaySchedule = GetTodaySchedule(business);
            if (todaySchedule is { IsOpen: true } && IsOpenNow(business))
                return $"Abierto hasta {todaySchedule.CloseTime}";

            var next = GetNextOpenSchedule(business);
            return next == null
                ? "Cerrado"
                : $"Cerrado, abre {DayLabel(next.Day)} a las {next.OpenTime}";
        }

        private static ScheduleValidationResult BuildSchedule(
            List<BusinessOperatingHourRequest>? request)
        {
            var source = request == null || request.Count == 0
                ? DefaultSchedule()
                : request.Select(item => new BusinessOperatingHourRequest
                {
                    Day = item.Day,
                    IsOpen = item.IsOpen,
                    OpenTime = item.OpenTime,
                    CloseTime = item.CloseTime
                }).ToList();

            if (source.Select(item => item.Day).Distinct().Count() != source.Count)
                return ScheduleValidationResult.Invalid("No repitas dias en el horario.");

            var schedule = new List<BusinessOperatingHour>();
            foreach (var item in source.OrderBy(item => item.Day))
            {
                if (item.Day < 1 || item.Day > 7)
                    return ScheduleValidationResult.Invalid("El dia del horario no es valido.");

                var openTime = item.OpenTime.Trim();
                var closeTime = item.CloseTime.Trim();
                if (item.IsOpen)
                {
                    if (!IsValidTime(openTime) || !IsValidTime(closeTime))
                        return ScheduleValidationResult.Invalid("El horario debe usar formato HH:mm, por ejemplo 09:00.");

                    var open = TimeOnly.ParseExact(openTime, "HH:mm");
                    var close = TimeOnly.ParseExact(closeTime, "HH:mm");
                    if (close <= open)
                        return ScheduleValidationResult.Invalid($"La hora de cierre de {DayLabel(item.Day)} debe ser mayor que la apertura.");
                }

                schedule.Add(new BusinessOperatingHour
                {
                    Day = item.Day,
                    IsOpen = item.IsOpen,
                    OpenTime = openTime,
                    CloseTime = closeTime
                });
            }

            var firstOpen = schedule.FirstOrDefault(item => item.IsOpen);
            if (firstOpen == null)
                return ScheduleValidationResult.Invalid("Selecciona al menos un dia abierto.");

            return ScheduleValidationResult.Valid(
                schedule,
                firstOpen,
                string.Join(",", schedule.Where(item => item.IsOpen).Select(item => item.Day)));
        }

        private static List<BusinessOperatingHour> GetSchedule(Business business)
        {
            if (!string.IsNullOrWhiteSpace(business.OperatingHoursJson))
            {
                try
                {
                    var parsed = JsonSerializer.Deserialize<List<BusinessOperatingHour>>(
                        business.OperatingHoursJson);
                    if (parsed != null && parsed.Count > 0)
                        return parsed.OrderBy(item => item.Day).ToList();
                }
                catch (JsonException)
                {
                    // Fall back to legacy columns below.
                }
            }

            var days = (business.OpenDays ?? string.Empty)
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(day => int.TryParse(day, out var parsed) ? parsed : 0)
                .Where(day => day >= 1 && day <= 7)
                .ToHashSet();

            return Enumerable.Range(1, 7)
                .Select(day => new BusinessOperatingHour
                {
                    Day = day,
                    IsOpen = days.Contains(day),
                    OpenTime = business.OpenTime,
                    CloseTime = business.CloseTime
                })
                .ToList();
        }

        private static BusinessOperatingHour? GetTodaySchedule(Business business)
        {
            return GetSchedule(business).FirstOrDefault(item => item.Day == TodayNumber());
        }

        private static BusinessOperatingHour? GetNextOpenSchedule(Business business)
        {
            var today = TodayNumber();
            var now = TimeOnly.FromDateTime(DateTime.Now);
            var schedule = GetSchedule(business).Where(item => item.IsOpen).ToList();

            for (var offset = 0; offset < 7; offset++)
            {
                var day = ((today - 1 + offset) % 7) + 1;
                var next = schedule
                    .Where(item => item.Day == day)
                    .OrderBy(item => item.OpenTime)
                    .FirstOrDefault(item =>
                    {
                        if (offset > 0)
                            return true;

                        return TimeOnly.TryParseExact(item.OpenTime, "HH:mm", out var open) &&
                            open > now;
                    });

                if (next != null)
                    return next;
            }

            return null;
        }

        private static int TodayNumber()
        {
            var day = (int)DateTime.Now.DayOfWeek;
            return day == 0 ? 7 : day;
        }

        private static string DayLabel(int day)
        {
            return day switch
            {
                1 => "lunes",
                2 => "martes",
                3 => "miercoles",
                4 => "jueves",
                5 => "viernes",
                6 => "sabado",
                7 => "domingo",
                _ => "otro dia"
            };
        }

        private static List<BusinessOperatingHourRequest> DefaultSchedule()
        {
            return Enumerable.Range(1, 7)
                .Select(day => new BusinessOperatingHourRequest
                {
                    Day = day,
                    IsOpen = day <= 5,
                    OpenTime = "09:00",
                    CloseTime = "22:00"
                })
                .ToList();
        }

        private class BusinessOperatingHour
        {
            public int Day { get; set; }
            public bool IsOpen { get; set; }
            public string OpenTime { get; set; } = "09:00";
            public string CloseTime { get; set; } = "22:00";
        }

        private record ScheduleValidationResult(
            bool IsValid,
            string Error,
            List<BusinessOperatingHour> Schedule,
            BusinessOperatingHour? FirstOpen,
            string OpenDays)
        {
            public static ScheduleValidationResult Invalid(string error) =>
                new(false, error, new List<BusinessOperatingHour>(), null, string.Empty);

            public static ScheduleValidationResult Valid(
                List<BusinessOperatingHour> schedule,
                BusinessOperatingHour firstOpen,
                string openDays) =>
                new(true, string.Empty, schedule, firstOpen, openDays);
        };
    }

    public class BusinessApprovalRequest
    {
        public string Status { get; set; } = string.Empty;
    }

    public class BusinessAvailabilityRequest
    {
        public bool IsPaused { get; set; }
    }
}
