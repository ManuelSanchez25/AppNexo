using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nexo.Api.Migrations
{
    [Migration("20260921000200_AddDriverApplicationDetails")]
    public partial class AddDriverApplicationDetails : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>("DriverVehicleMakeModel", "Users", maxLength: 100, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>("DriverVehicleColor", "Users", maxLength: 40, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>("DriverVehiclePlate", "Users", maxLength: 20, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>("DriverLicenseType", "Users", maxLength: 30, nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<string>("DriverIdentityType", "Users", maxLength: 30, nullable: false, defaultValue: "");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn("DriverVehicleMakeModel", "Users");
            migrationBuilder.DropColumn("DriverVehicleColor", "Users");
            migrationBuilder.DropColumn("DriverVehiclePlate", "Users");
            migrationBuilder.DropColumn("DriverLicenseType", "Users");
            migrationBuilder.DropColumn("DriverIdentityType", "Users");
        }
    }
}
