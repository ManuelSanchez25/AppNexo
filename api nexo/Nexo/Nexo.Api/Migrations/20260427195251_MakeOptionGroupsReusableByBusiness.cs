using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nexo.Api.Migrations
{
    /// <inheritdoc />
    public partial class MakeOptionGroupsReusableByBusiness : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ProductOptionGroups_Products_ProductId",
                table: "ProductOptionGroups");

            migrationBuilder.RenameColumn(
                name: "ProductId",
                table: "ProductOptionGroups",
                newName: "BusinessId");

            migrationBuilder.RenameIndex(
                name: "IX_ProductOptionGroups_ProductId",
                table: "ProductOptionGroups",
                newName: "IX_ProductOptionGroups_BusinessId");

            migrationBuilder.CreateTable(
                name: "ProductOptionGroupAssignments",
                columns: table => new
                {
                    ProductId = table.Column<int>(type: "integer", nullable: false),
                    ProductOptionGroupId = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProductOptionGroupAssignments", x => new { x.ProductId, x.ProductOptionGroupId });
                    table.ForeignKey(
                        name: "FK_ProductOptionGroupAssignments_ProductOptionGroups_ProductOp~",
                        column: x => x.ProductOptionGroupId,
                        principalTable: "ProductOptionGroups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProductOptionGroupAssignments_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ProductOptionGroupAssignments_ProductOptionGroupId",
                table: "ProductOptionGroupAssignments",
                column: "ProductOptionGroupId");

            migrationBuilder.Sql(
                """
                INSERT INTO "ProductOptionGroupAssignments" ("ProductId", "ProductOptionGroupId")
                SELECT "BusinessId", "Id"
                FROM "ProductOptionGroups";
                """);

            migrationBuilder.Sql(
                """
                UPDATE "ProductOptionGroups" AS pog
                SET "BusinessId" = p."BusinessId"
                FROM "Products" AS p
                WHERE p."Id" = pog."BusinessId";
                """);

            migrationBuilder.AddForeignKey(
                name: "FK_ProductOptionGroups_Businesses_BusinessId",
                table: "ProductOptionGroups",
                column: "BusinessId",
                principalTable: "Businesses",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ProductOptionGroups_Businesses_BusinessId",
                table: "ProductOptionGroups");

            migrationBuilder.Sql(
                """
                UPDATE "ProductOptionGroups" AS pog
                SET "BusinessId" = assignment."ProductId"
                FROM (
                    SELECT "ProductOptionGroupId", MIN("ProductId") AS "ProductId"
                    FROM "ProductOptionGroupAssignments"
                    GROUP BY "ProductOptionGroupId"
                ) AS assignment
                WHERE assignment."ProductOptionGroupId" = pog."Id";
                """);

            migrationBuilder.DropTable(
                name: "ProductOptionGroupAssignments");

            migrationBuilder.RenameColumn(
                name: "BusinessId",
                table: "ProductOptionGroups",
                newName: "ProductId");

            migrationBuilder.RenameIndex(
                name: "IX_ProductOptionGroups_BusinessId",
                table: "ProductOptionGroups",
                newName: "IX_ProductOptionGroups_ProductId");

            migrationBuilder.AddForeignKey(
                name: "FK_ProductOptionGroups_Products_ProductId",
                table: "ProductOptionGroups",
                column: "ProductId",
                principalTable: "Products",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
