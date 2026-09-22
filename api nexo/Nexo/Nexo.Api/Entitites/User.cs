using Nexo.Api.Entities;

namespace Nexo.Api.Entitites
{
    public class User
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public bool EmailVerified { get; set; }
        public string EmailVerificationCodeHash { get; set; } = string.Empty;
        public DateTime? EmailVerificationExpiresAt { get; set; }
        public DateTime? EmailVerificationLastSentAt { get; set; }
        public int EmailVerificationAttempts { get; set; }
        public string PasswordResetCodeHash { get; set; } = string.Empty;
        public DateTime? PasswordResetExpiresAt { get; set; }
        public DateTime? PasswordResetLastSentAt { get; set; }
        public int PasswordResetAttempts { get; set; }
        public UserRole Role { get; set; } = UserRole.Client;
        public DateTime BirthDate { get; set; }
        public string PasswordHash { get; set; } = string.Empty;
        public DateTime? TermsAcceptedAt { get; set; }
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
        public string DriverApprovalStatus { get; set; } = string.Empty;
        public List<Business> OwnedBusinesses { get; set; } = new();
        public List<Address> Addresses { get; set; } = new();
        public List<Order> Orders { get; set; } = new();
        public List<Order> DriverOrders { get; set; } = new();
        public List<PushDevice> PushDevices { get; set; } = new();
    }
}
