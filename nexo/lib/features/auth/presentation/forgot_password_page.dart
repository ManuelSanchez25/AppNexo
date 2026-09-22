import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/features/auth/data/auth_api.dart';
import 'package:nexo/theme/app_buttons.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail.contains('@') ? widget.initialEmail : '',
  );
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _hidePassword = true;

  String get _cleanEmail => _email.text.trim().toLowerCase();
  bool get _validPassword =>
      _password.text.length >= 8 &&
      _password.text.length <= 20 &&
      RegExp(r'[A-Z]').hasMatch(_password.text) &&
      RegExp(r'[a-z]').hasMatch(_password.text) &&
      RegExp(r'\d').hasMatch(_password.text);

  Future<void> _sendCode() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_cleanEmail)) {
      _message('Escribe un correo válido.');
      return;
    }
    await _run(() async {
      await AuthApi.requestPasswordReset(email: _cleanEmail);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _message('Si la cuenta existe, enviamos un código al correo.');
    });
  }

  Future<void> _reset() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      _message('Escribe el código de 6 dígitos.');
      return;
    }
    if (!_validPassword) {
      _message(
        'La contraseña debe tener 8 a 20 caracteres, mayúscula, minúscula y número.',
      );
      return;
    }
    if (_password.text != _confirm.text) {
      _message('Las contraseñas no coinciden.');
      return;
    }
    await _run(() async {
      await AuthApi.resetPassword(
        email: _cleanEmail,
        code: _code.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      _message('Contraseña actualizada. Ya puedes iniciar sesión.');
      Navigator.pop(context);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _message(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar contraseña')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset_rounded, size: 64),
              const SizedBox(height: 14),
              const Text(
                'Recupera tu acceso',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Te enviaremos un código de 6 dígitos. Expira en 10 minutos.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo de tu cuenta',
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _hidePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '8-20 caracteres, mayúscula, minúscula y número',
                  style: TextStyle(
                    color: _validPassword ? Colors.green : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                style: AppButtons.primary,
                onPressed: _loading ? null : (_codeSent ? _reset : _sendCode),
                child: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeSent ? 'Cambiar contraseña' : 'Enviar código'),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _loading ? null : _sendCode,
                  child: const Text('Reenviar código'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
