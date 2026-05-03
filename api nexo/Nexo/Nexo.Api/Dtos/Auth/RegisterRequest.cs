namespace Nexo.Api.Dtos.Auth
{
    public class RegisterRequest
    {
        public string Name { get; set; } = "";
        public string Email { get; set; } = "";
        public string Password { get; set; } = "";
        public DateTime BirthDate { get; set; }
        public string Role { get; set; } = "";
    }
}
