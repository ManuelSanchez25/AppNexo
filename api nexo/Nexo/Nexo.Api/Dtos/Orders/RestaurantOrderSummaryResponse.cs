namespace Nexo.Api.Dtos.Orders
{
    public class RestaurantOrderSummaryResponse
    {
        public string OrderId { get; set; } = string.Empty;
        public int BusinessId { get; set; }
        public string BusinessName { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public decimal Total { get; set; }
        public DateTime CreatedAt { get; set; }
        public int ItemsCount { get; set; }
    }
}
