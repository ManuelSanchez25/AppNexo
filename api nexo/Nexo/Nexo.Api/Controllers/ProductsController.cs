using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nexo.Api.Data;
using Nexo.Api.Dtos.Products;
using Nexo.Api.Entities;
using Nexo.Api.Entitites;

namespace Nexo.Api.Controllers
{
    [ApiController]
    [Route("api/businesses/{businessId}/products")]
    public class ProductsController : ControllerBase
    {
        private readonly AppDbContext _db;

        public ProductsController(AppDbContext db)
        {
            _db = db;
        }

        [HttpGet]
        public IActionResult GetByBusiness(int businessId)
        {
            var businessExists = _db.Businesses.Any(b => b.Id == businessId);
            if (!businessExists) return NotFound("No existe el negocio");

            var products = _db.Products
                .Where(p => p.BusinessId == businessId && p.IsAvailable)
                .OrderBy(p => p.Name)
                .Include(p => p.OptionGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Products)
                .Include(p => p.OptionGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Options.Where(o => o.IsAvailable).OrderBy(o => o.SortOrder))
                .ToList();

            return Ok(products.Select(p => ToResponse(p, includeUnavailableOptions: false)));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpGet("owned")]
        public IActionResult GetOwnedByBusiness(int businessId)
        {
            var business = GetOwnedBusiness(businessId, out var result);
            if (result != null) return result;
            if (business == null) return NotFound("No existe el negocio");

            var products = _db.Products
                .Where(p => p.BusinessId == businessId)
                .OrderBy(p => p.Name)
                .Include(p => p.OptionGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Products)
                .Include(p => p.OptionGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Options.OrderBy(o => o.SortOrder))
                .ToList();

            return Ok(products.Select(p => ToResponse(p, includeUnavailableOptions: true)));
        }

