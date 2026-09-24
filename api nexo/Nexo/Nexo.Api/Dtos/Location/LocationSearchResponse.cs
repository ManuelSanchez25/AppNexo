namespace Nexo.Api.Dtos.Location
{
    public class LocationSearchResponse
    {
        public string DisplayName { get; set; } = string.Empty;
        public string Street { get; set; } = string.Empty;
        public string ExteriorNumber { get; set; } = string.Empty;
        public string Neighborhood { get; set; } = string.Empty;
        public string City { get; set; } = string.Empty;
        public string State { get; set; } = string.Empty;
        public string PostalCode { get; set; } = string.Empty;
        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
    }
}
