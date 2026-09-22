import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/data/auth_api.dart';
import 'package:nexo/features/auth/data/google_auth_service.dart';
import 'package:nexo/features/auth/presentation/email_verification_page.dart';
import 'package:nexo/features/auth/presentation/forgot_password_page.dart';
import 'package:nexo/features/auth/presentation/google_sign_in_button.dart';
import 'package:nexo/features/auth/presentation/register_page.dart';
import 'package:nexo/features/auth/presentation/session_home_page.dart';
import 'package:nexo/theme/app_buttons.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String? _identifierError;
  String? _passwordError;
  final TextEditingController _identifierCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _validateInputs(String identifier, String password) {
    var isValid = true;

    if (identifier.isEmpty) {
      _identifierError = 'Escribe tu correo, telefono o usuario';
      isValid = false;
    } else {
      _identifierError = null;
    }

    if (password.isEmpty) {
      _passwordError = 'Escribe tu contraseña';
      isValid = false;
    } else if (password.length < 6) {
      _passwordError = 'Mínimo 6 caracteres';
      isValid = false;
    } else {
      _passwordError = null;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _onLoginPressed() async {
    final identifier = _identifierCtrl.text.trim();
    final password = _passCtrl.text;
    final authController = AuthScope.of(context);

    if (!_validateInputs(identifier, password)) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthApi.login(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;

      authController.setSession(user);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bienvenido ${user.name}')));

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SessionHomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceAll('Exception:', '').trim();
      if (message.toLowerCase().contains('verifica tu correo') &&
          identifier.contains('@')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(email: identifier),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onGoogleLogin(GoogleSignInAccount account) async {
    final authController = AuthScope.of(context);
    final session = await AuthApi.googleLogin(
      idToken: GoogleAuthService.idTokenFrom(account),
      role: 'client',
    );

    if (!mounted) return;

    authController.setSession(session);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bienvenido ${session.name}')));

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SessionHomePage()),
      (route) => false,
    );
  }

  void _openRegister(AccountType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterPage(initialAccountType: type)),
    );
    _identifierCtrl.clear();
    _passCtrl.clear();
    _identifierError = null;
    _passwordError = null;
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF171614),
                          Color(0xFF2B2620),
                          Color(0xFF5F4C3E),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/nexologobueno.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Accede a una experiencia más limpia para pedir o administrar.',
                          style: TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            height: 1.04,
                            letterSpacing: -1,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Una sola app para cliente y restaurante, con flujos separados y una interfaz mucho más clara.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFFE7DDD1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE5E0D7)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Inicia sesión',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Entra con tu correo, telefono o usuario para continuar.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _identifierCtrl,
                          keyboardType: TextInputType.text,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Correo o telefono',
                            errorText: _identifierError,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            errorText: _passwordError,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ForgotPasswordPage(
                                        initialEmail: _identifierCtrl.text
                                            .trim(),
                                      ),
                                    ),
                                  ),
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: AppButtons.primary,
                          onPressed: _isLoading ? null : _onLoginPressed,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                        const SizedBox(height: 12),
                        GoogleSignInButton(
                          label: 'Entrar con Google',
                          enabled: !_isLoading,
                          onSignedIn: _onGoogleLogin,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Si es tu primera vez con Google, crea la cuenta abajo para registrar fecha y tipo de cuenta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF777777),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Crear una cuenta',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _openRegister(AccountType.client),
                                child: const Text('Cliente'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _openRegister(AccountType.restaurant),
                                child: const Text('Restaurante'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _openRegister(AccountType.driver),
                                child: const Text('Repartidor'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