        [HttpGet("{productId:int}")]
        public IActionResult GetById(int businessId, int productId)
        {
            var product = _db.Products
                .Where(p => p.BusinessId == businessId && p.Id == productId)
                .Include(p => p.OptionGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Products)
                .Include(p => p.OptionGroups.OrderBy(g => g.SortOrder))
                .ThenInclude(g => g.Options.Where(o => o.IsAvailable).OrderBy(o => o.SortOrder))
                .FirstOrDefault();

            if (product == null || !product.IsAvailable)
                return NotFound("No existe el producto");

            return Ok(ToResponse(product, includeUnavailableOptions: false));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPost]
        public IActionResult Create(int businessId, [FromBody] CreateProductRequest request)
        {
            var business = GetOwnedBusiness(businessId, out var result);
            if (result != null) return result;
            if (business == null) return NotFound("No existe el negocio");

            if (request == null) return BadRequest("Producto vacio");
            if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest("El nombre es obligatorio");
            if (request.Price <= 0) return BadRequest("El precio debe ser mayor a 0");

            var normalizedName = request.Name.Trim().ToLower();
            var existsProduct = _db.Products.Any(p =>
                p.BusinessId == businessId &&
                p.Name.ToLower() == normalizedName);

            if (existsProduct)
                return Conflict("Ya existe un producto con ese nombre en este negocio");

            var product = new Product
            {
                BusinessId = businessId,
                Name = request.Name.Trim(),
                Description = request.Description?.Trim() ?? string.Empty,
                Price = request.Price,
                ImageUrl = request.Image?.Trim() ?? string.Empty,
                IsAvailable = request.IsAvailable
            };

            _db.Products.Add(product);
            _db.SaveChanges();

            return Created($"/api/businesses/{businessId}/products/{product.Id}", ToResponse(product, includeUnavailableOptions: true));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPut("{productId:int}")]
        public IActionResult Update(int businessId, int productId, [FromBody] CreateProductRequest request)
        {
            var business = GetOwnedBusiness(businessId, out var result);
            if (result != null) return result;
            if (business == null) return NotFound("No existe el negocio");

            if (request == null) return BadRequest("Producto vacio");
            if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest("El nombre es obligatorio");
            if (request.Price <= 0) return BadRequest("El precio debe ser mayor a 0");

            var product = _db.Products
                .Include(p => p.OptionGroups)
                .ThenInclude(g => g.Products)
                .Include(p => p.OptionGroups)
                .ThenInclude(g => g.Options)
                .FirstOrDefault(p => p.BusinessId == businessId && p.Id == productId);

            if (product == null) return NotFound("No existe el producto");

            var normalizedName = request.Name.Trim().ToLower();
            var existsProduct = _db.Products.Any(p =>
                p.BusinessId == businessId &&
                p.Id != productId &&
                p.Name.ToLower() == normalizedName);

            if (existsProduct)
                return Conflict("Ya existe un producto con ese nombre en este negocio");

            product.Name = request.Name.Trim();
            product.Description = request.Description?.Trim() ?? string.Empty;
            product.Price = request.Price;
            product.ImageUrl = request.Image?.Trim() ?? string.Empty;
            product.IsAvailable = request.IsAvailable;

            _db.SaveChanges();

            return Ok(ToResponse(product, includeUnavailableOptions: true));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpGet("/api/businesses/{businessId}/option-groups")]
        public IActionResult GetBusinessOptionGroups(int businessId, [FromQuery] int? productId = null)
        {
            var business = GetOwnedBusiness(businessId, out var result);
            if (result != null) return result;
            if (business == null) return NotFound("No existe el negocio");

            if (productId.HasValue)
            {
                var productBelongsToBusiness = _db.Products.Any(
                    p => p.BusinessId == businessId && p.Id == productId.Value);
                if (!productBelongsToBusiness)
                    return NotFound("No existe el producto");
            }

            var groups = _db.ProductOptionGroups
                .Where(g => g.BusinessId == businessId)
                .OrderBy(g => g.SortOrder)
                .Include(g => g.Products)
                .Include(g => g.Options.OrderBy(o => o.SortOrder))
                .ToList();

            return Ok(groups.Select(g => ToGroupResponse(
                g,
                includeUnavailableOptions: true,
                assignedProductId: productId)));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPost("{productId:int}/option-groups")]
        public IActionResult CreateOptionGroup(int businessId, int productId, [FromBody] CreateProductOptionGroupRequest request)
        {
            var product = GetOwnedProduct(businessId, productId, out var result);
            if (result != null) return result;
            if (product == null) return NotFound("No existe el producto");

            if (request == null || string.IsNullOrWhiteSpace(request.Name))
                return BadRequest("El nombre del grupo es obligatorio");
            if (request.MinSelections < 0 || request.MaxSelections < 0)
                return BadRequest("Los limites de seleccion no son validos");
            if (request.MaxSelections > 0 && request.MinSelections > request.MaxSelections)
                return BadRequest("El minimo no puede ser mayor al maximo");

            var group = new ProductOptionGroup
            {
                BusinessId = businessId,
                Name = request.Name.Trim(),
                IsRequired = request.IsRequired,
                MinSelections = request.MinSelections,
                MaxSelections = request.MaxSelections,
                SortOrder = request.SortOrder
            };
            group.Products.Add(product);

            _db.ProductOptionGroups.Add(group);
            _db.SaveChanges();

            return Ok(ToGroupResponse(group, includeUnavailableOptions: true, assignedProductId: productId));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPut("{productId:int}/option-groups/{groupId:int}")]
        public IActionResult UpdateOptionGroup(int businessId, int productId, int groupId, [FromBody] CreateProductOptionGroupRequest request)
        {
            var product = GetOwnedProduct(businessId, productId, out var result);
            if (result != null) return result;
            if (product == null) return NotFound("No existe el producto");

            if (request == null || string.IsNullOrWhiteSpace(request.Name))
                return BadRequest("El nombre del grupo es obligatorio");
            if (request.MinSelections < 0 || request.MaxSelections < 0)
                return BadRequest("Los limites de seleccion no son validos");
            if (request.MaxSelections > 0 && request.MinSelections > request.MaxSelections)
                return BadRequest("El minimo no puede ser mayor al maximo");

            var group = _db.ProductOptionGroups
                .Include(g => g.Products)
                .Include(g => g.Options)
                .FirstOrDefault(g => g.Id == groupId && g.BusinessId == businessId);

            if (group == null) return NotFound("No existe el grupo");

            group.Name = request.Name.Trim();
            group.IsRequired = request.IsRequired;
            group.MinSelections = request.MinSelections;
            group.MaxSelections = request.MaxSelections;
            group.SortOrder = request.SortOrder;

            if (!group.Products.Any(p => p.Id == productId))
            {
                group.Products.Add(product);
            }

            _db.SaveChanges();

            return Ok(ToGroupResponse(group, includeUnavailableOptions: true, assignedProductId: productId));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPost("{productId:int}/option-groups/{groupId:int}/attach")]
        public IActionResult AttachOptionGroup(int businessId, int productId, int groupId)
        {
            var product = GetOwnedProduct(businessId, productId, out var result);
            if (result != null) return result;
            if (product == null) return NotFound("No existe el producto");

            var group = _db.ProductOptionGroups
                .Include(g => g.Products)
                .Include(g => g.Options)
                .FirstOrDefault(g => g.Id == groupId && g.BusinessId == businessId);

            if (group == null) return NotFound("No existe el grupo");

            if (!group.Products.Any(p => p.Id == productId))
            {
                group.Products.Add(product);
                _db.SaveChanges();
            }

            return Ok(ToGroupResponse(group, includeUnavailableOptions: true, assignedProductId: productId));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpDelete("{productId:int}/option-groups/{groupId:int}/attach")]
        public IActionResult DetachOptionGroup(int businessId, int productId, int groupId)
        {
            var product = GetOwnedProduct(businessId, productId, out var result);
            if (result != null) return result;
            if (product == null) return NotFound("No existe el producto");

            var group = _db.ProductOptionGroups
                .Include(g => g.Products)
                .FirstOrDefault(g => g.Id == groupId && g.BusinessId == businessId);

            if (group == null) return NotFound("No existe el grupo");

            var assignedProduct = group.Products.FirstOrDefault(p => p.Id == productId);
            if (assignedProduct != null)
            {
                group.Products.Remove(assignedProduct);
                _db.SaveChanges();
            }

            return NoContent();
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPost("{productId:int}/option-groups/{groupId:int}/options")]
        public IActionResult CreateOption(int businessId, int productId, int groupId, [FromBody] CreateProductOptionRequest request)
        {
            var product = GetOwnedProduct(businessId, productId, out var result);
            if (result != null) return result;
            if (product == null) return NotFound("No existe el producto");
            if (request == null || string.IsNullOrWhiteSpace(request.Name))
                return BadRequest("El nombre de la opcion es obligatorio");

            var group = _db.ProductOptionGroups
                .Include(g => g.Products)
                .FirstOrDefault(g => g.Id == groupId && g.BusinessId == businessId);

            if (group == null) return NotFound("No existe el grupo");
            if (!group.Products.Any(p => p.Id == productId))
                return BadRequest("El grupo no esta asignado a este producto");

            var option = new ProductOption
            {
                ProductOptionGroupId = groupId,
                Name = request.Name.Trim(),
                PriceDelta = request.PriceDelta,
                IsAvailable = request.IsAvailable,
                SortOrder = request.SortOrder
            };

            _db.ProductOptions.Add(option);
            _db.SaveChanges();

            return Ok(ToOptionResponse(option));
        }

