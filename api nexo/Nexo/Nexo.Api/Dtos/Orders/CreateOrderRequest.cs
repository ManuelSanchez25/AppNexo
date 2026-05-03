namespace Nexo.Api.Dtos.Orders
{
    public class CreateOrderRequest
    {
        public int? UserId { get; set; }
        public int AddressId { get; set; }
        public List<CreateOrderItemRequest> Items { get; set; } = new();
    }

    public class CreateOrderItemRequest
    {
        public int ProductId { get; set; }
        public int Quantity { get; set; }
        public List<int> SelectedOptionIds { get; set; } = new();
    }
}
