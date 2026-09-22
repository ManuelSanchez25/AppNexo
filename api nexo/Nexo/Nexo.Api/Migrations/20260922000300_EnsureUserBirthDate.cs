using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Nexo.Api.Data;

#nullable disable

namespace Nexo.Api.Migrations
{
    [DbContext(typeof(AppDbContext))]
    [Migration("20260922000300_EnsureUserBirthDate")]
    public partial class EnsureUserBirthDate : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                ALTER TABLE "Users"
                    ADD COLUMN IF NOT EXISTS "BirthDate" timestamp with time zone NOT NULL
                    DEFAULT TIMESTAMPTZ '2000-01-01 00:00:00+00';
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Keep the repaired column when rolling back this compatibility migration.
        }
    }
}
