class LoginResponse {
  final int userId;
  final String name;
  final String email;
  final String role;
  final String token;

  LoginResponse({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      userId: json['userId'] as int,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: (json['role'] ?? '') as String,
      token: (json['token'] ?? '') as String,
    );
  }
}
