import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/data/auth_api.dart';
import 'package:nexo/features/auth/presentation/register_page.dart';
import 'package:nexo/features/auth/presentation/session_home_page.dart';
import 'package:nexo/theme/app_buttons.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _validateInputs(String email, String password) {
    var isValid = true;

    if (email.isEmpty) {
      _emailError = 'Escribe tu correo o usuario';
      isValid = false;
    } else {
      _emailError = null;
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
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final authController = AuthScope.of(context);

    if (!_validateInputs(email, password)) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthApi.login(
        identifier: email,
        password: password,
      );

      if (!mounted) return;

      authController.setSession(user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenido ${user.name}')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SessionHomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception:', '').trim(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openRegister(AccountType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterPage(initialAccountType: type),
      ),
    );
    _emailCtrl.clear();
    _passCtrl.clear();
    _emailError = null;
    _passwordError = null;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
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
                          'Entra con tu correo o usuario para continuar.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Correo o usuario',
                            errorText: _emailError,
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
                        const SizedBox(height: 26),
                        ElevatedButton(
                          style: AppButtons.primary,
                          onPressed: _isLoading ? null : _onLoginPressed,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Entrar'),
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
                                onPressed: () => _openRegister(AccountType.client),
                                child: const Text('Cliente'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _openRegister(AccountType.restaurant),
                                child: const Text('Restaurante'),
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
