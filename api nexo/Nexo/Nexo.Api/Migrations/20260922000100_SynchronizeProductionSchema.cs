using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Nexo.Api.Data;

#nullable disable

namespace Nexo.Api.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20260922000100_SynchronizeProductionSchema")]
    public partial class SynchronizeProductionSchema : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE "Businesses"
                    ADD COLUMN IF NOT EXISTS "ApprovalStatus" character varying(30) NOT NULL DEFAULT 'approved';

                ALTER TABLE "Users"
                    ADD COLUMN IF NOT EXISTS "DriverFullName" text NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverPhone" text NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverVehicleType" character varying(20) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverLicenseNumber" character varying(50) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverIdentityDocument" character varying(50) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverApprovalStatus" character varying(30) NOT NULL DEFAULT '';

                ALTER TABLE "Orders"
                    ADD COLUMN IF NOT EXISTS "DriverUserId" integer NULL;

                CREATE INDEX IF NOT EXISTS "IX_Orders_DriverUserId"
                    ON "Orders" ("DriverUserId");

                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1
                        FROM pg_constraint
                        WHERE conname = 'FK_Orders_Users_DriverUserId'
                    ) THEN
                        ALTER TABLE "Orders"
                            ADD CONSTRAINT "FK_Orders_Users_DriverUserId"
                            FOREIGN KEY ("DriverUserId") REFERENCES "Users" ("Id")
                            ON DELETE SET NULL;
                    END IF;
                END $$;
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE "Orders" DROP CONSTRAINT IF EXISTS "FK_Orders_Users_DriverUserId";
                DROP INDEX IF EXISTS "IX_Orders_DriverUserId";
                ALTER TABLE "Orders" DROP COLUMN IF EXISTS "DriverUserId";

                ALTER TABLE "Users"
                    DROP COLUMN IF EXISTS "DriverFullName",
                    DROP COLUMN IF EXISTS "DriverPhone",
                    DROP COLUMN IF EXISTS "DriverVehicleType",
                    DROP COLUMN IF EXISTS "DriverLicenseNumber",
                    DROP COLUMN IF EXISTS "DriverIdentityDocument",
                    DROP COLUMN IF EXISTS "DriverApprovalStatus";

                ALTER TABLE "Businesses" DROP COLUMN IF EXISTS "ApprovalStatus";
                """);
        }
    }
}