        [Authorize(Roles = "Restaurant,Admin")]
        [HttpPut("{productId:int}/option-groups/{groupId:int}/options/{optionId:int}")]
        public IActionResult UpdateOption(int businessId, int productId, int groupId, int optionId, [FromBody] CreateProductOptionRequest request)
        {
            var product = GetOwnedProduct(businessId, productId, out var result);
            if (result != null) return result;
            if (product == null) return NotFound("No existe el producto");
            if (request == null || string.IsNullOrWhiteSpace(request.Name))
                return BadRequest("El nombre de la opcion es obligatorio");

            var option = _db.ProductOptions
                .Include(o => o.ProductOptionGroup)
                .ThenInclude(g => g.Products)
                .FirstOrDefault(o =>
                    o.Id == optionId &&
                    o.ProductOptionGroupId == groupId &&
                    o.ProductOptionGroup.BusinessId == businessId);

            if (option == null) return NotFound("No existe la opcion");
            if (!option.ProductOptionGroup.Products.Any(p => p.Id == productId))
                return BadRequest("El grupo no esta asignado a este producto");

            option.Name = request.Name.Trim();
            option.PriceDelta = request.PriceDelta;
            option.IsAvailable = request.IsAvailable;
            option.SortOrder = request.SortOrder;

            _db.SaveChanges();

            return Ok(ToOptionResponse(option));
        }

