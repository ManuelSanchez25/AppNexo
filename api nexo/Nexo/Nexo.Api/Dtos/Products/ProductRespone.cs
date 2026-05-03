using Nexo.Api.Entities;

namespace Nexo.Api.Dtos.Products
{
    public class ProductResponse
    {
        public int Id { get; set; }
        public int BusinessId { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public string Description { get; set; } = string.Empty;
        public string Image { get; set; } = string.Empty;
        public bool IsAvailable { get; set; }
        public List<ProductOptionGroupResponse> OptionGroups { get; set; } = new();
    }

    public class ProductOptionGroupResponse
    {
        public int Id { get; set; }
        public int BusinessId { get; set; }
        public string Name { get; set; } = string.Empty;
        public bool IsRequired { get; set; }
        public int MinSelections { get; set; }
        public int MaxSelections { get; set; }
        public int SortOrder { get; set; }
        public int AssignedProductsCount { get; set; }
        public bool IsAssignedToProduct { get; set; }
        public List<ProductOptionResponse> Options { get; set; } = new();
    }

    public class ProductOptionResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal PriceDelta { get; set; }
        public bool IsAvailable { get; set; }
        public int SortOrder { get; set; }
    }
}
