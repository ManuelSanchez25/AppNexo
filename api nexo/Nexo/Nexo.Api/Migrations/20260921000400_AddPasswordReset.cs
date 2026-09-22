using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nexo.Api.Migrations
{
    [Migration("20260921000400_AddPasswordReset")]
    public partial class AddPasswordReset : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(name: "PasswordResetAttempts", table: "Users", type: "integer", nullable: false, defaultValue: 0);
            migrationBuilder.AddColumn<string>(name: "PasswordResetCodeHash", table: "Users", type: "text", nullable: false, defaultValue: "");
            migrationBuilder.AddColumn<DateTime>(name: "PasswordResetExpiresAt", table: "Users", type: "timestamp with time zone", nullable: true);
            migrationBuilder.AddColumn<DateTime>(name: "PasswordResetLastSentAt", table: "Users", type: "timestamp with time zone", nullable: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "PasswordResetAttempts", table: "Users");
            migrationBuilder.DropColumn(name: "PasswordResetCodeHash", table: "Users");
            migrationBuilder.DropColumn(name: "PasswordResetExpiresAt", table: "Users");
            migrationBuilder.DropColumn(name: "PasswordResetLastSentAt", table: "Users");
        }
    }
}
