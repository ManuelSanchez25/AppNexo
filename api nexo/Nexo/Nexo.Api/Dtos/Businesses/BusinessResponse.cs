namespace Nexo.Api.Dtos.Businesses
{
    public class BusinessResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public double Rating { get; set; }
        public string Time { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public string AddressText { get; set; } = string.Empty;
        public string ApprovalStatus { get; set; } = string.Empty;
        public string OpenTime { get; set; } = string.Empty;
        public string CloseTime { get; set; } = string.Empty;
        public string OpenDays { get; set; } = string.Empty;
        public List<BusinessOperatingHourResponse> OperatingHours { get; set; } = new();
        public bool IsPaused { get; set; }
        public bool IsOpen { get; set; }
        public string AvailabilityLabel { get; set; } = string.Empty;
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public double DeliveryRadiusKm { get; set; }
    }

    public class BusinessOperatingHourResponse
    {
        public int Day { get; set; }
        public bool IsOpen { get; set; }
        public string OpenTime { get; set; } = string.Empty;
        public string CloseTime { get; set; } = string.Empty;
    }
}
