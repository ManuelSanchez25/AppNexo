import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nexo/features/auth/application/auth_scope.dart';
import 'package:nexo/features/auth/data/auth_api.dart';
import 'package:nexo/features/auth/data/google_auth_service.dart';
import 'package:nexo/features/auth/presentation/google_sign_in_button.dart';
import 'package:nexo/features/auth/presentation/session_home_page.dart';
import 'package:nexo/theme/app_buttons.dart';

enum AccountType { client, restaurant, driver }

class RegisterPage extends StatefulWidget {
  final AccountType initialAccountType;

  const RegisterPage({super.key, this.initialAccountType = AccountType.client});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _driverFullNameCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();
  final _driverVehicleMakeModelCtrl = TextEditingController();
  final _driverVehicleColorCtrl = TextEditingController();
  final _driverVehiclePlateCtrl = TextEditingController();
  final _driverLicenseCtrl = TextEditingController();
  final _driverIdentityCtrl = TextEditingController();

  String? _driverVehicleType;
  String? _driverLicenseType;
  String? _driverIdentityType;

  DateTime? _birthDate;
  String? _birthDateError;
  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _driverError;
  bool _termsError = false;
  bool _isLoading = false;
  bool _acceptTerms = false;
  late AccountType _accountType;

  @override
  void initState() {
    super.initState();
    _accountType = widget.initialAccountType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _passCtrl.dispose();
    _birthDateCtrl.dispose();
    _driverFullNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    _driverVehicleMakeModelCtrl.dispose();
    _driverVehicleColorCtrl.dispose();
    _driverVehiclePlateCtrl.dispose();
    _driverLicenseCtrl.dispose();
    _driverIdentityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final minimumAge = _accountType == AccountType.driver ? 18 : 15;
    final maxDate = DateTime(today.year - minimumAge, today.month, today.day);

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
    final contact = _contactCtrl.text.trim();
    final isEmail = contact.contains('@');
    final email = isEmail ? contact : '';
    final phone = isEmail ? '' : contact;
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

    if (contact.isEmpty) {
      _emailError = 'Escribe tu correo o telefono';
      isValid = false;
    } else if (isEmail &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact)) {
      _emailError = 'Correo no válido';
      isValid = false;
    } else if (!isEmail && contact.replaceAll(RegExp(r'\D'), '').length < 10) {
      _emailError = 'Telefono no válido';
      isValid = false;
    } else {
      _emailError = null;
    }

    if (_accountType == AccountType.client) {
      if (!_acceptTerms) {
        _termsError = true;
        isValid = false;
      } else {
        _termsError = false;
      }
    } else {
      _termsError = false;
    }

