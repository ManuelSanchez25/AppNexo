import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/data/auth_api.dart';
import 'package:nexo/features/auth/presentation/session_home_page.dart';
import 'package:nexo/theme/app_buttons.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _codeError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _codeError = 'El código debe tener 6 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
      _codeError = null;
    });

    try {
      final session = await AuthApi.verifyEmail(
        email: widget.email,
        code: code,
      );

      if (!mounted) return;

      AuthScope.of(context).setSession(session);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo verificado correctamente')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SessionHomePage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);

    try {
      await AuthApi.resendEmailCode(email: widget.email);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Código reenviado')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu correo')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE5E0D7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Código de seguridad',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enviamos un código de 6 dígitos a ${widget.email}. Expira en 10 minutos.',
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Código',
                        counterText: '',
                        errorText: _codeError,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      style: AppButtons.primary,
                      onPressed: _isLoading ? null : _verify,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verificar correo'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isResending ? null : _resend,
                      child: Text(
                        _isResending ? 'Reenviando...' : 'Reenviar código',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
