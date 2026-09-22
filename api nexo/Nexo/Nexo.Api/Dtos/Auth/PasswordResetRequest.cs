namespace Nexo.Api.Dtos.Auth
{
    public class PasswordResetRequest
    {
        public string Email { get; set; } = string.Empty;
    }

    public class ConfirmPasswordResetRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}
