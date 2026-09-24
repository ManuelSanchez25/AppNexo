using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Nexo.Api.Dtos.Location;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/location")]
    public class LocationController : ControllerBase
    {
        private const string UserAgent = "NexoApp/1.0 (contact: local-dev)";
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IMemoryCache _cache;

        public LocationController(IHttpClientFactory httpClientFactory, IMemoryCache cache)
        {
            _httpClientFactory = httpClientFactory;
            _cache = cache;
        }

        [HttpGet("search")]
        public async Task<IActionResult> Search([FromQuery] string q, CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 4)
                return BadRequest("Escribe al menos 4 caracteres para buscar.");

            var cacheKey = $"location:search:{q.Trim().ToLowerInvariant()}";
            if (_cache.TryGetValue(cacheKey, out IReadOnlyList<LocationSearchResponse>? cached) && cached != null)
            {
                return Ok(cached);
            }

            var encoded = Uri.EscapeDataString(q.Trim());
            var url = $"https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=6&q={encoded}";

            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.UserAgent.ParseAdd(UserAgent);

            var client = _httpClientFactory.CreateClient();
            var response = await client.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return StatusCode((int)response.StatusCode, "No pudimos buscar esa direccion.");

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);

            var items = document.RootElement
                .EnumerateArray()
                .Select(MapLocation)
                .Where(item => !string.IsNullOrWhiteSpace(item.DisplayName))
                .ToList();

            _cache.Set(cacheKey, items, TimeSpan.FromMinutes(30));
            return Ok(items);
        }

        [HttpGet("reverse")]
        public async Task<IActionResult> Reverse([FromQuery] decimal lat, [FromQuery] decimal lng, CancellationToken cancellationToken)
        {
            if (lat < -90 || lat > 90 || lng < -180 || lng > 180)
                return BadRequest("Coordenadas invalidas.");

            var cacheKey = $"location:reverse:{lat:F6}:{lng:F6}";
            if (_cache.TryGetValue(cacheKey, out LocationSearchResponse? cached) && cached != null)
            {
                return Ok(cached);
            }

            var url = $"https://nominatim.openstreetmap.org/reverse?format=jsonv2&addressdetails=1&lat={lat}&lon={lng}";
            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.UserAgent.ParseAdd(UserAgent);

            var client = _httpClientFactory.CreateClient();
            var response = await client.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return StatusCode((int)response.StatusCode, "No pudimos interpretar esa ubicacion.");

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var item = MapLocation(document.RootElement);
            _cache.Set(cacheKey, item, TimeSpan.FromMinutes(30));
            return Ok(item);
        }

        private static LocationSearchResponse MapLocation(JsonElement element)
        {
            element.TryGetProperty("address", out var address);

            string ReadAddress(string name) =>
                address.ValueKind == JsonValueKind.Object && address.TryGetProperty(name, out var value)
                    ? value.GetString() ?? string.Empty
                    : string.Empty;

            decimal.TryParse(
                element.TryGetProperty("lat", out var latElement) ? latElement.GetString() : "0",
                NumberStyles.Any,
                CultureInfo.InvariantCulture,
                out var lat);
            decimal.TryParse(
                element.TryGetProperty("lon", out var lonElement) ? lonElement.GetString() : "0",
                NumberStyles.Any,
                CultureInfo.InvariantCulture,
                out var lng);

            var city = FirstNonEmpty(
                ReadAddress("city"),
                ReadAddress("town"),
                ReadAddress("village"),
                ReadAddress("municipality"));

            var neighborhood = FirstNonEmpty(
                ReadAddress("suburb"),
                ReadAddress("neighbourhood"),
                ReadAddress("quarter"));

            return new LocationSearchResponse
            {
                DisplayName = element.TryGetProperty("display_name", out var displayName)
                    ? displayName.GetString() ?? string.Empty
                    : string.Empty,
                Street = FirstNonEmpty(ReadAddress("road"), ReadAddress("pedestrian")),
                ExteriorNumber = ReadAddress("house_number"),
                Neighborhood = neighborhood,
                City = city,
                State = ReadAddress("state"),
                PostalCode = ReadAddress("postcode"),
                Latitude = lat,
                Longitude = lng
            };
        }

        private static string FirstNonEmpty(params string[] values)
        {
            return values.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value)) ?? string.Empty;
        }
    }
}
