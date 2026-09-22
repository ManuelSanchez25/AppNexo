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
        public DbSet<PushDevice> PushDevices => Set<PushDevice>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<User>()
                .Property(u => u.Role)
                .HasConversion<string>();

            modelBuilder.Entity<User>()
                .HasIndex(u => u.Name)
                .IsUnique();
            modelBuilder.Entity<User>()
                .HasIndex(u => u.Email)
                .IsUnique()
                .HasFilter("\"Email\" <> ''");
            modelBuilder.Entity<User>()
                .HasIndex(u => u.Phone)
                .IsUnique()
                .HasFilter("\"Phone\" <> ''");

            modelBuilder.Entity<User>()
                .Property(u => u.DriverApprovalStatus)
                .HasMaxLength(30);

            modelBuilder.Entity<PushDevice>()
                .HasIndex(d => d.Token)
                .IsUnique();
            modelBuilder.Entity<PushDevice>()
                .Property(d => d.Token)
                .HasMaxLength(4096);
            modelBuilder.Entity<PushDevice>()
                .Property(d => d.Platform)
                .HasMaxLength(20);
            modelBuilder.Entity<PushDevice>()
                .HasOne(d => d.User)
                .WithMany(u => u.PushDevices)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<User>().Property(u => u.DriverVehicleType).HasMaxLength(20);
            modelBuilder.Entity<User>().Property(u => u.DriverVehicleMakeModel).HasMaxLength(100);
            modelBuilder.Entity<User>().Property(u => u.DriverVehicleColor).HasMaxLength(40);
            modelBuilder.Entity<User>().Property(u => u.DriverVehiclePlate).HasMaxLength(20);
            modelBuilder.Entity<User>().Property(u => u.DriverLicenseType).HasMaxLength(30);
            modelBuilder.Entity<User>().Property(u => u.DriverLicenseNumber).HasMaxLength(50);
            modelBuilder.Entity<User>().Property(u => u.DriverIdentityType).HasMaxLength(30);
            modelBuilder.Entity<User>().Property(u => u.DriverIdentityDocument).HasMaxLength(50);

            modelBuilder.Entity<Business>()
                .HasOne(b => b.OwnerUser)
                .WithMany(u => u.OwnedBusinesses)
                .HasForeignKey(b => b.OwnerUserId)
                .OnDelete(DeleteBehavior.SetNull);

            modelBuilder.Entity<Business>()
                .Property(b => b.ApprovalStatus)
                .HasMaxLength(30)
                .HasDefaultValue("approved");

            modelBuilder.Entity<Business>()
                .Property(b => b.OpenTime)
                .HasMaxLength(5)
                .HasDefaultValue("09:00");

            modelBuilder.Entity<Business>()
                .Property(b => b.CloseTime)
                .HasMaxLength(5)
                .HasDefaultValue("22:00");

            modelBuilder.Entity<Business>()
                .Property(b => b.OpenDays)
                .HasMaxLength(20)
                .HasDefaultValue("1,2,3,4,5");

            modelBuilder.Entity<Business>()
                .Property(b => b.OperatingHoursJson)
                .HasColumnType("text")
                .HasDefaultValue("");

            modelBuilder.Entity<Business>()
                .Property(b => b.IsPaused)
                .HasDefaultValue(false);

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
                .Property(o => o.DeliveryPin)
                .HasMaxLength(4);

            modelBuilder.Entity<Order>()
                .Property(o => o.CancelledBy)
                .HasMaxLength(30);

            modelBuilder.Entity<Order>()
                .Property(o => o.CancellationReason)
                .HasMaxLength(250);

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

            modelBuilder.Entity<Order>()
                .HasOne(o => o.DriverUser)
                .WithMany(u => u.DriverOrders)
                .HasForeignKey(o => o.DriverUserId)
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
