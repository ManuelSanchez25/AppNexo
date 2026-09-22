namespace Nexo.Api.Dtos.Drivers
{
    public class DriverApplicationResponse
    {
        public int UserId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string VehicleType { get; set; } = string.Empty;
        public string VehicleMakeModel { get; set; } = string.Empty;
        public string VehicleColor { get; set; } = string.Empty;
        public string VehiclePlate { get; set; } = string.Empty;
        public string LicenseType { get; set; } = string.Empty;
        public string LicenseNumber { get; set; } = string.Empty;
        public string IdentityType { get; set; } = string.Empty;
        public string IdentityDocument { get; set; } = string.Empty;
        public string ApprovalStatus { get; set; } = string.Empty;
    }
}
