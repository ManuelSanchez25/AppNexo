namespace Nexo.Api.Dtos.Businesses
{
    public class CreateBusinessRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public double Rating { get; set; }
        public string Time { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public string AddressText { get; set; } = string.Empty;
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public double DeliveryRadiusKm { get; set; } = 5;
    }
}
