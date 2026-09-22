namespace Nexo.Api.Dtos.Auth
{
    public class RegisterRequest
    {
        public string Name { get; set; } = "";
        public string Email { get; set; } = "";
        public string Phone { get; set; } = "";
        public string Password { get; set; } = "";
        public DateTime BirthDate { get; set; }
        public string Role { get; set; } = "";
        public bool AcceptTerms { get; set; }
        public string DriverFullName { get; set; } = "";
        public string DriverPhone { get; set; } = "";
        public string DriverVehicleType { get; set; } = "";
        public string DriverVehicleMakeModel { get; set; } = "";
        public string DriverVehicleColor { get; set; } = "";
        public string DriverVehiclePlate { get; set; } = "";
        public string DriverLicenseType { get; set; } = "";
        public string DriverLicenseNumber { get; set; } = "";
        public string DriverIdentityType { get; set; } = "";
        public string DriverIdentityDocument { get; set; } = "";
    }
}
