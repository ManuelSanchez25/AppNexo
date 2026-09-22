using Nexo.Api.Entitites;

namespace Nexo.Api.Entities
{
    public class Business
    {
        public int Id { get; set; }
        public int? OwnerUserId { get; set; }
        public User? OwnerUser { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public double Rating { get; set; }
        public string Time { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty; // ✅ NUEVO
        public string AddressText { get; set; } = string.Empty;
        public string ApprovalStatus { get; set; } = "approved";
        public string OpenTime { get; set; } = "09:00";
        public string CloseTime { get; set; } = "22:00";
        public string OpenDays { get; set; } = "1,2,3,4,5";
        public string OperatingHoursJson { get; set; } = string.Empty;
        public bool IsPaused { get; set; }
        public decimal? Latitude { get; set; }
        public decimal? Longitude { get; set; }
        public double DeliveryRadiusKm { get; set; } = 5;
        public List<Product> Products { get; set; } = new();
        public List<ProductOptionGroup> OptionGroups { get; set; } = new();

    }
}
