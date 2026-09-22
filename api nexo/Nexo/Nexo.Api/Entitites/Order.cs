using Nexo.Api.Entities;

namespace Nexo.Api.Entitites
{
    public class Order
    {
        public int Id { get; set; }
        public string PublicId { get; set; } = Guid.NewGuid().ToString();
        public string ClientRequestId { get; set; } = string.Empty;
        public int BusinessId { get; set; }
        public Business Business { get; set; } = null!;
        public int? UserId { get; set; }
        public User? User { get; set; }
        public int? DriverUserId { get; set; }
        public User? DriverUser { get; set; }
        public string Status { get; set; } = "received";
        public string DeliveryPin { get; set; } = string.Empty;
        public string CancelledBy { get; set; } = string.Empty;
        public string CancellationReason { get; set; } = string.Empty;
        public decimal Subtotal { get; set; }
        public decimal Shipping { get; set; }
        public decimal Total { get; set; }
        public int? AddressId { get; set; }
        public Address? Address { get; set; }
        public string DeliveryLabel { get; set; } = string.Empty;
        public string RecipientName { get; set; } = string.Empty;
        public string RecipientPhone { get; set; } = string.Empty;
        public string DeliveryAddressText { get; set; } = string.Empty;
        public decimal? DeliveryLatitude { get; set; }
        public decimal? DeliveryLongitude { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? DeliveredAt { get; set; }
        public List<OrderItem> Items { get; set; } = new();
    }
}
