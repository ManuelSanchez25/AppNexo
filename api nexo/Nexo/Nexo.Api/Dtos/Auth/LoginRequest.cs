namespace Nexo.Api.Dtos.Auth
{
    public class LoginRequest
    {
        public string Identifier { get; set; } = ""; // username, email o telefono
        public string Password { get; set; } = "";
    }
}
