using System.Collections.Concurrent;
using System.Text.Json;
using System.Threading.Channels;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Services
{
    public class OrderRealtimeService : IOrderRealtimeService
    {
        private readonly ConcurrentDictionary<string, ConcurrentDictionary<Guid, Channel<string>>> _streams = new();

        public async IAsyncEnumerable<string> SubscribeCustomerAsync(
            int userId,
            [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            await foreach (var message in SubscribeAsync($"customer:{userId}", cancellationToken))
            {
                yield return message;
            }
        }

        public async IAsyncEnumerable<string> SubscribeRestaurantAsync(
            int restaurantUserId,
            bool isAdmin,
            [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            if (isAdmin)
            {
                await foreach (var message in SubscribeAsync("restaurant:admin", cancellationToken))
                {
                    yield return message;
                }

                yield break;
            }

            await foreach (var message in SubscribeAsync($"restaurant:{restaurantUserId}", cancellationToken))
            {
                yield return message;
            }
        }

        public async IAsyncEnumerable<string> SubscribeDriverAsync(
            int driverUserId,
            [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken cancellationToken = default)
        {
            await foreach (var message in SubscribeAsync("driver:available", cancellationToken))
            {
                yield return message;
            }
        }

        public ValueTask PublishCustomerOrderUpdatedAsync(
            int userId,
            string orderId,
            string status)
        {
            var payload = JsonSerializer.Serialize(new
            {
                type = "order-updated",
                orderId,
                status
            });

            return PublishAsync($"customer:{userId}", payload);
        }

        public async ValueTask PublishRestaurantOrdersUpdatedAsync(
            int? restaurantUserId,
            string orderId,
            string status)
        {
            var payload = JsonSerializer.Serialize(new
            {
                type = "restaurant-order-updated",
                orderId,
                status
            });

            if (restaurantUserId.HasValue)
            {
                await PublishAsync($"restaurant:{restaurantUserId.Value}", payload);
            }

            await PublishAsync("restaurant:admin", payload);
        }

        public ValueTask PublishDriverOrdersUpdatedAsync(
            string orderId,
            string status)
        {
            var payload = JsonSerializer.Serialize(new
            {
                type = "driver-order-updated",
                orderId,
                status
            });

            return PublishAsync("driver:available", payload);
        }

        private async IAsyncEnumerable<string> SubscribeAsync(
            string key,
            [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken cancellationToken)
        {
            var channel = Channel.CreateUnbounded<string>();
            var id = Guid.NewGuid();
            var subscribers = _streams.GetOrAdd(
                key,
                _ => new ConcurrentDictionary<Guid, Channel<string>>());

            subscribers[id] = channel;

            try
            {
                yield return "{\"type\":\"connected\"}";

                await foreach (var message in channel.Reader.ReadAllAsync(cancellationToken))
                {
                    yield return message;
                }
            }
            finally
            {
                subscribers.TryRemove(id, out _);
                if (subscribers.IsEmpty)
                {
                    _streams.TryRemove(key, out _);
                }
            }
        }

        private ValueTask PublishAsync(string key, string payload)
        {
            if (!_streams.TryGetValue(key, out var subscribers))
            {
                return ValueTask.CompletedTask;
            }

            foreach (var channel in subscribers.Values)
            {
                channel.Writer.TryWrite(payload);
            }

            return ValueTask.CompletedTask;
        }
    }
}
