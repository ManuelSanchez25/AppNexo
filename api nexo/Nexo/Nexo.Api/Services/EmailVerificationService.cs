using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
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
        private readonly IHttpClientFactory _httpClientFactory;

        public EmailVerificationService(
            IConfiguration configuration,
            ILogger<EmailVerificationService> logger,
            IHttpClientFactory httpClientFactory)
        {
            _configuration = configuration;
            _logger = logger;
            _httpClientFactory = httpClientFactory;
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
            var resendApiKey = _configuration["Email:ResendApiKey"];
            var host = _configuration["Email:SmtpHost"];
            var from = _configuration["Email:From"];
            var text = $"{intro}: {code}\n\nExpira en 10 minutos. Si no lo solicitaste, ignora este mensaje.";

            if (!string.IsNullOrWhiteSpace(resendApiKey))
            {
                await SendWithResendAsync(resendApiKey, from, email, subject, text);
                return;
            }

            if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(from))
            {
                throw new InvalidOperationException("El servicio de correo no está configurado.");
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
                EnableSsl = enableSsl,
                Timeout = 15_000
            };

            if (!string.IsNullOrWhiteSpace(username))
            {
                client.Credentials = new NetworkCredential(username, password);
            }

            using var message = new MailMessage(
                from,
                email,
                subject,
                text);

            await client.SendMailAsync(message);
        }

        private async Task SendWithResendAsync(
            string apiKey,
            string? from,
            string email,
            string subject,
            string text)
        {
            if (string.IsNullOrWhiteSpace(from))
                throw new InvalidOperationException("Configura Email:From para enviar correos.");

            var client = _httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(15);
            client.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", apiKey.Trim());

            using var response = await client.PostAsJsonAsync(
                "https://api.resend.com/emails",
                new { from, to = new[] { email }, subject, text });

            if (response.IsSuccessStatusCode) return;

            var detail = await response.Content.ReadAsStringAsync();
            _logger.LogError("Resend rechazó el correo: {Status} {Detail}", response.StatusCode, detail);
            throw new InvalidOperationException(
                "No pudimos enviar el correo de verificación. Revisa la configuración de correo.");
        }
    }
}
