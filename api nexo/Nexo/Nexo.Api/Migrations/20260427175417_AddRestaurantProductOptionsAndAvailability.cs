using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Nexo.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddRestaurantProductOptionsAndAvailability : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsAvailable",
                table: "Products",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<int>(
                name: "BusinessId",
                table: "Orders",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "BaseUnitPrice",
                table: "OrderItems",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "OptionsUnitPrice",
                table: "OrderItems",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "ProductDescription",
                table: "OrderItems",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.Sql("""
                UPDATE "OrderItems" oi
                SET "BaseUnitPrice" = oi."UnitPrice",
                    "ProductDescription" = COALESCE(p."Description", '')
                FROM "Products" p
                WHERE p."Id" = oi."ProductId";
                """);

            migrationBuilder.Sql("""
                UPDATE "Orders" o
                SET "BusinessId" = src."BusinessId"
                FROM (
                    SELECT oi."OrderId", MIN(p."BusinessId") AS "BusinessId"
                    FROM "OrderItems" oi
                    INNER JOIN "Products" p ON p."Id" = oi."ProductId"
                    GROUP BY oi."OrderId"
                ) AS src
                WHERE o."Id" = src."OrderId";
                """);

            migrationBuilder.Sql("""
                UPDATE "Orders"
                SET "BusinessId" = (
                    SELECT MIN(b."Id")
                    FROM "Businesses" b
                )
                WHERE "BusinessId" IS NULL;
                """);

            migrationBuilder.AlterColumn<int>(
                name: "BusinessId",
                table: "Orders",
                type: "integer",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.CreateTable(
                name: "ProductOptionGroups",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ProductId = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "text", nullable: false),
                    IsRequired = table.Column<bool>(type: "boolean", nullable: false),
                    MinSelections = table.Column<int>(type: "integer", nullable: false),
                    MaxSelections = table.Column<int>(type: "integer", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductOptionGroups", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProductOptionGroups_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ProductOptions",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ProductOptionGroupId = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "text", nullable: false),
                    PriceDelta = table.Column<decimal>(type: "numeric", nullable: false),
                    IsAvailable = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    SortOrder = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductOptions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProductOptions_ProductOptionGroups_ProductOptionGroupId",
                        column: x => x.ProductOptionGroupId,
                        principalTable: "ProductOptionGroups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "OrderItemOptionSelections",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    OrderItemId = table.Column<int>(type: "integer", nullable: false),
                    ProductOptionId = table.Column<int>(type: "integer", nullable: true),
                    GroupName = table.Column<string>(type: "text", nullable: false),
                    OptionName = table.Column<string>(type: "text", nullable: false),
                    PriceDelta = table.Column<decimal>(type: "numeric", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OrderItemOptionSelections", x => x.Id);
                    table.ForeignKey(
                        name: "FK_OrderItemOptionSelections_OrderItems_OrderItemId",
                        column: x => x.OrderItemId,
                        principalTable: "OrderItems",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_OrderItemOptionSelections_ProductOptions_ProductOptionId",
                        column: x => x.ProductOptionId,
                        principalTable: "ProductOptions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Orders_BusinessId",
                table: "Orders",
                column: "BusinessId");

            migrationBuilder.CreateIndex(
                name: "IX_OrderItemOptionSelections_OrderItemId",
                table: "OrderItemOptionSelections",
                column: "OrderItemId");

            migrationBuilder.CreateIndex(
                name: "IX_OrderItemOptionSelections_ProductOptionId",
                table: "OrderItemOptionSelections",
                column: "ProductOptionId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductOptionGroups_ProductId",
                table: "ProductOptionGroups",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_ProductOptions_ProductOptionGroupId",
                table: "ProductOptions",
                column: "ProductOptionGroupId");

            migrationBuilder.AddForeignKey(
                name: "FK_Orders_Businesses_BusinessId",
                table: "Orders",
                column: "BusinessId",
                principalTable: "Businesses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Orders_Businesses_BusinessId",
                table: "Orders");

            migrationBuilder.DropTable(
                name: "OrderItemOptionSelections");

            migrationBuilder.DropTable(
                name: "ProductOptions");

            migrationBuilder.DropTable(
                name: "ProductOptionGroups");

            migrationBuilder.DropIndex(
                name: "IX_Orders_BusinessId",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "IsAvailable",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "BusinessId",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "BaseUnitPrice",
                table: "OrderItems");

            migrationBuilder.DropColumn(
                name: "OptionsUnitPrice",
                table: "OrderItems");

            migrationBuilder.DropColumn(
                name: "ProductDescription",
                table: "OrderItems");
        }
    }
}
