using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Json;
using System.Net.Mail;
using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Auth;
using Nexo.Api.Entitites;
using Nexo.Api.Services;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly EmailVerificationService _emailVerificationService;
        private readonly PasswordHasher<User> _hasher = new();
        private readonly byte[] _jwtKey;
        private readonly HashSet<string> _googleClientIds;
        private readonly bool _requireEmailVerification;

        public AuthController(
            AppDbContext db,
            IConfiguration configuration,
            EmailVerificationService emailVerificationService)
        {
            _db = db;
            _emailVerificationService = emailVerificationService;

            var jwtKey = configuration["Jwt:Key"]
                ?? throw new InvalidOperationException("No se encontró Jwt:Key en la configuración.");

            if (Encoding.UTF8.GetByteCount(jwtKey) < 32)
                throw new InvalidOperationException("Jwt:Key debe tener al menos 32 bytes para HS256.");

            _jwtKey = Encoding.UTF8.GetBytes(jwtKey);
            _googleClientIds = (configuration["Google:ClientIds"] ?? string.Empty)
                .Split(new[] { ',', ';', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            _requireEmailVerification = bool.TryParse(
                configuration["Email:RequireVerification"],
                out var requireEmailVerification) && requireEmailVerification;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            if (request == null ||
                string.IsNullOrWhiteSpace(request.Identifier) ||
                string.IsNullOrWhiteSpace(request.Password))
            {
                return BadRequest("Faltan datos obligatorios");
            }

            var identifier = request.Identifier.Trim().ToLower();
            var phoneIdentifier = NormalizePhone(request.Identifier);

            var user = await _db.Users.FirstOrDefaultAsync(u =>
                u.Email.ToLower() == identifier ||
                u.Name.ToLower() == identifier ||
                (!string.IsNullOrEmpty(phoneIdentifier) && u.Phone == phoneIdentifier));

            if (user == null)
                return Unauthorized("Usuario o contraseña incorrectos");

            if (_requireEmailVerification &&
                !string.IsNullOrWhiteSpace(user.Email) &&
                !user.EmailVerified)
                return StatusCode(403, "Verifica tu correo antes de entrar.");

            var result = _hasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);

            if (result == PasswordVerificationResult.Failed)
                return Unauthorized("Usuario o contraseña incorrectos");

            return Ok(ToLoginResponse(user));
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            if (request == null ||
                string.IsNullOrWhiteSpace(request.Name) ||
                string.IsNullOrWhiteSpace(request.Password))
            {
                return BadRequest("Faltan datos obligatorios");
            }

            var email = request.Email.Trim().ToLower();
            var phone = NormalizePhone(request.Phone);
            var username = request.Name.Trim().ToLower();
            var requestedRole = ParseRequestedRole(request.Role);

            if (requestedRole == UserRole.Client && !request.AcceptTerms)
                return BadRequest("Debes aceptar los terminos y el aviso de privacidad.");
            if (string.IsNullOrWhiteSpace(email) && string.IsNullOrWhiteSpace(phone))
                return BadRequest("Escribe un correo o telefono");

            if (!string.IsNullOrWhiteSpace(email) && !IsValidEmail(email))
            {
                return BadRequest("Correo no válido");
            }

            if (!string.IsNullOrWhiteSpace(phone) && phone.Length is < 10 or > 15)
                return BadRequest("El celular debe tener entre 10 y 15 digitos.");

            if (requestedRole == null)
                return BadRequest("El tipo de cuenta no es válido");

            if (username.Contains(" "))
                return BadRequest("El nombre de usuario no debe tener espacios");

            if (username.Length < 4)
                return BadRequest("El nombre de usuario es muy corto");

            if (username.Length > 40)
                return BadRequest("El nombre de usuario no puede superar 40 caracteres");

            var passwordError = ValidatePassword(request.Password);
            if (passwordError != null)
                return BadRequest(passwordError);

            var birthDate = DateTime.SpecifyKind(request.BirthDate.Date, DateTimeKind.Utc);
            var birthDateError = ValidateBirthDate(birthDate);
            if (birthDateError != null)
                return BadRequest(birthDateError);
            if (requestedRole == UserRole.Driver && !IsAtLeastAge(birthDate, 18))
                return BadRequest("Debes tener al menos 18 años para registrarte como repartidor.");

            var driverError = requestedRole == UserRole.Driver
                ? ValidateDriverApplication(
                    request.DriverFullName, request.DriverPhone,
                    request.DriverVehicleType, request.DriverVehicleMakeModel,
                    request.DriverVehicleColor, request.DriverVehiclePlate,
                    request.DriverLicenseType, request.DriverLicenseNumber,
                    request.DriverIdentityType, request.DriverIdentityDocument)
                : null;
            if (driverError != null) return BadRequest(driverError);

            var usernameExists = await _db.Users.AnyAsync(u => u.Name == username);
            if (usernameExists)
                return Conflict("Ese nombre de usuario ya existe");

            var emailExists = !string.IsNullOrWhiteSpace(email) &&
                await _db.Users.AnyAsync(u => u.Email == email);
            if (emailExists)
                return Conflict("Ese correo ya existe");

            var accountPhone = requestedRole == UserRole.Driver
                ? NormalizePhone(request.DriverPhone)
                : phone;
            var phoneExists = !string.IsNullOrWhiteSpace(accountPhone) &&
                await _db.Users.AnyAsync(u =>
                    u.Phone == accountPhone || u.DriverPhone == accountPhone);
            if (phoneExists)
                return Conflict("Ese celular ya está registrado en otra cuenta.");

            var user = new User
            {
                Name = username,
                Email = email,
                Phone = accountPhone,
                EmailVerified = !_requireEmailVerification || string.IsNullOrWhiteSpace(email),
                BirthDate = birthDate,
                Role = requestedRole.Value,
                TermsAcceptedAt = request.AcceptTerms ? DateTime.UtcNow : null,
                DriverFullName = requestedRole == UserRole.Driver
                    ? request.DriverFullName.Trim()
                    : string.Empty,
                DriverPhone = requestedRole == UserRole.Driver
                    ? accountPhone
                    : string.Empty,
                DriverVehicleType = requestedRole == UserRole.Driver
                    ? request.DriverVehicleType.Trim()
                    : string.Empty,
                DriverVehicleMakeModel = requestedRole == UserRole.Driver
                    ? request.DriverVehicleMakeModel.Trim()
                    : string.Empty,
                DriverVehicleColor = requestedRole == UserRole.Driver
                    ? request.DriverVehicleColor.Trim()
                    : string.Empty,
                DriverVehiclePlate = requestedRole == UserRole.Driver
                    ? request.DriverVehiclePlate.Trim().ToUpperInvariant()
                    : string.Empty,
                DriverLicenseType = requestedRole == UserRole.Driver
                    ? request.DriverLicenseType.Trim().ToLowerInvariant()
                    : string.Empty,
                DriverLicenseNumber = requestedRole == UserRole.Driver
                    ? request.DriverLicenseNumber.Trim()
                    : string.Empty,
                DriverIdentityType = requestedRole == UserRole.Driver
                    ? request.DriverIdentityType.Trim().ToLowerInvariant()
                    : string.Empty,
                DriverIdentityDocument = requestedRole == UserRole.Driver
                    ? request.DriverIdentityDocument.Trim()
                    : string.Empty,
                DriverApprovalStatus = requestedRole == UserRole.Driver
                    ? "pending"
                    : string.Empty
            };

            user.PasswordHash = _hasher.HashPassword(user, request.Password);

            await using var transaction = await _db.Database.BeginTransactionAsync();
            try
            {
                _db.Users.Add(user);
                await _db.SaveChangesAsync();

                if (_requireEmailVerification && !string.IsNullOrWhiteSpace(user.Email))
                {
                    await SendEmailVerificationCodeAsync(user);
                    await _db.SaveChangesAsync();
                }

                await transaction.CommitAsync();
            }
            catch (DbUpdateException)
            {
                await transaction.RollbackAsync();
                return Conflict("El usuario, correo o celular ya está registrado.");
            }
            catch (Exception)
            {
                await transaction.RollbackAsync();
                return StatusCode(503,
                    "No pudimos enviar el correo de verificación. Inténtalo nuevamente en un momento.");
            }

            var loginResponse = ToLoginResponse(user);
            return Ok(new RegisterResponse
            {
                UserId = loginResponse.UserId,
                Name = loginResponse.Name,
                Email = loginResponse.Email,
                EmailVerified = loginResponse.EmailVerified,
                Role = loginResponse.Role,
                DriverApprovalStatus = loginResponse.DriverApprovalStatus,
                Token = loginResponse.Token
            });
        }

        [HttpPost("google")]
        public async Task<IActionResult> Google([FromBody] GoogleAuthRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.IdToken))
                return BadRequest("No llegó la cuenta de Google.");

            if (_googleClientIds.Count == 0)
                return BadRequest("Configura Google:ClientIds en el backend antes de usar Google Sign-In.");

            var googleUser = await ValidateGoogleTokenAsync(request.IdToken.Trim());
            if (googleUser == null)
                return Unauthorized("No pudimos validar tu cuenta de Google.");

            var email = googleUser.Email.Trim().ToLower();
            var existingUser = await _db.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (existingUser != null)
            {
                if (!existingUser.EmailVerified)
                {
                    existingUser.EmailVerified = true;
                    existingUser.EmailVerificationCodeHash = string.Empty;
                    existingUser.EmailVerificationExpiresAt = null;
                    existingUser.EmailVerificationLastSentAt = null;
                    existingUser.EmailVerificationAttempts = 0;
                    await _db.SaveChangesAsync();
                }

                return Ok(ToLoginResponse(existingUser));
            }

            var requestedRole = ParseRequestedRole(request.Role);
            if (requestedRole == null)
                return BadRequest("El tipo de cuenta no es válido");

            if (!request.BirthDate.HasValue)
                return BadRequest("Completa tu registro con fecha de nacimiento antes de entrar con Google.");

            var birthDate = DateTime.SpecifyKind(request.BirthDate.Value.Date, DateTimeKind.Utc);
            var birthDateError = ValidateBirthDate(birthDate);
            if (birthDateError != null)
                return BadRequest(birthDateError);
            if (requestedRole == UserRole.Driver && !IsAtLeastAge(birthDate, 18))
                return BadRequest("Debes tener al menos 18 años para registrarte como repartidor.");

            var phone = requestedRole == UserRole.Driver
                ? NormalizePhone(request.DriverPhone)
                : NormalizePhone(request.Phone);
            if (requestedRole == UserRole.Client && !request.AcceptTerms)
                return BadRequest("Debes aceptar los terminos y el aviso de privacidad.");

            var phoneExists = !string.IsNullOrEmpty(phone) &&
                await _db.Users.AnyAsync(u => u.Phone == phone || u.DriverPhone == phone);
            if (phoneExists)
                return Conflict("Ese celular ya está registrado en otra cuenta.");

            var driverError = requestedRole == UserRole.Driver
                ? ValidateDriverApplication(
                    request.DriverFullName, request.DriverPhone,
                    request.DriverVehicleType, request.DriverVehicleMakeModel,
                    request.DriverVehicleColor, request.DriverVehiclePlate,
                    request.DriverLicenseType, request.DriverLicenseNumber,
                    request.DriverIdentityType, request.DriverIdentityDocument)
                : null;
            if (driverError != null) return BadRequest(driverError);

            var username = await BuildUniqueUsernameAsync(
                string.IsNullOrWhiteSpace(request.Name) ? googleUser.Name : request.Name,
                email);

            var user = new User
            {
                Name = username,
                Email = email,
                Phone = phone,
                EmailVerified = true,
                BirthDate = birthDate,
                Role = requestedRole.Value,
                TermsAcceptedAt = request.AcceptTerms ? DateTime.UtcNow : null,
                DriverFullName = requestedRole == UserRole.Driver
                    ? request.DriverFullName.Trim()
                    : string.Empty,
                DriverPhone = requestedRole == UserRole.Driver
                    ? phone
                    : string.Empty,
                DriverVehicleType = requestedRole == UserRole.Driver
                    ? request.DriverVehicleType.Trim()
                    : string.Empty,
                DriverVehicleMakeModel = requestedRole == UserRole.Driver
                    ? request.DriverVehicleMakeModel.Trim()
                    : string.Empty,
                DriverVehicleColor = requestedRole == UserRole.Driver
                    ? request.DriverVehicleColor.Trim()
                    : string.Empty,
                DriverVehiclePlate = requestedRole == UserRole.Driver
                    ? request.DriverVehiclePlate.Trim().ToUpperInvariant()
                    : string.Empty,
                DriverLicenseType = requestedRole == UserRole.Driver
                    ? request.DriverLicenseType.Trim().ToLowerInvariant()
                    : string.Empty,
                DriverLicenseNumber = requestedRole == UserRole.Driver
                    ? request.DriverLicenseNumber.Trim()
                    : string.Empty,
                DriverIdentityType = requestedRole == UserRole.Driver
                    ? request.DriverIdentityType.Trim().ToLowerInvariant()
                    : string.Empty,
                DriverIdentityDocument = requestedRole == UserRole.Driver
                    ? request.DriverIdentityDocument.Trim()
                    : string.Empty,
                DriverApprovalStatus = requestedRole == UserRole.Driver
                    ? "pending"
                    : string.Empty
            };

            user.PasswordHash = _hasher.HashPassword(user, Guid.NewGuid().ToString("N"));

            try
            {
                _db.Users.Add(user);
                await _db.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                return Conflict("El usuario, correo o celular ya está registrado.");
            }
            catch (Exception ex)
            {
                return Problem(ex.Message);
            }

            return Ok(ToLoginResponse(user));
        }

        [HttpPost("verify-email")]
        public async Task<IActionResult> VerifyEmail([FromBody] EmailVerificationRequest request)
        {
            if (request == null ||
                string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Code))
            {
                return BadRequest("Escribe tu correo y código.");
            }

            var email = request.Email.Trim().ToLower();
            var code = request.Code.Trim();

            if (!IsValidEmail(email))
                return BadRequest("Correo no válido");

            if (!Regex.IsMatch(code, @"^\d{6}$"))
                return BadRequest("El código debe tener 6 dígitos.");

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (user == null)
                return NotFound("No existe una cuenta con ese correo.");

            if (user.EmailVerified)
                return Ok(ToLoginResponse(user));

            if (user.EmailVerificationAttempts >= 5)
                return StatusCode(429, "Demasiados intentos. Reenvía un código nuevo.");

            if (!user.EmailVerificationExpiresAt.HasValue ||
                user.EmailVerificationExpiresAt.Value < DateTime.UtcNow)
            {
                return BadRequest("El código expiró. Solicita uno nuevo.");
            }

            var expectedHash = EmailVerificationService.HashCode(user, code);
            if (!string.Equals(expectedHash, user.EmailVerificationCodeHash, StringComparison.OrdinalIgnoreCase))
            {
                user.EmailVerificationAttempts++;
                await _db.SaveChangesAsync();
                return BadRequest("Código incorrecto.");
            }

            user.EmailVerified = true;
            user.EmailVerificationCodeHash = string.Empty;
            user.EmailVerificationExpiresAt = null;
            user.EmailVerificationLastSentAt = null;
            user.EmailVerificationAttempts = 0;
            await _db.SaveChangesAsync();

            return Ok(ToLoginResponse(user));
        }

        [HttpPost("resend-email-code")]
        public async Task<IActionResult> ResendEmailCode([FromBody] ResendEmailVerificationRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Email))
                return BadRequest("Escribe tu correo.");

            var email = request.Email.Trim().ToLower();

            if (!IsValidEmail(email))
                return BadRequest("Correo no válido");

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (user == null)
                return NotFound("No existe una cuenta con ese correo.");

            if (user.EmailVerified)
                return Ok("Correo ya verificado.");

            if (user.EmailVerificationLastSentAt.HasValue &&
                user.EmailVerificationLastSentAt.Value.AddSeconds(60) > DateTime.UtcNow)
            {
                return StatusCode(429, "Espera 60 segundos antes de reenviar otro código.");
            }

            await SendEmailVerificationCodeAsync(user);
            await _db.SaveChangesAsync();

            return Ok("Código reenviado.");
        }

        [Authorize]
        [HttpGet("me")]
        public async Task<IActionResult> Me()
        {
            var userId = GetAuthenticatedUserId();
            if (!userId.HasValue)
                return Unauthorized();

            var user = await _db.Users.FindAsync(userId.Value);
            if (user == null)
                return Unauthorized();

            return Ok(ToLoginResponse(user));
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword([FromBody] PasswordResetRequest request)
        {
            if (request == null || !IsValidEmail(request.Email.Trim().ToLower()))
                return BadRequest("Escribe un correo válido.");

            var email = request.Email.Trim().ToLower();
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            const string response = "Si el correo está registrado, recibirás un código en unos minutos.";
            if (user == null) return Ok(response);

            if (user.PasswordResetLastSentAt.HasValue &&
                user.PasswordResetLastSentAt.Value.AddSeconds(60) > DateTime.UtcNow)
                return Ok(response);

            var code = EmailVerificationService.GenerateCode();
            user.PasswordResetCodeHash = EmailVerificationService.HashCode(user, code);
            user.PasswordResetExpiresAt = DateTime.UtcNow.AddMinutes(10);
            user.PasswordResetLastSentAt = DateTime.UtcNow;
            user.PasswordResetAttempts = 0;
            await _db.SaveChangesAsync();
            await _emailVerificationService.SendPasswordResetCodeAsync(user.Email, code);
            return Ok(response);
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromBody] ConfirmPasswordResetRequest request)
        {
            var email = request?.Email.Trim().ToLower() ?? string.Empty;
            var code = request?.Code.Trim() ?? string.Empty;
            if (!IsValidEmail(email) || !Regex.IsMatch(code, @"^\d{6}$"))
                return BadRequest("Revisa el correo y el código de 6 dígitos.");

            var passwordError = ValidatePassword(request!.NewPassword);
            if (passwordError != null) return BadRequest(passwordError);

            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == email);
            if (user == null || user.PasswordResetAttempts >= 5)
                return BadRequest("El código no es válido. Solicita uno nuevo.");
            if (!user.PasswordResetExpiresAt.HasValue || user.PasswordResetExpiresAt < DateTime.UtcNow)
                return BadRequest("El código expiró. Solicita uno nuevo.");

            var expectedHash = EmailVerificationService.HashCode(user, code);
            if (!string.Equals(expectedHash, user.PasswordResetCodeHash, StringComparison.OrdinalIgnoreCase))
            {
                user.PasswordResetAttempts++;
                await _db.SaveChangesAsync();
                return BadRequest("Código incorrecto.");
            }

            user.PasswordHash = _hasher.HashPassword(user, request.NewPassword);
            user.PasswordResetCodeHash = string.Empty;
            user.PasswordResetExpiresAt = null;
            user.PasswordResetLastSentAt = null;
            user.PasswordResetAttempts = 0;
            await _db.SaveChangesAsync();
            return Ok("Contraseña actualizada.");
        }

        [Authorize(Roles = "Driver")]
        [HttpGet("driver-profile")]
        public async Task<IActionResult> DriverProfile()
        {
            var userId = GetAuthenticatedUserId();
            var user = userId.HasValue ? await _db.Users.FindAsync(userId.Value) : null;
            if (user == null || user.Role != UserRole.Driver) return Unauthorized();

            return Ok(new DriverProfileResponse
            {
                Username = user.Name,
                Email = user.Email,
                FullName = user.DriverFullName,
                Phone = user.DriverPhone,
                BirthDate = user.BirthDate,
                ApprovalStatus = user.DriverApprovalStatus,
                VehicleType = user.DriverVehicleType,
                VehicleMakeModel = user.DriverVehicleMakeModel,
                VehicleColor = user.DriverVehicleColor,
                VehiclePlate = MaskValue(user.DriverVehiclePlate),
                LicenseType = user.DriverLicenseType,
                LicenseNumber = MaskValue(user.DriverLicenseNumber),
                IdentityType = user.DriverIdentityType,
                IdentityDocument = MaskValue(user.DriverIdentityDocument)
            });
        }

        private static string MaskValue(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return string.Empty;
            if (value.Length <= 4) return new string('*', value.Length);
            return $"{new string('*', value.Length - 4)}{value[^4..]}";
        }

        private static string? ValidateDriverApplication(
            string fullName,
            string phone,
            string vehicleType,
            string vehicleMakeModel,
            string vehicleColor,
            string vehiclePlate,
            string licenseType,
            string licenseNumber,
            string identityType,
            string identityNumber)
        {
            var normalizedVehicle = vehicleType.Trim().ToLowerInvariant();
            var normalizedIdentity = identityType.Trim().ToLowerInvariant();
            var normalizedLicense = licenseType.Trim().ToLowerInvariant();
            var phoneDigits = Regex.Replace(phone ?? string.Empty, @"\D", string.Empty);

            if (fullName.Trim().Length is < 5 or > 120)
                return "Escribe tu nombre legal completo.";
            if (phoneDigits.Length is < 10 or > 15)
                return "Escribe un telefono valido de 10 a 15 digitos.";
            if (normalizedVehicle is not ("motorcycle" or "bicycle" or "car"))
                return "Selecciona moto, bicicleta o auto.";
            if (normalizedIdentity is not ("ine" or "passport" or "professional_license"))
                return "Selecciona un tipo de identificacion oficial valido.";
            if (identityNumber.Trim().Length is < 5 or > 50)
                return "Escribe el folio de tu identificacion oficial.";

            if (normalizedVehicle == "bicycle") return null;

            if (vehicleMakeModel.Trim().Length is < 2 or > 100)
                return "Escribe la marca y modelo del vehiculo.";
            if (vehicleColor.Trim().Length is < 3 or > 40)
                return "Escribe el color del vehiculo.";
            if (vehiclePlate.Trim().Length is < 4 or > 20)
                return "Escribe una placa valida.";
            if (normalizedLicense is not ("license" or "permit"))
                return "Selecciona licencia de conducir o permiso vigente.";
            if (licenseNumber.Trim().Length is < 5 or > 50)
                return "Escribe el folio de la licencia o permiso.";

            return null;
        }

        private static UserRole? ParseRequestedRole(string? rawRole)
        {
            if (string.IsNullOrWhiteSpace(rawRole))
                return UserRole.Client;

            return rawRole.Trim().ToLower() switch
            {
                "client" => UserRole.Client,
                "restaurant" => UserRole.Restaurant,
                "driver" => UserRole.Driver,
                _ => null
            };
        }

        private static string? ValidatePassword(string password)
        {
            if (password.Length < 8 || password.Length > 20)
                return "La contraseña debe tener entre 8 y 20 caracteres";
            if (!password.Any(char.IsUpper) ||
                !password.Any(char.IsLower) ||
                !password.Any(char.IsDigit))
            {
                return "La contraseña debe incluir mayúscula, minúscula y número";
            }

            return null;
        }

        private static string? ValidateBirthDate(DateTime birthDate)
        {
            var today = DateTime.UtcNow.Date;

            if (birthDate > today || birthDate < today.AddYears(-100))
                return "Fecha de nacimiento inválida";

            var age = today.Year - birthDate.Year;
            if (birthDate > today.AddYears(-age))
                age--;

            return age < 15
                ? "Debes tener al menos 15 años para registrarte"
                : null;
        }

        private static bool IsAtLeastAge(DateTime birthDate, int minimumAge)
        {
            return birthDate.Date <= DateTime.UtcNow.Date.AddYears(-minimumAge);
        }

        private static string NormalizePhone(string? rawPhone)
        {
            if (string.IsNullOrWhiteSpace(rawPhone))
                return string.Empty;

            return Regex.Replace(rawPhone, @"\D", string.Empty);
        }

        private static bool IsValidEmail(string email)
        {
            if (string.IsNullOrWhiteSpace(email) || email.Length > 254)
                return false;

            return MailAddress.TryCreate(email, out var parsed) &&
                string.Equals(parsed.Address, email, StringComparison.OrdinalIgnoreCase) &&
                parsed.Host.Contains('.');
        }

        private async Task SendEmailVerificationCodeAsync(User user)
        {
            var code = EmailVerificationService.GenerateCode();
            user.EmailVerificationCodeHash = EmailVerificationService.HashCode(user, code);
            user.EmailVerificationExpiresAt = DateTime.UtcNow.AddMinutes(10);
            user.EmailVerificationLastSentAt = DateTime.UtcNow;
            user.EmailVerificationAttempts = 0;

            await _emailVerificationService.SendVerificationCodeAsync(user.Email, code);
        }

        private async Task<string> BuildUniqueUsernameAsync(string? preferredName, string email)
        {
            var rawName = string.IsNullOrWhiteSpace(preferredName)
                ? email.Split('@')[0]
                : preferredName.Trim().ToLower();
            var normalized = Regex.Replace(rawName, "[^a-z0-9_]", string.Empty);

            if (normalized.Length < 4)
                normalized = $"user{normalized}";

            if (normalized.Length < 4)
                normalized = $"user{Guid.NewGuid():N}";

            var baseName = normalized.Length > 24 ? normalized[..24] : normalized;
            var candidate = baseName;
            var suffix = 1;

            while (await _db.Users.AnyAsync(u => u.Name == candidate))
            {
                var suffixText = suffix.ToString();
                var prefixLength = Math.Min(baseName.Length, 24 - suffixText.Length);
                candidate = $"{baseName[..prefixLength]}{suffixText}";
                suffix++;
            }

            return candidate;
        }

        private async Task<GoogleTokenInfo?> ValidateGoogleTokenAsync(string idToken)
        {
            using var httpClient = new HttpClient();
            var response = await httpClient.GetAsync(
                $"https://oauth2.googleapis.com/tokeninfo?id_token={Uri.EscapeDataString(idToken)}");

            if (!response.IsSuccessStatusCode)
                return null;

            var tokenInfo = await response.Content.ReadFromJsonAsync<GoogleTokenInfo>();

            if (tokenInfo == null ||
                string.IsNullOrWhiteSpace(tokenInfo.Email) ||
                !string.Equals(tokenInfo.EmailVerified, "true", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            if (!_googleClientIds.Contains(tokenInfo.Audience))
                return null;

            return tokenInfo;
        }

        private LoginResponse ToLoginResponse(User user)
        {
            return new LoginResponse
            {
                UserId = user.Id,
                Name = user.Name,
                Email = user.Email,
                EmailVerified = user.EmailVerified,
                Role = user.Role.ToString(),
                DriverApprovalStatus = user.DriverApprovalStatus,
                Token = GenerateToken(user)
            };
        }

        private int? GetAuthenticatedUserId()
        {
            var claimValue = User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? User.FindFirstValue("sub");

            return int.TryParse(claimValue, out var userId) ? userId : null;
        }

        private string GenerateToken(User user)
        {
            var claims = new List<Claim>
            {
                new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new(ClaimTypes.Name, user.Name),
                new(ClaimTypes.Email, user.Email),
                new(ClaimTypes.Role, user.Role.ToString())
            };

            var credentials = new SigningCredentials(
                new SymmetricSecurityKey(_jwtKey),
                SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                claims: claims,
                expires: DateTime.UtcNow.AddDays(7),
                signingCredentials: credentials);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        private sealed class GoogleTokenInfo
        {
            [JsonPropertyName("aud")]
            public string Audience { get; set; } = string.Empty;

            [JsonPropertyName("email")]
            public string Email { get; set; } = string.Empty;

            [JsonPropertyName("email_verified")]
            public string EmailVerified { get; set; } = string.Empty;

            [JsonPropertyName("name")]
            public string Name { get; set; } = string.Empty;
        }
    }
}
