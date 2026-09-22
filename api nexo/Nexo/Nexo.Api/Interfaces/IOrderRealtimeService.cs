namespace Nexo.Api.Interfaces
{
    public interface IOrderRealtimeService
    {
        IAsyncEnumerable<string> SubscribeCustomerAsync(
            int userId,
            CancellationToken cancellationToken = default);

        IAsyncEnumerable<string> SubscribeRestaurantAsync(
            int restaurantUserId,
            bool isAdmin,
            CancellationToken cancellationToken = default);

        IAsyncEnumerable<string> SubscribeDriverAsync(
            int driverUserId,
            CancellationToken cancellationToken = default);

        ValueTask PublishCustomerOrderUpdatedAsync(
            int userId,
            string orderId,
            string status);

        ValueTask PublishRestaurantOrdersUpdatedAsync(
            int? restaurantUserId,
            string orderId,
            string status);

        ValueTask PublishDriverOrdersUpdatedAsync(
            string orderId,
            string status);
    }
}
