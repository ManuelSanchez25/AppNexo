import 'package:flutter/material.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/data/auth_api.dart';
import 'package:nexo/features/auth/presentation/session_home_page.dart';
import 'package:nexo/theme/app_buttons.dart';

enum AccountType { client, restaurant }

class RegisterPage extends StatefulWidget {
  final AccountType initialAccountType;

  const RegisterPage({
    super.key,
    this.initialAccountType = AccountType.client,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  DateTime? _birthDate;
  String? _birthDateError;
  String? _nameError;
  String? _emailError;
  String? _passError;
  bool _isLoading = false;
  late AccountType _accountType;

  @override
  void initState() {
    super.initState();
    _accountType = widget.initialAccountType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final maxDate = DateTime(today.year - 15, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: maxDate,
      firstDate: DateTime(1900),
      lastDate: maxDate,
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateError = null;
        _birthDateCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  Future<void> _onRegisterPressed() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final authController = AuthScope.of(context);

    var isValid = true;

    if (name.isEmpty) {
      _nameError = _accountType == AccountType.restaurant
          ? 'Escribe el usuario del restaurante'
          : 'Escribe tu nombre';
      isValid = false;
    } else if (name.length < 3) {
      _nameError = 'Nombre muy corto';
      isValid = false;
    } else {
      _nameError = null;
    }

    if (email.isEmpty) {
      _emailError = 'Escribe tu correo';
      isValid = false;
    } else if (!email.contains('@') || !email.contains('.')) {
      _emailError = 'Correo no válido';
      isValid = false;
    } else {
      _emailError = null;
    }

    if (pass.isEmpty) {
      _passError = 'Escribe una contraseña';
      isValid = false;
    } else if (pass.length < 6) {
      _passError = 'Mínimo 6 caracteres';
      isValid = false;
    } else {
      _passError = null;
    }

    if (_birthDate == null) {
      _birthDateError = 'Selecciona tu fecha de nacimiento';
      isValid = false;
    } else {
      _birthDateError = null;
    }

    setState(() {});
    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final session = await AuthApi.register(
        name: name,
        email: email,
        password: pass,
        birthDate: _birthDate!,
        role: _accountType == AccountType.restaurant ? 'restaurant' : 'client',
      );

      if (!mounted) return;

      authController.setSession(session);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _accountType == AccountType.restaurant
                ? 'Cuenta restaurante creada correctamente'
                : 'Cuenta creada correctamente',
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final isRestaurant = _accountType == AccountType.restaurant;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRestaurant ? 'Cuenta restaurante' : 'Crear cuenta'),
      ),
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
                      'Elige tu tipo de cuenta',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Una cuenta cliente para pedir o una cuenta restaurante para administrar negocio, catálogo y pedidos.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<AccountType>(
                      segments: const [
                        ButtonSegment<AccountType>(
                          value: AccountType.client,
                          label: Text('Cliente'),
                          icon: Icon(Icons.person_rounded),
                        ),
                        ButtonSegment<AccountType>(
                          value: AccountType.restaurant,
                          label: Text('Restaurante'),
                          icon: Icon(Icons.storefront_rounded),
                        ),
                      ],
                      selected: {_accountType},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _accountType = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: isRestaurant
                            ? 'Usuario del restaurante'
                            : 'Nombre de usuario',
                        errorText: _nameError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickBirthDate,
                      child: AbsorbPointer(
                        child: TextField(
                          readOnly: true,
                          controller: _birthDateCtrl,
                          decoration: InputDecoration(
                            labelText: 'Fecha de nacimiento',
                            errorText: _birthDateError,
                            suffixIcon:
                                const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo',
                        errorText: _emailError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        errorText: _passError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4EEE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isRestaurant
                            ? 'Entrarás directo al panel restaurante para crear negocios, productos e ingredientes.'
                            : 'Entrarás al catálogo del cliente para explorar negocios, pedir y revisar tu historial.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF555555),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _onRegisterPressed,
                      style: AppButtons.primary,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isRestaurant
                                  ? 'Crear cuenta restaurante'
                                  : 'Crear cuenta',
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
