namespace Nexo.Api.Dtos.Auth
{
    public class RegisterResponse
    {
        public int UserId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public bool EmailVerified { get; set; }
        public string Role { get; set; } = string.Empty;
        public string DriverApprovalStatus { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;
    }
}
