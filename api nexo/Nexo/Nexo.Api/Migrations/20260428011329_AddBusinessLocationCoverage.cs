using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nexo.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddBusinessLocationCoverage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AddressText",
                table: "Businesses",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<double>(
                name: "DeliveryRadiusKm",
                table: "Businesses",
                type: "double precision",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<decimal>(
                name: "Latitude",
                table: "Businesses",
                type: "numeric",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Longitude",
                table: "Businesses",
                type: "numeric",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AddressText",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "DeliveryRadiusKm",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "Businesses");
        }
    }
}
