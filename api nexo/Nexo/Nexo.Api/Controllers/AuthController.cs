using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Auth;
using Nexo.Api.Entitites;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly PasswordHasher<User> _hasher = new();
        private readonly byte[] _jwtKey;

        public AuthController(AppDbContext db, IConfiguration configuration)
        {
            _db = db;

            var jwtKey = configuration["Jwt:Key"]
                ?? throw new InvalidOperationException("No se encontró Jwt:Key en la configuración.");

            if (Encoding.UTF8.GetByteCount(jwtKey) < 32)
                throw new InvalidOperationException("Jwt:Key debe tener al menos 32 bytes para HS256.");

            _jwtKey = Encoding.UTF8.GetBytes(jwtKey);
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

            var user = await _db.Users.FirstOrDefaultAsync(u =>
                u.Email.ToLower() == identifier || u.Name.ToLower() == identifier);

            if (user == null)
                return Unauthorized("Usuario o contraseña incorrectos");

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
                string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Password))
            {
                return BadRequest("Faltan datos obligatorios");
            }

            var email = request.Email.Trim().ToLower();
            var username = request.Name.Trim().ToLower();
            var requestedRole = ParseRequestedRole(request.Role);

            if (requestedRole == null)
                return BadRequest("El tipo de cuenta no es válido");

            if (username.Contains(" "))
                return BadRequest("El nombre de usuario no debe tener espacios");

            if (username.Length < 4)
                return BadRequest("El nombre de usuario es muy corto");

            var today = DateTime.UtcNow.Date;
            var birthDate = DateTime.SpecifyKind(request.BirthDate.Date, DateTimeKind.Utc);

            if (birthDate > today || birthDate < today.AddYears(-100))
                return BadRequest("Fecha de nacimiento inválida");

            var age = today.Year - birthDate.Year;
            if (birthDate > today.AddYears(-age))
                age--;

            if (age < 15)
                return BadRequest("Debes tener al menos 15 años para registrarte");

            var usernameExists = await _db.Users.AnyAsync(u => u.Name == username);
            if (usernameExists)
                return Conflict("Ese nombre de usuario ya existe");

            var emailExists = await _db.Users.AnyAsync(u => u.Email == email);
            if (emailExists)
                return Conflict("Ese correo ya existe");

            var user = new User
            {
                Name = username,
                Email = email,
                BirthDate = birthDate,
                Role = requestedRole.Value
            };

            user.PasswordHash = _hasher.HashPassword(user, request.Password);

            try
            {
                _db.Users.Add(user);
                await _db.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                return Problem(ex.Message);
            }

            var loginResponse = ToLoginResponse(user);
            return Ok(new RegisterResponse
            {
                UserId = loginResponse.UserId,
                Name = loginResponse.Name,
                Email = loginResponse.Email,
                Role = loginResponse.Role,
                Token = loginResponse.Token
            });
        }

        private static UserRole? ParseRequestedRole(string? rawRole)
        {
            if (string.IsNullOrWhiteSpace(rawRole))
                return UserRole.Client;

            return rawRole.Trim().ToLower() switch
            {
                "client" => UserRole.Client,
                "restaurant" => UserRole.Restaurant,
                _ => null
            };
        }

        private LoginResponse ToLoginResponse(User user)
        {
            return new LoginResponse
            {
                UserId = user.Id,
                Name = user.Name,
                Email = user.Email,
                Role = user.Role.ToString(),
                Token = GenerateToken(user)
            };
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
    }
}
