namespace Nexo.Api.Dtos.Auth
{
    public class GoogleAuthRequest
    {
        public string IdToken { get; set; } = string.Empty;
        public string Role { get; set; } = "client";
        public DateTime? BirthDate { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public bool AcceptTerms { get; set; }
        public string DriverFullName { get; set; } = string.Empty;
        public string DriverPhone { get; set; } = string.Empty;
        public string DriverVehicleType { get; set; } = string.Empty;
        public string DriverVehicleMakeModel { get; set; } = string.Empty;
        public string DriverVehicleColor { get; set; } = string.Empty;
        public string DriverVehiclePlate { get; set; } = string.Empty;
        public string DriverLicenseType { get; set; } = string.Empty;
        public string DriverLicenseNumber { get; set; } = string.Empty;
        public string DriverIdentityType { get; set; } = string.Empty;
        public string DriverIdentityDocument { get; set; } = string.Empty;
    }
}
