namespace Nexo.Api.Dtos.Auth
{
    public class EmailVerificationRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
