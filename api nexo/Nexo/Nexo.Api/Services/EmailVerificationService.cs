using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using Nexo.Api.Entitites;

namespace Nexo.Api.Services
{
    public class EmailVerificationService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<EmailVerificationService> _logger;

        public EmailVerificationService(
            IConfiguration configuration,
            ILogger<EmailVerificationService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public static string GenerateCode()
        {
            return RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        }

        public static string HashCode(User user, string code)
        {
            var value = $"{user.Id}:{user.Email.Trim().ToLower()}:{code.Trim()}";
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value));
            return Convert.ToHexString(bytes);
        }

        public async Task SendVerificationCodeAsync(string email, string code)
        {
            await SendCodeAsync(email, code, "Tu código de verificación Nexo",
                "Tu código para verificar tu correo en Nexo es");
        }

        public async Task SendPasswordResetCodeAsync(string email, string code)
        {
            await SendCodeAsync(email, code, "Restablece tu contraseña de Nexo",
                "Tu código para restablecer tu contraseña en Nexo es");
        }

        private async Task SendCodeAsync(string email, string code, string subject, string intro)
        {
            var host = _configuration["Email:SmtpHost"];
            var from = _configuration["Email:From"];

            if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(from))
            {
                _logger.LogWarning("Código de verificación para {Email}: {Code}", email, code);
                return;
            }

            var port = int.TryParse(_configuration["Email:SmtpPort"], out var parsedPort)
                ? parsedPort
                : 587;
            var enableSsl = !string.Equals(
                _configuration["Email:EnableSsl"],
                "false",
                StringComparison.OrdinalIgnoreCase);
            var username = _configuration["Email:Username"];
            var password = _configuration["Email:Password"];

            using var client = new SmtpClient(host, port)
            {
                EnableSsl = enableSsl
            };

            if (!string.IsNullOrWhiteSpace(username))
            {
                client.Credentials = new NetworkCredential(username, password);
            }

            using var message = new MailMessage(
                from,
                email,
                subject,
                $"{intro}: {code}\n\nExpira en 10 minutos. Si no lo solicitaste, ignora este mensaje.");

            await client.SendMailAsync(message);
        }
    }
}
