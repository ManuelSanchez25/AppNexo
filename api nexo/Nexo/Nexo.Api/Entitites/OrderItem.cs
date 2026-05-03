namespace Nexo.Api.Entitites
{
    public class OrderItem
    {
        public int Id { get; set; }
        public int OrderId { get; set; }
        public Order Order { get; set; } = null!;
        public int ProductId { get; set; }
        public Product Product { get; set; } = null!;
        public string ProductName { get; set; } = string.Empty;
        public string ProductImageUrl { get; set; } = string.Empty;
        public string ProductDescription { get; set; } = string.Empty;
        public decimal UnitPrice { get; set; }
        public decimal BaseUnitPrice { get; set; }
        public decimal OptionsUnitPrice { get; set; }
        public int Quantity { get; set; }
        public decimal LineTotal { get; set; }
        public List<OrderItemOptionSelection> SelectedOptions { get; set; } = new();
    }
}
