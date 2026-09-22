class LoginResponse {
  final int userId;
  final String name;
  final String email;
  final bool emailVerified;
  final String role;
  final String driverApprovalStatus;
  final String token;

  LoginResponse({
    required this.userId,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.role,
    required this.driverApprovalStatus,
    required this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      userId: json['userId'] as int,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      emailVerified: (json['emailVerified'] ?? false) as bool,
      role: (json['role'] ?? '') as String,
      driverApprovalStatus: (json['driverApprovalStatus'] ?? '') as String,
      token: (json['token'] ?? '') as String,
    );
  }
}