        private int? GetCurrentUserId()
        {
            var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
            return int.TryParse(value, out var userId) ? userId : null;
        }

        private bool IsAdmin()
        {
            return string.Equals(
                User.FindFirstValue(ClaimTypes.Role),
                "Admin",
                StringComparison.OrdinalIgnoreCase);
        }

        private Business? GetOwnedBusiness(int businessId, out IActionResult? result)
        {
            result = null;
            var userId = GetCurrentUserId();
            if (userId == null)
            {
                result = Unauthorized();
                return null;
            }

            var business = _db.Businesses.FirstOrDefault(b => b.Id == businessId);
            if (business == null)
            {
                result = NotFound("No existe el negocio");
                return null;
            }

            if (!IsAdmin() && business.OwnerUserId != userId.Value)
            {
                result = Forbid();
                return null;
            }

            return business;
        }

        private Product? GetOwnedProduct(int businessId, int productId, out IActionResult? result)
        {
            result = null;
            var business = GetOwnedBusiness(businessId, out result);
            if (result != null || business == null) return null;

            return _db.Products
                .Include(p => p.OptionGroups)
                .ThenInclude(g => g.Products)
                .Include(p => p.OptionGroups)
                .ThenInclude(g => g.Options)
                .FirstOrDefault(p => p.BusinessId == businessId && p.Id == productId);
        }

        private static ProductResponse ToResponse(Product product, bool includeUnavailableOptions)
        {
            var optionGroups = product.OptionGroups
                .OrderBy(g => g.SortOrder)
                .Select(g => ToGroupResponse(g, includeUnavailableOptions, assignedProductId: product.Id))
                .Where(g => includeUnavailableOptions || g.Options.Count > 0)
                .ToList();

            return new ProductResponse
            {
                Id = product.Id,
                BusinessId = product.BusinessId,
                Name = product.Name,
                Description = product.Description,
                Price = product.Price,
                Image = product.ImageUrl,
                IsAvailable = product.IsAvailable,
                OptionGroups = optionGroups
            };
        }

        private static ProductOptionGroupResponse ToGroupResponse(
            ProductOptionGroup group,
            bool includeUnavailableOptions,
            int? assignedProductId = null)
        {
            return new ProductOptionGroupResponse
            {
                Id = group.Id,
                BusinessId = group.BusinessId,
                Name = group.Name,
                IsRequired = group.IsRequired,
                MinSelections = group.MinSelections,
                MaxSelections = group.MaxSelections,
                SortOrder = group.SortOrder,
                AssignedProductsCount = group.Products.Count,
                IsAssignedToProduct = assignedProductId.HasValue &&
                    group.Products.Any(p => p.Id == assignedProductId.Value),
                Options = group.Options
                    .Where(o => includeUnavailableOptions || o.IsAvailable)
                    .OrderBy(o => o.SortOrder)
                    .Select(ToOptionResponse)
                    .ToList()
            };
        }

        private static ProductOptionResponse ToOptionResponse(ProductOption option)
        {
            return new ProductOptionResponse
            {
                Id = option.Id,
                Name = option.Name,
                PriceDelta = option.PriceDelta,
                IsAvailable = option.IsAvailable,
                SortOrder = option.SortOrder
            };
        }
    }
}
