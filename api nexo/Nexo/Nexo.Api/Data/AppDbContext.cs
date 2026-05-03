using Microsoft.EntityFrameworkCore;
using Nexo.Api.Entities;
using Nexo.Api.Entitites;

namespace Nexo.Api.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options)
        {
        }

        public DbSet<Business> Businesses { get; set; } = null!;
        public DbSet<Product> Products { get; set; } = null!;
        public DbSet<ProductOptionGroup> ProductOptionGroups => Set<ProductOptionGroup>();
        public DbSet<ProductOption> ProductOptions => Set<ProductOption>();
        public DbSet<User> Users => Set<User>();
        public DbSet<Address> Addresses => Set<Address>();
        public DbSet<Order> Orders => Set<Order>();
        public DbSet<OrderItem> OrderItems => Set<OrderItem>();
        public DbSet<OrderItemOptionSelection> OrderItemOptionSelections => Set<OrderItemOptionSelection>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<User>()
                .Property(u => u.Role)
                .HasConversion<string>();

            modelBuilder.Entity<Business>()
                .HasOne(b => b.OwnerUser)
                .WithMany(u => u.OwnedBusinesses)
                .HasForeignKey(b => b.OwnerUserId)
                .OnDelete(DeleteBehavior.SetNull);

            modelBuilder.Entity<Address>()
                .HasOne(a => a.User)
                .WithMany(u => u.Addresses)
                .HasForeignKey(a => a.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Product>()
                .Property(p => p.IsAvailable)
                .HasDefaultValue(true);

            modelBuilder.Entity<ProductOption>()
                .Property(o => o.IsAvailable)
                .HasDefaultValue(true);

            modelBuilder.Entity<ProductOptionGroup>()
                .HasOne(g => g.Business)
                .WithMany(b => b.OptionGroups)
                .HasForeignKey(g => g.BusinessId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Product>()
                .HasMany(p => p.OptionGroups)
                .WithMany(g => g.Products)
                .UsingEntity<Dictionary<string, object>>(
                    "ProductOptionGroupAssignments",
                    right => right
                        .HasOne<ProductOptionGroup>()
                        .WithMany()
                        .HasForeignKey("ProductOptionGroupId")
                        .OnDelete(DeleteBehavior.Cascade),
                    left => left
                        .HasOne<Product>()
                        .WithMany()
                        .HasForeignKey("ProductId")
                        .OnDelete(DeleteBehavior.Cascade),
                    join =>
                    {
                        join.HasKey("ProductId", "ProductOptionGroupId");
                        join.ToTable("ProductOptionGroupAssignments");
                    });

            modelBuilder.Entity<ProductOption>()
                .HasOne(o => o.ProductOptionGroup)
                .WithMany(g => g.Options)
                .HasForeignKey(o => o.ProductOptionGroupId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Order>()
                .HasIndex(o => o.PublicId)
                .IsUnique();

            modelBuilder.Entity<Order>()
                .Property(o => o.Status)
                .HasMaxLength(50);

            modelBuilder.Entity<Order>()
                .HasOne(o => o.Business)
                .WithMany()
                .HasForeignKey(o => o.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Order>()
                .HasOne(o => o.Address)
                .WithMany()
                .HasForeignKey(o => o.AddressId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Order>()
                .HasOne(o => o.User)
                .WithMany(u => u.Orders)
                .HasForeignKey(o => o.UserId)
                .OnDelete(DeleteBehavior.SetNull);

            modelBuilder.Entity<OrderItem>()
                .HasOne(oi => oi.Order)
                .WithMany(o => o.Items)
                .HasForeignKey(oi => oi.OrderId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<OrderItem>()
                .HasOne(oi => oi.Product)
                .WithMany(p => p.OrderItems)
                .HasForeignKey(oi => oi.ProductId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<OrderItemOptionSelection>()
                .HasOne(s => s.OrderItem)
                .WithMany(i => i.SelectedOptions)
                .HasForeignKey(s => s.OrderItemId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<OrderItemOptionSelection>()
                .HasOne(s => s.ProductOption)
                .WithMany(o => o.OrderItemSelections)
                .HasForeignKey(s => s.ProductOptionId)
                .OnDelete(DeleteBehavior.SetNull);
        }
    }
}
