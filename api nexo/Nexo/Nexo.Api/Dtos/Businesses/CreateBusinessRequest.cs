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
        public string OpenTime { get; set; } = "09:00";
        public string CloseTime { get; set; } = "22:00";
        public string OpenDays { get; set; } = "1,2,3,4,5";
        public List<BusinessOperatingHourRequest> OperatingHours { get; set; } = new();
        public bool IsPaused { get; set; }
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public double DeliveryRadiusKm { get; set; } = 5;
    }

    public class BusinessOperatingHourRequest
    {
        public int Day { get; set; }
        public bool IsOpen { get; set; }
        public string OpenTime { get; set; } = "09:00";
        public string CloseTime { get; set; } = "22:00";
    }
}