    if (pass.isEmpty) {
      _passError = 'Escribe una contraseña';
      isValid = false;
    } else if (pass.length < 8 || pass.length > 20) {
      _passError = 'Usa entre 8 y 20 caracteres';
      isValid = false;
    } else if (!RegExp(r'[A-Z]').hasMatch(pass) ||
        !RegExp(r'[a-z]').hasMatch(pass) ||
        !RegExp(r'[0-9]').hasMatch(pass)) {
      _passError = 'Incluye mayúscula, minúscula y número';
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

    if (_accountType == AccountType.driver && !_validateDriverFields()) {
      isValid = false;
    }

    setState(() {});
    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final session = await AuthApi.register(
        name: name,
        email: email,
        phone: phone,
        password: pass,
        birthDate: _birthDate!,
        role: switch (_accountType) {
          AccountType.restaurant => 'restaurant',
          AccountType.driver => 'driver',
          AccountType.client => 'client',
        },
        acceptTerms: _accountType != AccountType.client || _acceptTerms,
        driverFullName: _driverFullNameCtrl.text.trim(),
        driverPhone: _driverPhoneCtrl.text.trim(),
        driverVehicleType: _driverVehicleType ?? '',
        driverVehicleMakeModel: _driverVehicleMakeModelCtrl.text.trim(),
        driverVehicleColor: _driverVehicleColorCtrl.text.trim(),
        driverVehiclePlate: _driverVehiclePlateCtrl.text.trim(),
        driverLicenseType: _driverLicenseType ?? '',
        driverLicenseNumber: _driverLicenseCtrl.text.trim(),
        driverIdentityType: _driverIdentityType ?? '',
        driverIdentityDocument: _driverIdentityCtrl.text.trim(),
      );

      if (!mounted) return;

      authController.setSession(session);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _accountType == AccountType.restaurant
                ? 'Cuenta restaurante creada correctamente'
                : _accountType == AccountType.driver
                ? 'Solicitud de repartidor enviada para revisión'
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
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateGoogleRegistration() {
    var isValid = true;

    _nameError = null;
    _emailError = null;
    _passError = null;

    if (_birthDate == null) {
      _birthDateError = 'Selecciona tu fecha de nacimiento';
      isValid = false;
    } else {
      _birthDateError = null;
    }

    if (_accountType == AccountType.driver && !_validateDriverFields()) {
      isValid = false;
    }

    if (_accountType == AccountType.client) {
      _termsError = !_acceptTerms;
      if (_termsError) isValid = false;
    }

    setState(() {});
    return isValid;
  }

  bool _validateDriverFields() {
    final phoneDigits = _driverPhoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final isMotorVehicle =
        _driverVehicleType == 'motorcycle' || _driverVehicleType == 'car';

    final today = DateTime.now();
    final driverBirthDate = _birthDate;
    final isAdult =
        driverBirthDate != null &&
        !driverBirthDate.isAfter(
          DateTime(today.year - 18, today.month, today.day),
        );

    if (!isAdult) {
      _driverError = 'Debes tener al menos 18 años para ser repartidor';
    } else if (_driverFullNameCtrl.text.trim().length < 5) {
      _driverError = 'Escribe tu nombre legal completo';
    } else if (phoneDigits.length < 10 || phoneDigits.length > 15) {
      _driverError = 'Escribe un teléfono válido de 10 a 15 dígitos';
    } else if (_driverVehicleType == null) {
      _driverError = 'Selecciona el vehículo con el que repartirás';
    } else if (_driverIdentityType == null ||
        _driverIdentityCtrl.text.trim().length < 5) {
      _driverError = 'Selecciona tu identificación y escribe su folio';
    } else if (isMotorVehicle &&
        (_driverVehicleMakeModelCtrl.text.trim().length < 2 ||
            _driverVehicleColorCtrl.text.trim().length < 3 ||
            _driverVehiclePlateCtrl.text.trim().length < 4)) {
      _driverError = 'Completa marca/modelo, color y placa del vehículo';
    } else if (isMotorVehicle &&
        (_driverLicenseType == null ||
            _driverLicenseCtrl.text.trim().length < 5)) {
      _driverError = 'Selecciona licencia o permiso y escribe su folio';
    } else {
      _driverError = null;
    }

    return _driverError == null;
  }

  bool get _driverIsAdult {
    final birthDate = _birthDate;
    if (birthDate == null) return false;
    final today = DateTime.now();
    return !birthDate.isAfter(
      DateTime(today.year - 18, today.month, today.day),
    );
  }

  bool get _driverNameValid => _driverFullNameCtrl.text.trim().length >= 5;

  bool get _driverPhoneValid {
    final digits = _driverPhoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 15;
  }

  bool get _driverIdentityValid =>
      _driverIdentityType != null &&
      _driverIdentityCtrl.text.trim().length >= 5;

  bool get _motorVehicleSelected =>
      _driverVehicleType == 'motorcycle' || _driverVehicleType == 'car';

  bool get _driverVehicleDetailsValid =>
      !_motorVehicleSelected ||
      (_driverVehicleMakeModelCtrl.text.trim().length >= 2 &&
          _driverVehicleColorCtrl.text.trim().length >= 3 &&
          _driverVehiclePlateCtrl.text.trim().length >= 4);

  bool get _driverLicenseValid =>
      !_motorVehicleSelected ||
      (_driverLicenseType != null &&
          _driverLicenseCtrl.text.trim().length >= 5);

  Future<void> _onGoogleRegister(GoogleSignInAccount account) async {
    if (!_validateGoogleRegistration()) {
      throw Exception('Completa los campos requeridos antes de usar Google.');
    }

    final authController = AuthScope.of(context);
    final session = await AuthApi.googleLogin(
      idToken: GoogleAuthService.idTokenFrom(account),
      role: switch (_accountType) {
        AccountType.restaurant => 'restaurant',
        AccountType.driver => 'driver',
        AccountType.client => 'client',
      },
      birthDate: _birthDate,
      name: _nameCtrl.text.trim(),
      acceptTerms: _accountType != AccountType.client || _acceptTerms,
      driverFullName: _driverFullNameCtrl.text.trim(),
      driverPhone: _driverPhoneCtrl.text.trim(),
      driverVehicleType: _driverVehicleType ?? '',
      driverVehicleMakeModel: _driverVehicleMakeModelCtrl.text.trim(),
      driverVehicleColor: _driverVehicleColorCtrl.text.trim(),
      driverVehiclePlate: _driverVehiclePlateCtrl.text.trim(),
      driverLicenseType: _driverLicenseType ?? '',
      driverLicenseNumber: _driverLicenseCtrl.text.trim(),
      driverIdentityType: _driverIdentityType ?? '',
      driverIdentityDocument: _driverIdentityCtrl.text.trim(),
    );

    if (!mounted) return;

    authController.setSession(session);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _accountType == AccountType.restaurant
              ? 'Cuenta restaurante creada con Google'
              : _accountType == AccountType.driver
              ? 'Solicitud de repartidor enviada con Google'
              : 'Cuenta creada con Google',
        ),
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SessionHomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurant = _accountType == AccountType.restaurant;
    final isDriver = _accountType == AccountType.driver;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRestaurant
              ? 'Cuenta restaurante'
              : isDriver
              ? 'Cuenta repartidor'
              : 'Crear cuenta',
        ),
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
                      'Cliente para pedir, restaurante para vender o repartidor para entregar pedidos aprobados.',
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
                        ButtonSegment<AccountType>(
                          value: AccountType.driver,
                          label: Text('Repartidor'),
                          icon: Icon(Icons.delivery_dining_rounded),
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
                            : isDriver
                            ? 'Usuario de repartidor'
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
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contactCtrl,
                      keyboardType: TextInputType.text,
                      onChanged: (_) => setState(() => _emailError = null),
                      decoration: InputDecoration(
                        labelText: 'Correo o número de teléfono',
                        errorText: _emailError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      maxLength: 20,
                      onChanged: (_) => setState(() => _passError = null),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        errorText: _passError,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F5F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RequirementRow(
                            met:
                                _passCtrl.text.length >= 8 &&
                                _passCtrl.text.length <= 20,
                            label: 'Entre 8 y 20 caracteres',
                          ),
                          _RequirementRow(
                            met: RegExp(r'[A-Z]').hasMatch(_passCtrl.text),
                            label: 'Una letra mayúscula',
                          ),
                          _RequirementRow(
                            met: RegExp(r'[a-z]').hasMatch(_passCtrl.text),
                            label: 'Una letra minúscula',
                          ),
                          _RequirementRow(
                            met: RegExp(r'[0-9]').hasMatch(_passCtrl.text),
                            label: 'Un número',
                          ),
                        ],
                      ),
                    ),
                    if (!isDriver && !isRestaurant) ...[
                      const SizedBox(height: 14),
                      CheckboxListTile(
                        value: _acceptTerms,
                        onChanged: (value) => setState(() {
                          _acceptTerms = value ?? false;
                          _termsError = false;
                        }),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          'Acepto los términos de servicio y el aviso de privacidad.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _acceptTerms
                                ? const Color(0xFF16834B)
                                : const Color(0xFF555555),
                            fontWeight: _acceptTerms
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: _termsError
                            ? const Text(
                                'Debes aceptar para crear tu cuenta.',
                                style: TextStyle(color: Color(0xFFE24A2B)),
                              )
                            : null,
                      ),
                    ],
                    if (isDriver) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEAD79B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverError ?? 'Requisitos del expediente',
                              style: TextStyle(
                                fontSize: 13,
                                color: _driverError == null
                                    ? const Color(0xFF65501C)
                                    : const Color(0xFFE24A2B),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _RequirementRow(
                              met: _driverIsAdult,
                              label: 'Tener al menos 18 años',
                            ),
                            _RequirementRow(
                              met: _driverNameValid,
                              label: 'Nombre legal completo',
                            ),
                            _RequirementRow(
                              met: _driverPhoneValid,
                              label: 'Teléfono de 10 a 15 dígitos',
                            ),
                            _RequirementRow(
                              met: _driverVehicleType != null,
                              label: 'Seleccionar vehículo',
                            ),
                            _RequirementRow(
                              met: _driverIdentityValid,
                              label: 'Identificación oficial y folio',
                            ),
                            if (_motorVehicleSelected) ...[
                              _RequirementRow(
                                met: _driverVehicleDetailsValid,
                                label: 'Marca/modelo, color y placa',
                              ),
                              _RequirementRow(
                                met: _driverLicenseValid,
                                label: 'Licencia o permiso y folio',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _driverFullNameCtrl,
                        onChanged: (_) => setState(() => _driverError = null),
                        decoration: const InputDecoration(
                          labelText: 'Nombre legal completo',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _driverPhoneCtrl,
                        onChanged: (_) => setState(() => _driverError = null),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _driverVehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Vehículo para repartir',
                          prefixIcon: Icon(Icons.delivery_dining_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'motorcycle',
                            child: Text('Moto'),
                          ),
                          DropdownMenuItem(
                            value: 'bicycle',
                            child: Text('Bicicleta'),
                          ),
                          DropdownMenuItem(value: 'car', child: Text('Auto')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _driverVehicleType = value;
                            _driverError = null;
                            if (value == 'bicycle') {
                              _driverLicenseType = null;
                              _driverLicenseCtrl.clear();
                              _driverVehicleMakeModelCtrl.clear();
                              _driverVehicleColorCtrl.clear();
                              _driverVehiclePlateCtrl.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _driverIdentityType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de identificación oficial',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ine', child: Text('INE')),
                          DropdownMenuItem(
                            value: 'passport',
                            child: Text('Pasaporte'),
                          ),
                          DropdownMenuItem(
                            value: 'professional_license',
                            child: Text('Cédula profesional'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _driverIdentityType = value;
                          _driverError = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _driverIdentityCtrl,
                        onChanged: (_) => setState(() => _driverError = null),
                        decoration: const InputDecoration(
                          labelText: 'Folio de identificación',
                          helperText: 'El administrador verificará este dato',
                        ),
                      ),
                      if (_driverVehicleType == 'motorcycle' ||
                          _driverVehicleType == 'car') ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Datos del vehículo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _driverVehicleMakeModelCtrl,
                          onChanged: (_) => setState(() => _driverError = null),
                          decoration: const InputDecoration(
                            labelText: 'Marca y modelo',
                            hintText: 'Ej. Italika FT150 2024',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _driverVehicleColorCtrl,
                          onChanged: (_) => setState(() => _driverError = null),
                          decoration: const InputDecoration(labelText: 'Color'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _driverVehiclePlateCtrl,
                          onChanged: (_) => setState(() => _driverError = null),
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Placa'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _driverLicenseType,
                          decoration: const InputDecoration(
                            labelText: 'Documento para conducir',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'license',
                              child: Text('Licencia de conducir vigente'),
                            ),
                            DropdownMenuItem(
                              value: 'permit',
                              child: Text('Permiso vigente'),
                            ),
                          ],
                          onChanged: (value) => setState(() {
                            _driverLicenseType = value;
                            _driverError = null;
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _driverLicenseCtrl,
                          onChanged: (_) => setState(() => _driverError = null),
                          decoration: const InputDecoration(
                            labelText: 'Folio de licencia o permiso',
                          ),
                        ),
                      ] else if (_driverVehicleType == 'bicycle') ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Para bicicleta no solicitamos licencia ni placa.',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
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
                            : isDriver
                            ? 'Podrás entrar al panel repartidor, pero no tomar pedidos hasta que tu solicitud sea aprobada.'
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
                                  : isDriver
                                  ? 'Enviar solicitud'
                                  : 'Crear cuenta',
                            ),
                    ),
                    const SizedBox(height: 12),
                    GoogleSignInButton(
                      label: isRestaurant
                          ? 'Crear restaurante con Google'
                          : isDriver
                          ? 'Enviar solicitud con Google'
                          : 'Crear cuenta con Google',
                      enabled: !_isLoading,
                      onSignedIn: _onGoogleRegister,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Con Google no necesitas contraseña; el correo se toma de tu cuenta de Gmail.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                        height: 1.35,
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

class _RequirementRow extends StatelessWidget {
  final bool met;
  final String label;

  const _RequirementRow({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = met ? const Color(0xFF16834B) : const Color(0xFF8A8175);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: met ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
