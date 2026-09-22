namespace Nexo.Api.Dtos.Orders
{
    public class RestaurantOrderSummaryResponse
    {
        public string OrderId { get; set; } = string.Empty;
        public int BusinessId { get; set; }
        public int? DriverUserId { get; set; }
        public string BusinessName { get; set; } = string.Empty;
        public string PickupAddressText { get; set; } = string.Empty;
        public decimal? PickupLatitude { get; set; }
        public decimal? PickupLongitude { get; set; }
        public string CustomerName { get; set; } = string.Empty;
        public string DeliveryAddressText { get; set; } = string.Empty;
        public decimal? DeliveryLatitude { get; set; }
        public decimal? DeliveryLongitude { get; set; }
        public string Status { get; set; } = string.Empty;
        public decimal Total { get; set; }
        public DateTime CreatedAt { get; set; }
        public int ItemsCount { get; set; }
    }
}
