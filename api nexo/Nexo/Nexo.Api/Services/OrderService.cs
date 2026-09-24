using Microsoft.EntityFrameworkCore;
using System.Data;
using System.Security.Cryptography;
using System.Text.Json;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Drivers;
using Nexo.Api.Dtos.Orders;
using Nexo.Api.Entities;
using Nexo.Api.Entitites;
using Nexo.Api.Interfaces;

namespace Nexo.Api.Services
{
    public class OrderService : IOrderService
    {
        private static readonly TimeZoneInfo MexicoCityTimeZone = TimeZoneInfo.FindSystemTimeZoneById("America/Mexico_City");

        private static readonly HashSet<string> AllowedRestaurantStatuses = new(StringComparer.OrdinalIgnoreCase)
        {
            "received",
            "preparing",
            "ready",
            "on_the_way",
            "cancelled"
        };

        private readonly AppDbContext _db;
        private readonly IOrderRealtimeService _realtimeService;

        public OrderService(
            AppDbContext db,
            IOrderRealtimeService realtimeService)
        {
            _db = db;
            _realtimeService = realtimeService;
        }

        public async Task<CreateOrderResponse> CreateAsync(
            CreateOrderRequest request,
            int? userId,
            string clientRequestId,
            CancellationToken cancellationToken = default)
        {
            if (request.Items == null || request.Items.Count == 0)
                throw new InvalidOperationException("La orden debe tener al menos un producto.");
            if (request.Items.Count > 50)
                throw new InvalidOperationException("La orden no puede tener mas de 50 productos diferentes.");
            if (request.AddressId <= 0)
                throw new InvalidOperationException("Debes seleccionar una direccion de entrega.");
            if (request.Items.Any(i => i.Quantity <= 0 || i.Quantity > 20))
                throw new InvalidOperationException("La cantidad de cada producto debe estar entre 1 y 20.");
            if (!userId.HasValue)
                throw new InvalidOperationException("No encontramos un usuario autenticado para esta orden.");
            if (string.IsNullOrWhiteSpace(clientRequestId) || clientRequestId.Length > 64)
                throw new InvalidOperationException("No se pudo validar esta solicitud. Intenta confirmar el pedido nuevamente.");

            var userExists = await _db.Users
                .AnyAsync(u => u.Id == userId.Value, cancellationToken);
            if (!userExists)
                throw new InvalidOperationException("El usuario asociado a la orden no existe.");

            var existingOrderId = await _db.Orders
                .AsNoTracking()
                .Where(o => o.UserId == userId.Value && o.ClientRequestId == clientRequestId)
                .Select(o => (int?)o.Id)
                .FirstOrDefaultAsync(cancellationToken);
            if (existingOrderId.HasValue)
            {
                return await GetOrderResponseByIdAsync(existingOrderId.Value, cancellationToken)
                    ?? throw new InvalidOperationException("No se pudo recuperar el pedido ya creado.");
            }

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

            if (business.ApprovalStatus != "approved")
                throw new InvalidOperationException("Este negocio aun no esta aprobado para recibir pedidos.");

            if (!IsBusinessOpenNow(business))
                throw new InvalidOperationException("Este negocio esta cerrado por horario. Ya no puedes pedir por ahora.");

            if (business.Latitude is decimal businessLatitude &&
                business.Longitude is decimal businessLongitude &&
                address.Latitude is decimal deliveryLatitude &&
                address.Longitude is decimal deliveryLongitude &&
                business.DeliveryRadiusKm >= 0.5 &&
                business.DeliveryRadiusKm <= 50)
            {
                var distanceKm = CalculateDistanceKm(
                    (double)businessLatitude,
                    (double)businessLongitude,
                    (double)deliveryLatitude,
                    (double)deliveryLongitude);

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
                ClientRequestId = clientRequestId,
                AddressId = address.Id,
                Status = "pending_payment",
                PaymentProvider = "mercado_pago",
                PaymentStatus = "pending",
                DeliveryPin = RandomNumberGenerator.GetInt32(0, 10000).ToString("D4"),
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

        public async Task<bool> CancelCustomerOrderAsync(
            string publicId,
            int userId,
            string reason,
            CancellationToken cancellationToken = default)
        {
            var normalizedReason = reason?.Trim() ?? string.Empty;
            if (normalizedReason.Length < 3 || normalizedReason.Length > 200)
                throw new InvalidOperationException("Indica un motivo de cancelacion de 3 a 200 caracteres.");

            var order = await _db.Orders
                .Include(o => o.Business)
                .FirstOrDefaultAsync(
                    o => o.PublicId == publicId && o.UserId == userId,
                    cancellationToken);

            if (order == null) return false;
            if (order.Status is not ("pending_payment" or "received"))
                throw new InvalidOperationException(
                    "Solo puedes cancelar antes de que el restaurante acepte el pedido.");

            order.Status = "cancelled";
            order.CancelledBy = "customer";
            order.CancellationReason = normalizedReason;
            await _db.SaveChangesAsync(cancellationToken);
            await PublishOrderChangeAsync(order);
            return true;
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
                .Where(o => o.PaymentStatus == "approved")
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
                    DriverUserId = o.DriverUserId,
                    BusinessName = o.Business.Name,
                    PickupAddressText = o.Business.AddressText,
                    PickupLatitude = o.Business.Latitude,
                    PickupLongitude = o.Business.Longitude,
                    CustomerName = o.User != null ? o.User.Name : "Cliente",
                    DeliveryAddressText = o.DeliveryAddressText,
                    DeliveryLatitude = o.DeliveryLatitude,
                    DeliveryLongitude = o.DeliveryLongitude,
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

            query = query.Where(o => o.PaymentStatus == "approved");

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

            query = query.Where(o => o.PaymentStatus == "approved");

            var order = await query.FirstOrDefaultAsync(o => o.PublicId == publicId, cancellationToken);
            if (order == null)
                return false;

            if ((order.Status == "delivered" || order.Status == "cancelled") &&
                normalizedStatus != order.Status)
                throw new InvalidOperationException("Este pedido ya esta cerrado.");

            if (order.Status == "on_the_way" && normalizedStatus != "on_the_way")
                throw new InvalidOperationException("El repartidor ya recibio el pedido; el restaurante ya no puede cambiar su estado.");

            if (order.Status == "driver_assigned" &&
                normalizedStatus != "on_the_way" &&
                normalizedStatus != "cancelled")
                throw new InvalidOperationException("El pedido ya tiene repartidor asignado; solo puedes entregarlo al repartidor o cancelarlo.");

            if (normalizedStatus == "delivered")
                throw new InvalidOperationException("La entrega a domicilio la debe confirmar el repartidor.");

            if (normalizedStatus == "driver_assigned")
                throw new InvalidOperationException("Ese estado se asigna cuando un repartidor toma el pedido.");

            if (normalizedStatus == "on_the_way" && !order.DriverUserId.HasValue)
                throw new InvalidOperationException("Primero un repartidor debe tomar el pedido.");

            if (!IsAllowedRestaurantTransition(order.Status, normalizedStatus))
                throw new InvalidOperationException("Ese cambio de estado no es valido para este pedido.");

            order.Status = normalizedStatus;
            if (normalizedStatus == "cancelled")
            {
                order.CancelledBy = isAdmin ? "admin" : "restaurant";
                order.CancellationReason = "Cancelado por el negocio";
            }
            await _db.SaveChangesAsync(cancellationToken);
            if (order.UserId.HasValue)
            {
                await _realtimeService.PublishCustomerOrderUpdatedAsync(
                    order.UserId.Value,
                    order.PublicId,
                    order.Status);
            }
            await _realtimeService.PublishRestaurantOrdersUpdatedAsync(
                order.Business.OwnerUserId,
                order.PublicId,
                order.Status);
            await _realtimeService.PublishDriverOrdersUpdatedAsync(
                order.PublicId,
                order.Status);
            return true;
        }

        public async Task<IReadOnlyList<RestaurantOrderSummaryResponse>> GetAvailableDriverOrdersAsync(
            int driverUserId,
            CancellationToken cancellationToken = default)
        {
            await EnsureApprovedDriverAsync(driverUserId, cancellationToken);

            return await _db.Orders
                .AsNoTracking()
                .Include(o => o.Business)
                .Include(o => o.User)
                .Where(o => o.Status == "ready" && o.DriverUserId == null)
                .OrderBy(o => o.CreatedAt)
                .Select(o => new RestaurantOrderSummaryResponse
                {
                    OrderId = o.PublicId,
                    BusinessId = o.BusinessId,
                    DriverUserId = o.DriverUserId,
                    BusinessName = o.Business.Name,
                    PickupAddressText = o.Business.AddressText,
                    PickupLatitude = o.Business.Latitude,
                    PickupLongitude = o.Business.Longitude,
                    CustomerName = o.User != null ? o.User.Name : "Cliente",
                    DeliveryAddressText = o.DeliveryAddressText,
                    DeliveryLatitude = o.DeliveryLatitude,
                    DeliveryLongitude = o.DeliveryLongitude,
                    Status = o.Status,
                    Total = o.Total,
                    CreatedAt = o.CreatedAt,
                    ItemsCount = o.Items.Count
                })
                .ToListAsync(cancellationToken);
        }

        public async Task<IReadOnlyList<RestaurantOrderSummaryResponse>> GetActiveDriverOrdersAsync(
            int driverUserId,
            CancellationToken cancellationToken = default)
        {
            await EnsureApprovedDriverAsync(driverUserId, cancellationToken);

            return await _db.Orders
                .AsNoTracking()
                .Include(o => o.Business)
                .Include(o => o.User)
                .Where(o => o.DriverUserId == driverUserId &&
                    o.Status != "delivered" &&
                    o.Status != "cancelled")
                .OrderByDescending(o => o.CreatedAt)
                .Select(o => new RestaurantOrderSummaryResponse
                {
                    OrderId = o.PublicId,
                    BusinessId = o.BusinessId,
                    DriverUserId = o.DriverUserId,
                    BusinessName = o.Business.Name,
                    PickupAddressText = o.Business.AddressText,
                    PickupLatitude = o.Business.Latitude,
                    PickupLongitude = o.Business.Longitude,
                    CustomerName = o.User != null ? o.User.Name : "Cliente",
                    DeliveryAddressText = o.DeliveryAddressText,
                    DeliveryLatitude = o.DeliveryLatitude,
                    DeliveryLongitude = o.DeliveryLongitude,
                    Status = o.Status,
                    Total = o.Total,
                    CreatedAt = o.CreatedAt,
                    ItemsCount = o.Items.Count
                })
                .ToListAsync(cancellationToken);
        }

        public async Task<bool> AcceptDriverOrderAsync(
            string publicId,
            int driverUserId,
            CancellationToken cancellationToken = default)
        {
            await EnsureApprovedDriverAsync(driverUserId, cancellationToken);

            await using var transaction = await _db.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            var hasActiveOrder = await _db.Orders.AnyAsync(
                o => o.DriverUserId == driverUserId &&
                     o.Status != "delivered" &&
                     o.Status != "cancelled",
                cancellationToken);
            if (hasActiveOrder)
                throw new InvalidOperationException("Termina tu entrega activa antes de tomar otro pedido.");

            var order = await _db.Orders
                .Include(o => o.Business)
                .FirstOrDefaultAsync(
                    o => o.PublicId == publicId &&
                         o.Status == "ready" &&
                         o.DriverUserId == null,
                    cancellationToken);

            if (order == null) return false;

            order.DriverUserId = driverUserId;
            order.Status = "driver_assigned";
            await _db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            await PublishOrderChangeAsync(order);
            return true;
        }

        public async Task<bool> CompleteDriverOrderAsync(
            string publicId,
            int driverUserId,
            string pin,
            CancellationToken cancellationToken = default)
        {
            await EnsureApprovedDriverAsync(driverUserId, cancellationToken);

            var order = await _db.Orders
                .Include(o => o.Business)
                .FirstOrDefaultAsync(
                    o => o.PublicId == publicId &&
                         o.DriverUserId == driverUserId &&
                         o.Status == "on_the_way",
                    cancellationToken);

            if (order == null) return false;

            var normalizedPin = pin?.Trim() ?? string.Empty;
            if (!string.IsNullOrEmpty(order.DeliveryPin) && normalizedPin != order.DeliveryPin)
                throw new InvalidOperationException("El PIN de entrega no es correcto.");

            order.Status = "delivered";
            order.DeliveredAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(cancellationToken);
            await PublishOrderChangeAsync(order);
            return true;
        }

        public async Task<DriverStatsResponse> GetDriverStatsAsync(
            int driverUserId,
            CancellationToken cancellationToken = default)
        {
            await EnsureApprovedDriverAsync(driverUserId, cancellationToken);

            var today = DateTime.UtcNow.Date;
            var tomorrow = today.AddDays(1);

            var availableOrders = await _db.Orders.CountAsync(
                o => o.Status == "ready" && o.DriverUserId == null,
                cancellationToken);
            var activeOrders = await _db.Orders.CountAsync(
                o => o.DriverUserId == driverUserId &&
                     o.Status != "delivered" &&
                     o.Status != "cancelled",
                cancellationToken);
            var acceptedOrders = await _db.Orders.CountAsync(
                o => o.DriverUserId == driverUserId,
                cancellationToken);
            var deliveredOrders = await _db.Orders.CountAsync(
                o => o.DriverUserId == driverUserId &&
                     o.Status == "delivered",
                cancellationToken);
            var deliveredToday = await _db.Orders.CountAsync(
                o => o.DriverUserId == driverUserId &&
                     o.Status == "delivered" &&
                     o.DeliveredAt >= today &&
                     o.DeliveredAt < tomorrow,
                cancellationToken);
            var todayEarnings = await _db.Orders
                .Where(o => o.DriverUserId == driverUserId &&
                            o.Status == "delivered" &&
                            o.DeliveredAt >= today &&
                            o.DeliveredAt < tomorrow)
                .SumAsync(o => (decimal?)o.Shipping, cancellationToken) ?? 0;
            var totalEarnings = await _db.Orders
                .Where(o => o.DriverUserId == driverUserId &&
                            o.Status == "delivered")
                .SumAsync(o => (decimal?)o.Shipping, cancellationToken) ?? 0;

            return new DriverStatsResponse
            {
                AvailableOrders = availableOrders,
                ActiveOrders = activeOrders,
                AcceptedOrders = acceptedOrders,
                DeliveredOrders = deliveredOrders,
                DeliveredToday = deliveredToday,
                TodayEarnings = todayEarnings,
                TotalEarnings = totalEarnings
            };
        }

        private async Task EnsureApprovedDriverAsync(
            int driverUserId,
            CancellationToken cancellationToken)
        {
            var isApproved = await _db.Users.AnyAsync(
                u => u.Id == driverUserId &&
                     u.Role == UserRole.Driver &&
                     u.DriverApprovalStatus == "approved",
                cancellationToken);

            if (!isApproved)
                throw new InvalidOperationException("Tu cuenta de repartidor aun no esta aprobada.");
        }

        private static bool IsAllowedRestaurantTransition(
            string currentStatus,
            string nextStatus)
        {
            if (currentStatus == nextStatus)
                return true;

            return currentStatus switch
            {
                "received" => nextStatus is "preparing" or "cancelled",
                "preparing" => nextStatus is "ready" or "cancelled",
                "ready" => nextStatus is "cancelled",
                "driver_assigned" => nextStatus is "on_the_way" or "cancelled",
                "on_the_way" => false,
                "delivered" => false,
                "cancelled" => false,
                _ => false
            };
        }

        private async Task PublishOrderChangeAsync(Order order)
        {
            if (order.UserId.HasValue)
            {
                await _realtimeService.PublishCustomerOrderUpdatedAsync(
                    order.UserId.Value,
                    order.PublicId,
                    order.Status);
            }

            await _realtimeService.PublishRestaurantOrdersUpdatedAsync(
                order.Business.OwnerUserId,
                order.PublicId,
                order.Status);
            await _realtimeService.PublishDriverOrdersUpdatedAsync(
                order.PublicId,
                order.Status);
        }

        private static bool IsBusinessOpenNow(Business business)
        {
            var todaySchedule = GetSchedule(business)
                .FirstOrDefault(item => item.Day == TodayNumber());
            if (todaySchedule == null || !todaySchedule.IsOpen)
                return false;

            if (!TimeOnly.TryParseExact(todaySchedule.OpenTime, "HH:mm", out var open) ||
                !TimeOnly.TryParseExact(todaySchedule.CloseTime, "HH:mm", out var close))
                return false;

            if (close <= open)
                return false;

            var now = TimeOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, MexicoCityTimeZone));
            return now >= open && now < close;
        }

