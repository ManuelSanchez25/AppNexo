using Nexo.Api.Dtos.Drivers;
using Nexo.Api.Dtos.Orders;

namespace Nexo.Api.Interfaces
{
    public interface IOrderService
    {
        Task<CreateOrderResponse> CreateAsync(
            CreateOrderRequest request,
            int? userId,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<OrderHistoryItemResponse>> GetHistoryAsync(
            int userId,
            CancellationToken cancellationToken = default);

        Task<CreateOrderResponse?> GetByPublicIdAsync(
            string publicId,
            int userId,
            CancellationToken cancellationToken = default);

        Task<bool> CancelCustomerOrderAsync(
            string publicId,
            int userId,
            string reason,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<RestaurantOrderSummaryResponse>> GetRestaurantOrdersAsync(
            int restaurantUserId,
            bool isAdmin,
            CancellationToken cancellationToken = default);

        Task<CreateOrderResponse?> GetRestaurantOrderByPublicIdAsync(
            string publicId,
            int restaurantUserId,
            bool isAdmin,
            CancellationToken cancellationToken = default);

        Task<bool> UpdateRestaurantOrderStatusAsync(
            string publicId,
            int restaurantUserId,
            bool isAdmin,
            string status,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<RestaurantOrderSummaryResponse>> GetAvailableDriverOrdersAsync(
            int driverUserId,
            CancellationToken cancellationToken = default);

        Task<IReadOnlyList<RestaurantOrderSummaryResponse>> GetActiveDriverOrdersAsync(
            int driverUserId,
            CancellationToken cancellationToken = default);

        Task<DriverStatsResponse> GetDriverStatsAsync(
            int driverUserId,
            CancellationToken cancellationToken = default);

        Task<bool> AcceptDriverOrderAsync(
            string publicId,
            int driverUserId,
            CancellationToken cancellationToken = default);

        Task<bool> CompleteDriverOrderAsync(
            string publicId,
            int driverUserId,
            string pin,
            CancellationToken cancellationToken = default);
    }
}
