namespace Nexo.Api.Dtos.Orders
{
    public class OrderHistoryItemResponse
    {
        public string OrderId { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public decimal Subtotal { get; set; }
        public decimal Shipping { get; set; }
        public decimal Total { get; set; }
        public DateTime CreatedAt { get; set; }
        public int ItemsCount { get; set; }
    }
}
