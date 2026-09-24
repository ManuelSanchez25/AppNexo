namespace Nexo.Api.Dtos.Orders
{
    public class CreateOrderResponse
    {
        public string OrderId { get; set; } = string.Empty;
        public int BusinessId { get; set; }
        public int? DriverUserId { get; set; }
        public string Status { get; set; } = string.Empty;
        public string PaymentStatus { get; set; } = string.Empty;
        public string DeliveryPin { get; set; } = string.Empty;
        public string CancelledBy { get; set; } = string.Empty;
        public string CancellationReason { get; set; } = string.Empty;
        public decimal Subtotal { get; set; }
        public decimal Shipping { get; set; }
        public decimal Total { get; set; }
        public int AddressId { get; set; }
        public string DeliveryLabel { get; set; } = string.Empty;
        public string RecipientName { get; set; } = string.Empty;
        public string RecipientPhone { get; set; } = string.Empty;
        public string DeliveryAddressText { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime? DeliveredAt { get; set; }
        public List<CreateOrderItemResponse> Items { get; set; } = new();
    }

    public class CreateOrderItemResponse
    {
        public int ProductId { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public int Quantity { get; set; }
        public decimal LineTotal { get; set; }
        public string ImageUrl { get; set; } = string.Empty;
        public List<CreateOrderItemOptionResponse> SelectedOptions { get; set; } = new();
    }

    public class CreateOrderItemOptionResponse
    {
        public string GroupName { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public decimal PriceDelta { get; set; }
    }
}
