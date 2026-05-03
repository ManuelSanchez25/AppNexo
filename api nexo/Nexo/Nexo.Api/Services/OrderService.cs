using Microsoft.EntityFrameworkCore;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Orders;
using Nexo.Api.Entitites;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Services
{
    public class OrderService : IOrderService
    {
        private static readonly HashSet<string> AllowedRestaurantStatuses = new(StringComparer.OrdinalIgnoreCase)
        {
            "received",
            "preparing",
            "ready",
            "delivered",
            "cancelled"
        };

        private readonly AppDbContext _db;

        public OrderService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<CreateOrderResponse> CreateAsync(
            CreateOrderRequest request,
            int? userId,
            CancellationToken cancellationToken = default)
        {
            if (request.Items == null || request.Items.Count == 0)
                throw new InvalidOperationException("La orden debe tener al menos un producto.");
            if (request.AddressId <= 0)
                throw new InvalidOperationException("Debes seleccionar una direccion de entrega.");
            if (request.Items.Any(i => i.Quantity <= 0))
                throw new InvalidOperationException("La cantidad debe ser mayor a 0.");
            if (!userId.HasValue)
                throw new InvalidOperationException("No encontramos un usuario autenticado para esta orden.");

            var userExists = await _db.Users
                .AnyAsync(u => u.Id == userId.Value, cancellationToken);
            if (!userExists)
                throw new InvalidOperationException("El usuario asociado a la orden no existe.");

            var address = await _db.Addresses
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    a => a.Id == request.AddressId && a.UserId == userId.Value,
                    cancellationToken);

            if (address == null)
                throw new InvalidOperationException("La direccion seleccionada no existe o no te pertenece.");

            var productIds = request.Items
                .Select(i => i.ProductId)
                .Distinct()
                .ToList();

            var productsFromDb = await _db.Products
                .Include(p => p.OptionGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Options.OrderBy(o => o.SortOrder))
                .Where(p => productIds.Contains(p.Id))
                .ToListAsync(cancellationToken);

            if (productsFromDb.Count != productIds.Count)
            {
                var foundIds = productsFromDb.Select(p => p.Id).ToHashSet();
                var missing = productIds.Where(id => !foundIds.Contains(id)).ToList();
                throw new KeyNotFoundException(
                    $"Uno o mas productos no existen. Faltan: {string.Join(", ", missing)}");
            }

            var businessIds = productsFromDb.Select(p => p.BusinessId).Distinct().ToList();
            if (businessIds.Count != 1)
                throw new InvalidOperationException("Todos los productos del pedido deben ser del mismo negocio.");

            var business = await _db.Businesses
                .AsNoTracking()
                .FirstOrDefaultAsync(b => b.Id == businessIds[0], cancellationToken);

            if (business == null)
                throw new InvalidOperationException("No encontramos el negocio de este pedido.");
            var canValidateCoverage =
                business.Latitude.HasValue &&
                business.Longitude.HasValue &&
                address.Latitude.HasValue &&
                address.Longitude.HasValue &&
                business.DeliveryRadiusKm >= 0.5 &&
                business.DeliveryRadiusKm <= 50;

            if (canValidateCoverage)
            {
                var distanceKm = CalculateDistanceKm(
                    (double)business.Latitude.Value,
                    (double)business.Longitude.Value,
                    (double)address.Latitude.Value,
                    (double)address.Longitude.Value);

                if (distanceKm > business.DeliveryRadiusKm)
                {
                    throw new InvalidOperationException(
                        $"Tu direccion esta fuera del radio de entrega de este negocio ({business.DeliveryRadiusKm:0.0} km).");
                }
            }

            if (productsFromDb.Any(p => !p.IsAvailable))
                throw new InvalidOperationException("Uno o mas productos ya no estan disponibles.");

            decimal subtotal = 0m;
            var orderItems = new List<OrderItem>();

            foreach (var item in request.Items)
            {
                var product = productsFromDb.First(p => p.Id == item.ProductId);
                var selectedOptions = BuildSelectedOptions(product, item.SelectedOptionIds);
                var optionsUnitPrice = selectedOptions.Sum(o => o.PriceDelta);
                var finalUnitPrice = product.Price + optionsUnitPrice;
                var lineTotal = finalUnitPrice * item.Quantity;
                subtotal += lineTotal;

                orderItems.Add(new OrderItem
                {
                    ProductId = product.Id,
                    ProductName = product.Name,
                    ProductDescription = product.Description,
                    ProductImageUrl = product.ImageUrl,
                    BaseUnitPrice = product.Price,
                    OptionsUnitPrice = optionsUnitPrice,
                    UnitPrice = finalUnitPrice,
                    Quantity = item.Quantity,
                    LineTotal = lineTotal,
                    SelectedOptions = selectedOptions
                });
            }

            decimal shipping = subtotal >= 200m ? 0m : 15m;
            decimal total = subtotal + shipping;

            var order = new Order
            {
                BusinessId = businessIds[0],
                UserId = userId,
                AddressId = address.Id,
                Status = "received",
                Subtotal = subtotal,
                Shipping = shipping,
                Total = total,
                DeliveryLabel = address.Label,
                RecipientName = address.RecipientName,
                RecipientPhone = address.Phone,
                DeliveryAddressText = BuildFullAddress(address),
                DeliveryLatitude = address.Latitude,
                DeliveryLongitude = address.Longitude,
                CreatedAt = DateTime.UtcNow,
                Items = orderItems
            };

            _db.Orders.Add(order);
            await _db.SaveChangesAsync(cancellationToken);

            return await GetOrderResponseByIdAsync(order.Id, cancellationToken)
                ?? throw new InvalidOperationException("No se pudo cargar la orden creada.");
        }

        public async Task<IReadOnlyList<OrderHistoryItemResponse>> GetHistoryAsync(
            int userId,
            CancellationToken cancellationToken = default)
        {
            return await _db.Orders
                .AsNoTracking()
                .Where(o => o.UserId == userId)
                .OrderByDescending(o => o.CreatedAt)
                .Select(o => new OrderHistoryItemResponse
                {
                    OrderId = o.PublicId,
                    Status = o.Status,
                    Subtotal = o.Subtotal,
                    Shipping = o.Shipping,
                    Total = o.Total,
                    CreatedAt = o.CreatedAt,
                    ItemsCount = o.Items.Count
                })
                .ToListAsync(cancellationToken);
        }

        public async Task<CreateOrderResponse?> GetByPublicIdAsync(
            string publicId,
            int userId,
            CancellationToken cancellationToken = default)
        {
            var order = await _db.Orders
                .AsNoTracking()
                .Include(o => o.Items)
                .ThenInclude(i => i.SelectedOptions)
                .FirstOrDefaultAsync(
                    o => o.PublicId == publicId && o.UserId == userId,
                    cancellationToken);

            return order == null ? null : MapOrder(order);
        }

        public async Task<IReadOnlyList<RestaurantOrderSummaryResponse>> GetRestaurantOrdersAsync(
            int restaurantUserId,
            bool isAdmin,
            CancellationToken cancellationToken = default)
        {
            var query = _db.Orders
                .AsNoTracking()
                .Include(o => o.Business)
                .Include(o => o.User)
                .OrderByDescending(o => o.CreatedAt)
                .AsQueryable();

            if (!isAdmin)
            {
                query = query.Where(o => o.Business.OwnerUserId == restaurantUserId);
            }

            return await query
                .Select(o => new RestaurantOrderSummaryResponse
                {
                    OrderId = o.PublicId,
                    BusinessId = o.BusinessId,
                    BusinessName = o.Business.Name,
                    CustomerName = o.User != null ? o.User.Name : "Cliente",
                    Status = o.Status,
                    Total = o.Total,
                    CreatedAt = o.CreatedAt,
                    ItemsCount = o.Items.Count
                })
                .ToListAsync(cancellationToken);
        }

        public async Task<CreateOrderResponse?> GetRestaurantOrderByPublicIdAsync(
            string publicId,
            int restaurantUserId,
            bool isAdmin,
            CancellationToken cancellationToken = default)
        {
            var query = _db.Orders
                .AsNoTracking()
                .Include(o => o.Business)
                .Include(o => o.Items)
                .ThenInclude(i => i.SelectedOptions)
                .AsQueryable();

            if (!isAdmin)
            {
                query = query.Where(o => o.Business.OwnerUserId == restaurantUserId);
            }

            var order = await query.FirstOrDefaultAsync(o => o.PublicId == publicId, cancellationToken);
            return order == null ? null : MapOrder(order);
        }

        public async Task<bool> UpdateRestaurantOrderStatusAsync(
            string publicId,
            int restaurantUserId,
            bool isAdmin,
            string status,
            CancellationToken cancellationToken = default)
        {
            var normalizedStatus = status.Trim().ToLower();
            if (!AllowedRestaurantStatuses.Contains(normalizedStatus))
                throw new InvalidOperationException("El status solicitado no es valido.");

            var query = _db.Orders
                .Include(o => o.Business)
                .AsQueryable();

            if (!isAdmin)
            {
                query = query.Where(o => o.Business.OwnerUserId == restaurantUserId);
            }

            var order = await query.FirstOrDefaultAsync(o => o.PublicId == publicId, cancellationToken);
            if (order == null)
                return false;

            order.Status = normalizedStatus;
            await _db.SaveChangesAsync(cancellationToken);
            return true;
        }

        private List<OrderItemOptionSelection> BuildSelectedOptions(Product product, List<int>? selectedOptionIds)
        {
            var optionIds = (selectedOptionIds ?? new List<int>())
                .Distinct()
                .ToList();

            var allOptions = product.OptionGroups
                .SelectMany(g => g.Options.Select(o => new { Group = g, Option = o }))
                .ToList();

            var missingIds = optionIds.Where(id => allOptions.All(o => o.Option.Id != id)).ToList();
            if (missingIds.Count > 0)
                throw new InvalidOperationException("Una o mas opciones seleccionadas no pertenecen al producto.");

            var selectedByGroup = allOptions
                .Where(o => optionIds.Contains(o.Option.Id))
                .GroupBy(o => o.Group.Id)
                .ToDictionary(g => g.Key, g => g.ToList());

            foreach (var group in product.OptionGroups)
            {
                var selectedCount = selectedByGroup.TryGetValue(group.Id, out var selections)
                    ? selections.Count
                    : 0;

                if (group.IsRequired && selectedCount < Math.Max(group.MinSelections, 1))
                    throw new InvalidOperationException($"Debes seleccionar opciones en {group.Name}.");

                if (selectedCount < group.MinSelections)
                    throw new InvalidOperationException($"Selecciona al menos {group.MinSelections} opciones en {group.Name}.");

                if (group.MaxSelections > 0 && selectedCount > group.MaxSelections)
                    throw new InvalidOperationException($"Solo puedes seleccionar hasta {group.MaxSelections} opciones en {group.Name}.");
            }

            var unavailableSelections = selectedByGroup.Values
                .SelectMany(v => v)
                .Where(v => !v.Option.IsAvailable)
                .Select(v => v.Option.Name)
                .ToList();

            if (unavailableSelections.Count > 0)
                throw new InvalidOperationException($"Estas opciones ya no estan disponibles: {string.Join(", ", unavailableSelections)}");

            return selectedByGroup.Values
                .SelectMany(v => v)
                .OrderBy(v => v.Group.SortOrder)
                .ThenBy(v => v.Option.SortOrder)
                .Select(v => new OrderItemOptionSelection
                {
                    ProductOptionId = v.Option.Id,
                    GroupName = v.Group.Name,
                    OptionName = v.Option.Name,
                    PriceDelta = v.Option.PriceDelta
                })
                .ToList();
        }

        private async Task<CreateOrderResponse?> GetOrderResponseByIdAsync(int orderId, CancellationToken cancellationToken)
        {
            var order = await _db.Orders
                .AsNoTracking()
                .Include(o => o.Items)
                .ThenInclude(i => i.SelectedOptions)
                .FirstOrDefaultAsync(o => o.Id == orderId, cancellationToken);

            return order == null ? null : MapOrder(order);
        }

        private static CreateOrderResponse MapOrder(Order order)
        {
            return new CreateOrderResponse
            {
                OrderId = order.PublicId,
                BusinessId = order.BusinessId,
                Status = order.Status,
                Subtotal = order.Subtotal,
                Shipping = order.Shipping,
                Total = order.Total,
                AddressId = order.AddressId ?? 0,
                DeliveryLabel = order.DeliveryLabel,
                RecipientName = order.RecipientName,
                RecipientPhone = order.RecipientPhone,
                DeliveryAddressText = order.DeliveryAddressText,
                CreatedAt = order.CreatedAt,
                Items = order.Items
                    .Select(item => new CreateOrderItemResponse
                    {
                        ProductId = item.ProductId,
                        Name = item.ProductName,
                        Price = item.UnitPrice,
                        Quantity = item.Quantity,
                        LineTotal = item.LineTotal,
                        ImageUrl = item.ProductImageUrl,
                        SelectedOptions = item.SelectedOptions
                            .OrderBy(o => o.GroupName)
                            .ThenBy(o => o.OptionName)
                            .Select(option => new CreateOrderItemOptionResponse
                            {
                                GroupName = option.GroupName,
                                Name = option.OptionName,
                                PriceDelta = option.PriceDelta
                            })
                            .ToList()
                    })
                    .ToList()
            };
        }

        private static string BuildFullAddress(Address address)
        {
            var line1 = address.Street;
            if (!string.IsNullOrWhiteSpace(address.ExteriorNumber))
            {
                line1 += $" {address.ExteriorNumber}";
            }
            if (!string.IsNullOrWhiteSpace(address.InteriorNumber))
            {
                line1 += $" Int. {address.InteriorNumber}";
            }

            return $"{line1}, {address.Neighborhood}, {address.City}, {address.State}, CP {address.PostalCode}";
        }

        private static double CalculateDistanceKm(
            double originLat,
            double originLng,
            double destinationLat,
            double destinationLng)
        {
            const double earthRadiusKm = 6371d;
            var dLat = DegreesToRadians(destinationLat - originLat);
            var dLng = DegreesToRadians(destinationLng - originLng);

            var a =
                Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(DegreesToRadians(originLat)) *
                Math.Cos(DegreesToRadians(destinationLat)) *
                Math.Sin(dLng / 2) * Math.Sin(dLng / 2);

            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return earthRadiusKm * c;
        }

        private static double DegreesToRadians(double degrees)
        {
            return degrees * Math.PI / 180d;
        }
    }
}
