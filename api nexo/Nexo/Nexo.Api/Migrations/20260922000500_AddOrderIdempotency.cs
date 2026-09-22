using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Nexo.Api.Data;

#nullable disable

namespace Nexo.Api.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20260922000500_AddOrderIdempotency")]
    public partial class AddOrderIdempotency : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE "Orders"
                    ADD COLUMN IF NOT EXISTS "ClientRequestId" character varying(64) NOT NULL DEFAULT '';

                CREATE UNIQUE INDEX IF NOT EXISTS "IX_Orders_UserId_ClientRequestId"
                    ON "Orders" ("UserId", "ClientRequestId")
                    WHERE "ClientRequestId" <> '';
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP INDEX IF EXISTS "IX_Orders_UserId_ClientRequestId";
                ALTER TABLE "Orders" DROP COLUMN IF EXISTS "ClientRequestId";
                """);
        }
    }
}
