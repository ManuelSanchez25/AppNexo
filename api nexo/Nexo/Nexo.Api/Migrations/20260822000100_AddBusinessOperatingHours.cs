using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Nexo.Api.Data;

#nullable disable

namespace Nexo.Api.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(AppDbContext))]
    [Migration("20260822000100_AddBusinessOperatingHours")]
    public partial class AddBusinessOperatingHours : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "OpenTime",
                table: "Businesses",
                type: "text",
                nullable: false,
                defaultValue: "09:00");

            migrationBuilder.AddColumn<string>(
                name: "CloseTime",
                table: "Businesses",
                type: "text",
                nullable: false,
                defaultValue: "22:00");

            migrationBuilder.AddColumn<bool>(
                name: "IsPaused",
                table: "Businesses",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "OpenTime",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "CloseTime",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "IsPaused",
                table: "Businesses");
        }
    }
}
