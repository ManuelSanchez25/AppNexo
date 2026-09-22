using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nexo.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddBusinessOwnership : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "OwnerUserId",
                table: "Businesses",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Businesses_OwnerUserId",
                table: "Businesses",
                column: "OwnerUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Businesses_Users_OwnerUserId",
                table: "Businesses",
                column: "OwnerUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Businesses_Users_OwnerUserId",
                table: "Businesses");

            migrationBuilder.DropIndex(
                name: "IX_Businesses_OwnerUserId",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "OwnerUserId",
                table: "Businesses");
        }
    }
}