        private static List<BusinessOperatingHour> GetSchedule(Business business)
        {
            if (!string.IsNullOrWhiteSpace(business.OperatingHoursJson))
            {
                try
                {
                    var parsed = JsonSerializer.Deserialize<List<BusinessOperatingHour>>(
                        business.OperatingHoursJson);
                    if (parsed != null && parsed.Count > 0)
                        return parsed;
                }
                catch (JsonException)
                {
                    // Fall back to legacy columns below.
                }
            }

            var days = (business.OpenDays ?? string.Empty)
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(day => int.TryParse(day, out var parsed) ? parsed : 0)
                .Where(day => day >= 1 && day <= 7)
                .ToHashSet();

            return Enumerable.Range(1, 7)
                .Select(day => new BusinessOperatingHour
                {
                    Day = day,
                    IsOpen = days.Contains(day),
                    OpenTime = business.OpenTime,
                    CloseTime = business.CloseTime
                })
                .ToList();
        }

        private static int TodayNumber()
        {
            var day = (int)TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, MexicoCityTimeZone).DayOfWeek;
            return day == 0 ? 7 : day;
        }

        private class BusinessOperatingHour
        {
            public int Day { get; set; }
            public bool IsOpen { get; set; }
            public string OpenTime { get; set; } = "09:00";
            public string CloseTime { get; set; } = "22:00";
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

                var minimumSelections = group.IsRequired
                    ? Math.Max(group.MinSelections, 1)
                    : 0;

                if (selectedCount < minimumSelections)
                    throw new InvalidOperationException($"Debes seleccionar opciones en {group.Name}.");

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
                DriverUserId = order.DriverUserId,
                Status = order.Status,
                PaymentStatus = order.PaymentStatus,
                DeliveryPin = order.DeliveryPin,
                CancelledBy = order.CancelledBy,
                CancellationReason = order.CancellationReason,
                Subtotal = order.Subtotal,
                Shipping = order.Shipping,
                Total = order.Total,
                AddressId = order.AddressId ?? 0,
                DeliveryLabel = order.DeliveryLabel,
                RecipientName = order.RecipientName,
                RecipientPhone = order.RecipientPhone,
                DeliveryAddressText = order.DeliveryAddressText,
                CreatedAt = order.CreatedAt,
                DeliveredAt = order.DeliveredAt,
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
