using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Nexo.Api.Data;

#nullable disable

namespace Nexo.Api.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20260923000100_AddOrderPaymentFields")]
    public partial class AddOrderPaymentFields : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE "Orders"
                    ADD COLUMN IF NOT EXISTS "PaymentProvider" character varying(30) NOT NULL DEFAULT 'mercado_pago',
                    ADD COLUMN IF NOT EXISTS "PaymentStatus" character varying(30) NOT NULL DEFAULT 'pending',
                    ADD COLUMN IF NOT EXISTS "MercadoPagoPreferenceId" character varying(100) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "MercadoPagoPaymentId" character varying(100) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "MercadoPagoCheckoutUrl" character varying(2000) NOT NULL DEFAULT '';

                UPDATE "Orders"
                SET "PaymentStatus" = 'approved'
                WHERE "Status" <> 'pending_payment' AND "PaymentStatus" = 'pending';
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE "Orders"
                    DROP COLUMN IF EXISTS "MercadoPagoPaymentId",
                    DROP COLUMN IF EXISTS "MercadoPagoPreferenceId",
                    DROP COLUMN IF EXISTS "MercadoPagoCheckoutUrl",
                    DROP COLUMN IF EXISTS "PaymentStatus",
                    DROP COLUMN IF EXISTS "PaymentProvider";
                """);
        }
    }
}
