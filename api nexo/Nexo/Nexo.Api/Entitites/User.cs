using Nexo.Api.Entities;

namespace Nexo.Api.Entitites
{
    public class User
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public UserRole Role { get; set; } = UserRole.Client;
        public DateTime BirthDate { get; set; }
        public string PasswordHash { get; set; } = string.Empty;
        public List<Business> OwnedBusinesses { get; set; } = new();
        public List<Address> Addresses { get; set; } = new();
        public List<Order> Orders { get; set; } = new();
    }
}
