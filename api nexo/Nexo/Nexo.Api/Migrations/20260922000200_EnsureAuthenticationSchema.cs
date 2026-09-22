using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Nexo.Api.Data;

#nullable disable

namespace Nexo.Api.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20260922000200_EnsureAuthenticationSchema")]
    public partial class EnsureAuthenticationSchema : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE "Users"
                    ADD COLUMN IF NOT EXISTS "Phone" text NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "EmailVerified" boolean NOT NULL DEFAULT false,
                    ADD COLUMN IF NOT EXISTS "EmailVerificationCodeHash" text NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "EmailVerificationExpiresAt" timestamp with time zone NULL,
                    ADD COLUMN IF NOT EXISTS "EmailVerificationLastSentAt" timestamp with time zone NULL,
                    ADD COLUMN IF NOT EXISTS "EmailVerificationAttempts" integer NOT NULL DEFAULT 0,
                    ADD COLUMN IF NOT EXISTS "PasswordResetCodeHash" text NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "PasswordResetExpiresAt" timestamp with time zone NULL,
                    ADD COLUMN IF NOT EXISTS "PasswordResetLastSentAt" timestamp with time zone NULL,
                    ADD COLUMN IF NOT EXISTS "PasswordResetAttempts" integer NOT NULL DEFAULT 0,
                    ADD COLUMN IF NOT EXISTS "TermsAcceptedAt" timestamp with time zone NULL,
                    ADD COLUMN IF NOT EXISTS "DriverFullName" text NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverPhone" text NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverVehicleType" character varying(20) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverVehicleMakeModel" character varying(100) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverVehicleColor" character varying(40) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverVehiclePlate" character varying(20) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverLicenseType" character varying(30) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverLicenseNumber" character varying(50) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverIdentityType" character varying(30) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverIdentityDocument" character varying(50) NOT NULL DEFAULT '',
                    ADD COLUMN IF NOT EXISTS "DriverApprovalStatus" character varying(30) NOT NULL DEFAULT '';
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // This migration repairs installations with partially-created schemas.
        }
    }
}
