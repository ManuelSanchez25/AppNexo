using Nexo.Api.Entities;

namespace Nexo.Api.Entitites
{
    public class Product
    {
        public int Id { get; set; }
        public int BusinessId { get; set; }
        public Business Business { get; set; } = null!;
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public string ImageUrl { get; set; } = string.Empty;
        public bool IsAvailable { get; set; } = true;
        public List<ProductOptionGroup> OptionGroups { get; set; } = new();
        public List<OrderItem> OrderItems { get; set; } = new();
    }
}
