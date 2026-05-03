namespace Nexo.Api.Entitites
{
    public class OrderItemOptionSelection
    {
        public int Id { get; set; }
        public int OrderItemId { get; set; }
        public OrderItem OrderItem { get; set; } = null!;
        public int? ProductOptionId { get; set; }
        public ProductOption? ProductOption { get; set; }
        public string GroupName { get; set; } = string.Empty;
        public string OptionName { get; set; } = string.Empty;
        public decimal PriceDelta { get; set; }
    }
}
