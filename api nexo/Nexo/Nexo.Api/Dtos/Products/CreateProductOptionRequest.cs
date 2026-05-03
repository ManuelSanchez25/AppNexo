namespace Nexo.Api.Dtos.Products
{
    public class CreateProductOptionRequest
    {
        public string Name { get; set; } = string.Empty;
        public decimal PriceDelta { get; set; }
        public bool IsAvailable { get; set; } = true;
        public int SortOrder { get; set; }
    }
}
