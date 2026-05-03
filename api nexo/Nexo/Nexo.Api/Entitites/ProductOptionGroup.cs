using Nexo.Api.Entities;

namespace Nexo.Api.Entitites
{
    public class ProductOptionGroup
    {
        public int Id { get; set; }
        public int BusinessId { get; set; }
        public Business Business { get; set; } = null!;
        public string Name { get; set; } = string.Empty;
        public bool IsRequired { get; set; }
        public int MinSelections { get; set; }
        public int MaxSelections { get; set; }
        public int SortOrder { get; set; }
        public List<Product> Products { get; set; } = new();
        public List<ProductOption> Options { get; set; } = new();
    }
}
