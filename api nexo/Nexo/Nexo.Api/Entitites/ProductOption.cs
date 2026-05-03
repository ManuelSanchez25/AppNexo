namespace Nexo.Api.Entitites
{
    public class ProductOption
    {
        public int Id { get; set; }
        public int ProductOptionGroupId { get; set; }
        public ProductOptionGroup ProductOptionGroup { get; set; } = null!;
        public string Name { get; set; } = string.Empty;
        public decimal PriceDelta { get; set; }
        public bool IsAvailable { get; set; } = true;
        public int SortOrder { get; set; }
        public List<OrderItemOptionSelection> OrderItemSelections { get; set; } = new();
    }
}
