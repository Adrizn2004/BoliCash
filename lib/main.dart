import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'funcionalidades/rbac.dart';
import 'funcionalidades/seguridad/supabase_service.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
final ValueNotifier<UserAccount?> currentUser = ValueNotifier<UserAccount?>(null);
final ValueNotifier<UserRole> currentUserRole = ValueNotifier<UserRole>(UserRole.administradorSistema);

const Color kCrucenoGreen = Color(0xFF007A33);
const Color kCrucenoGreenDark = Color(0xFF005B26);
const Color kCrucenoGreenSoft = Color(0xFFEAF8F0);
const String kCurrencyCode = 'BS';

class UserAccount {
  const UserAccount({
    required this.fullName,
    required this.user,
    required this.password,
    this.balance = 0.0,
  });

  final String fullName;
  final String user;
  final String password;
  final double balance;

  UserAccount copyWith({
    String? fullName,
    String? user,
    String? password,
    double? balance,
  }) {
    return UserAccount(
      fullName: fullName ?? this.fullName,
      user: user ?? this.user,
      password: password ?? this.password,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'user': user,
      'password': password,
      'balance': balance,
    };
  }

  static UserAccount? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final fullName = json['fullName']?.toString() ?? '';
    final user = json['user']?.toString() ?? '';
    final password = json['password']?.toString() ?? '';
    final balance = (json['balance'] as num?)?.toDouble() ?? 0.0;

    if (fullName.isEmpty || user.isEmpty || password.isEmpty) {
      return null;
    }

    return UserAccount(
      fullName: fullName,
      user: user,
      password: password,
      balance: balance,
    );
  }
}

class UserAccountStore {
  static const String _fullNameKey = 'user_full_name';
  static const String _userKey = 'user_username';
  static const String _passwordKey = 'user_password';
  static const String _balanceKey = 'user_balance';

  static Future<void> saveAccount({
    required String fullName,
    required String user,
    required String password,
    double balance = 0.0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final account = UserAccount(
      fullName: fullName,
      user: user,
      password: password,
      balance: balance,
    );

    await prefs.setString(_fullNameKey, fullName);
    await prefs.setString(_userKey, user);
    await prefs.setString(_passwordKey, password);
    await prefs.setDouble(_balanceKey, balance);
    currentUser.value = account;
  }

  static Future<UserAccount?> loadAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString(_fullNameKey);
    final user = prefs.getString(_userKey);
    final password = prefs.getString(_passwordKey);
    final balance = prefs.getDouble(_balanceKey) ?? 0.0;

    if (fullName == null || user == null || password == null) {
      currentUser.value = null;
      return null;
    }

    final account = UserAccount(
      fullName: fullName,
      user: user,
      password: password,
      balance: balance,
    );
    currentUser.value = account;
    return account;
  }

  static Future<void> updateBalance(double newBalance) async {
    final account = currentUser.value ?? await loadAccount();
    if (account == null) return;

    final updatedAccount = account.copyWith(balance: newBalance);
    await saveAccount(
      fullName: updatedAccount.fullName,
      user: updatedAccount.user,
      password: updatedAccount.password,
      balance: updatedAccount.balance,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mmouorgrtaslqlowltwj.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_lkBq2dtAy0TMtLPILhEnaA_pO7_Rf-p',
  );

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  await SupabaseService.initialize();

  runApp(const BancoApp());
}

class AppSettingsStore {
  static const String _notificationsKey = 'settings_notifications';
  static const String _biometricsKey = 'settings_biometrics';
  static const String _themeModeKey = 'settings_theme_mode';

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = prefs.getBool(_notificationsKey) ?? true;
    final biometrics = prefs.getBool(_biometricsKey) ?? true;
    final themeName = prefs.getString(_themeModeKey);
    final themeMode = themeName == ThemeMode.dark.name
        ? ThemeMode.dark
        : ThemeMode.light;

    return {
      'notifications': notifications,
      'biometrics': biometrics,
      'themeMode': themeMode,
    };
  }

  static Future<void> saveSettings({
    required bool notifications,
    required bool biometrics,
    required ThemeMode themeMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, notifications);
    await prefs.setBool(_biometricsKey, biometrics);
    await prefs.setString(_themeModeKey, themeMode.name);
    appThemeMode.value = themeMode;
  }
}

class BancoApp extends StatefulWidget {
  const BancoApp({super.key});

  @override
  State<BancoApp> createState() => _BancoAppState();
}

class _BancoAppState extends State<BancoApp> {
  @override
  void initState() {
    super.initState();
    _loadAppSettings();
  }

  Future<void> _loadAppSettings() async {
    final settings = await AppSettingsStore.loadSettings();
    if (!mounted) return;
    appThemeMode.value = settings['themeMode'] as ThemeMode;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'BoliCash',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: kCrucenoGreen,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: kCrucenoGreen,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: kCrucenoGreen,
              brightness: Brightness.light,
              primary: kCrucenoGreen,
              secondary: kCrucenoGreen,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: kCrucenoGreen,
                foregroundColor: Colors.white,
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: kCrucenoGreen,
              foregroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: kCrucenoGreen,
            scaffoldBackgroundColor: const Color(0xFF111827),
            appBarTheme: const AppBarTheme(
              backgroundColor: kCrucenoGreen,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: kCrucenoGreen,
              brightness: Brightness.dark,
              primary: kCrucenoGreen,
              secondary: kCrucenoGreen,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: kCrucenoGreen,
                foregroundColor: Colors.white,
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: kCrucenoGreen,
              foregroundColor: Colors.white,
            ),
          ),
          home: const LoginScreen(),
          routes: {
            '/home': (_) => const AppShellScreen(),
            '/transfer': (_) => const TransferScreen(),
            '/historial': (_) => const HistorialScreen(),
            '/perfil': (_) => const ProfileScreen(),
            '/scanner': (_) => const ScannerScreen(),
            '/recibir': (_) => const ReceiveQrScreen(),
          },
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());
  String _savedDisplayName = '';

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
  }

  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final focusNode in _pinFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSavedAccount() async {
    final account = await UserAccountStore.loadAccount();
    if (!mounted || account == null) return;

    final fullName = account.fullName.trim();
    final userName = account.user.trim();
    final displayName = fullName.isNotEmpty ? fullName : userName;

    if (displayName.isNotEmpty) {
      setState(() {
        _savedDisplayName = displayName.split(' ').first;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_pinFocusNodes[0]);
    });
  }

  String get _pinValue => _pinControllers.map((controller) => controller.text).join();

  void _onPinChanged(int index, String value) {
    if (value.isEmpty) return;

    if (!RegExp(r'^\d$').hasMatch(value)) {
      _pinControllers[index].clear();
      return;
    }

    if (index < _pinFocusNodes.length - 1) {
      FocusScope.of(context).requestFocus(_pinFocusNodes[index + 1]);
    }

    if (_pinValue.length == 6) {
      _login();
    }
  }

  Future<void> _login() async {
    final pin = _pinValue;

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un PIN de 6 dígitos')),
      );
      return;
    }

    final account = await UserAccountStore.loadAccount();

    if (account == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una cuenta registrada. Crea una antes de iniciar sesión.')),
      );
      return;
    }

    final remoteLoginValid = await SupabaseService.validateCredentials(
      user: account.user,
      name: account.fullName,
      password: pin,
    );

    if (remoteLoginValid) {
      currentUserRole.value = UserRole.administradorSistema;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShellScreen()),
      );
      return;
    }

    if (account.password != pin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN incorrecto')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShellScreen()),
    );
  }

  Future<void> _openRegisterDialog() async {
    final nombreController = TextEditingController();
    final usuarioController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Crear cuenta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Usuario / Correo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nombre = nombreController.text.trim();
                final usuario = usuarioController.text.trim();
                final password = passwordController.text.trim();

                if (nombre.isEmpty || usuario.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Completa todos los campos para registrar la cuenta')),
                  );
                  return;
                }

                final stateContext = context;

                await UserAccountStore.saveAccount(
                  fullName: nombre,
                  user: usuario,
                  password: password,
                );

                if (!stateContext.mounted) return;
                Navigator.pop(dialogContext, true);
                ScaffoldMessenger.of(stateContext).showSnackBar(
                  const SnackBar(content: Text('Cuenta creada correctamente')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      for (final controller in _pinControllers) {
        controller.clear();
      }
      setState(() {
        _savedDisplayName = '';
      });
    }
  }

  Future<void> _openPasswordRecoveryScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecoveryPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSavedAccount = _savedDisplayName.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    size: 80,
                    color: kCrucenoGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasSavedAccount ? 'Hola, $_savedDisplayName' : 'BoliCash',
                    style: TextStyle(
                      fontSize: hasSavedAccount ? 30 : 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF172033),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasSavedAccount ? 'Ingresa tu PIN para continuar' : 'Inicia sesión para continuar',
                    style: const TextStyle(
                      color: Color(0xFF5C6470),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: List.generate(6, (index) {
                      return Expanded(
                        child: Container(
                          height: 54,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _pinControllers[index],
                            focusNode: _pinFocusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            onChanged: (value) => _onPinChanged(index, value),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: kCrucenoGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _pinValue.length == 6 ? _login : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCrucenoGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Ingresar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _openRegisterDialog,
                      child: const Text('Registrarse'),
                    ),
                  ),
                  TextButton(
                    onPressed: _openPasswordRecoveryScreen,
                    child: const Text('¿Olvidaste tu contraseña?'),
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

class RecoveryPasswordScreen extends StatefulWidget {
  const RecoveryPasswordScreen({super.key});

  @override
  State<RecoveryPasswordScreen> createState() => _RecoveryPasswordScreenState();
}

class _RecoveryPasswordScreenState extends State<RecoveryPasswordScreen> {
  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<void> _restorePassword() async {
    final identifier = _identifierController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (identifier.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos para restablecer la contraseña')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    final account = await UserAccountStore.loadAccount();
    if (account == null || account.user != identifier) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No encontramos ese usuario registrado')),
      );
      return;
    }

    await UserAccountStore.saveAccount(
      fullName: account.fullName,
      user: account.user,
      password: newPassword,
      balance: account.balance,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña restablecida correctamente')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Restablece tu contraseña',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ingresa tu usuario o correo registrado y define una nueva clave.',
                    style: TextStyle(color: Color(0xFF5C6470), fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      labelText: 'Correo o usuario registrado',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _restorePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCrucenoGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Restablecer contraseña'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancelar'),
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

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TransferScreen(),
    HistorialScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'Transferir'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _fullName = 'Usuario';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final account = await UserAccountStore.loadAccount();
    if (!mounted) return;

    setState(() {
      _fullName = account?.fullName ?? 'Usuario';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BoliCash',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hola, $_fullName',
                        style: const TextStyle(color: Color(0xFF5C6470), fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF172033),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kCrucenoGreen, kCrucenoGreenDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A1F5EFF),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saldo disponible',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Icon(Icons.visibility_rounded, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<UserAccount?>(
                    valueListenable: currentUser,
                    builder: (context, activeUser, _) {
                      final saldo = activeUser?.balance ?? 0.0;
                      return Text(
                        '${saldo.toStringAsFixed(2)} BS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          label: 'Pagar',
                          icon: Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          textColor: kCrucenoGreen,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScannerScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionButton(
                          label: 'Recibir',
                          icon: Icons.qr_code_2_rounded,
                          color: Colors.white24,
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ReceiveQrScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionTitle(title: 'Acciones rápidas'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.send_rounded,
                    label: 'Transferir',
                    color: const Color(0xFFEEF4FF),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransferScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.history_rounded,
                    label: 'Historial',
                    color: const Color(0xFFE9F9F0),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistorialScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: QuickActionCard(
                    icon: Icons.person_rounded,
                    label: 'Perfil',
                    color: const Color(0xFFFFF2E8),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Últimos movimientos'),
            const SizedBox(height: 12),
            const MovementItem(
              title: 'Abono recibido',
              date: 'Hoy • 08:40',
              value: '+25.00 BS',
              positive: true,
            ),
            const MovementItem(
              title: 'Compra en farmacia',
              date: 'Ayer • 19:20',
              value: '-18.50 BS',
              positive: false,
            ),
            const MovementItem(
              title: 'Transferencia cajero',
              date: 'Ayer • 09:15',
              value: '+40.00 BS',
              positive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  String? _codigo;

  void _generarCodigo() {
    final random = Random();
    final codigo = (100000 + random.nextInt(900000)).toString();
    setState(() {
      _codigo = codigo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferir'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transferir a cajero',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Genera un código de 6 dígitos para cobro o retiro en cajero.',
                style: TextStyle(color: Color(0xFF5C6470), fontSize: 15),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: kCrucenoGreen,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Código generado',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _codigo ?? '------',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generarCodigo,
                  icon: const Icon(Icons.generating_tokens_rounded),
                  label: const Text('Generar código'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCrucenoGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Volver al inicio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            MovementItem(title: 'Abono', date: 'Hoy • 08:40', value: '+25.00 BS', positive: true),
            MovementItem(title: 'Transferencia', date: 'Ayer • 16:10', value: '-50.00 BS', positive: false),
            MovementItem(title: 'Pago QR', date: 'Ayer • 13:30', value: '-12.90 BS', positive: false),
            MovementItem(title: 'Cargo recibido', date: 'Lun • 09:00', value: '+100.00 BS', positive: true),
            MovementItem(title: 'Recarga móvil', date: 'Dom • 21:15', value: '-20.00 BS', positive: false),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ciController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _fullName = 'Belen Montes';
  String _userEmail = 'belen.montes@gmail.com';
  String _ci = '12345678';
  String _phone = '+591 71234567';
  String _city = 'Santa Cruz';
  String _address = 'Av. Ballivian Nro. 245';
  final String _accountNumber = '3419 8456 023';

  bool _isEditing = false;
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = true;
  bool _twoFactorEnabled = true;
  bool _darkModeEnabled = false;
  UserRole _currentRole = UserRole.administradorSistema;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ciController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final account = await UserAccountStore.loadAccount();
    if (!mounted) return;

    final loadedName = account?.fullName.trim() ?? 'Belen Montes';
    final loadedEmail = account?.user.trim() ?? 'belen.montes@gmail.com';
    final role = await SupabaseService.resolveUserRole(loadedEmail);

    setState(() {
      _fullName = loadedName;
      _userEmail = loadedEmail;
      _nameController.text = loadedName;
      _emailController.text = loadedEmail;
      _ciController.text = _ci;
      _phoneController.text = _phone;
      _cityController.text = _city;
      _addressController.text = _address;
      _currentRole = role;
    });
  }

  Future<void> _loadSettings() async {
    final settings = await AppSettingsStore.loadSettings();
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = settings['notifications'] as bool;
      _biometricsEnabled = settings['biometrics'] as bool;
      _darkModeEnabled = settings['themeMode'] == ThemeMode.dark;
    });
  }

  Future<void> _saveProfileChanges() async {
    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final ci = _ciController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || ci.isEmpty || city.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los datos personales.')),
      );
      return;
    }

    final account = await UserAccountStore.loadAccount();
    if (account != null) {
      await UserAccountStore.saveAccount(
        fullName: name,
        user: email,
        password: account.password,
        balance: account.balance,
      );
    }

    if (!mounted) return;

    setState(() {
      _fullName = name;
      _userEmail = email;
      _ci = ci;
      _phone = phone;
      _city = city;
      _address = address;
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos personales actualizados')),
    );
  }

  Future<void> _saveConfiguration() async {
    await AppSettingsStore.saveSettings(
      notifications: _notificationsEnabled,
      biometrics: _biometricsEnabled,
      themeMode: _darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración guardada')),
    );
  }

  Future<void> _updatePin() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cambiar PIN'),
          content: TextField(
            controller: controller,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nuevo PIN de 6 dígitos',
              prefixIcon: Icon(Icons.lock_outline_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El PIN debe tener 6 dígitos numéricos.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, pin);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    final account = await UserAccountStore.loadAccount();
    if (account == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No existe una cuenta activa para actualizar el PIN.')),
      );
      return;
    }

    await UserAccountStore.saveAccount(
      fullName: account.fullName,
      user: account.user,
      password: result,
      balance: account.balance,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN actualizado correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
      ),
      backgroundColor: const Color(0xFFF5F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kCrucenoGreen, width: 4),
                        color: const Color(0xFFEAF8F0),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 52,
                        color: kCrucenoGreen,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _fullName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cuenta • $_accountNumber',
                      style: const TextStyle(
                        color: Color(0xFF5C6470),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: kCrucenoGreenSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_user_rounded, color: kCrucenoGreen, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Cliente activo • CI $_ci',
                                  style: const TextStyle(
                                    color: Color(0xFF172033),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.badge_rounded, color: kCrucenoGreen, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Rol activo • ${_currentRole.label}',
                                  style: const TextStyle(
                                    color: Color(0xFF172033),
                                    fontWeight: FontWeight.w700,
                                  ),
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
              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Datos personales',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF172033),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = !_isEditing;
                            });
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: Text(_isEditing ? 'Cancelar' : 'Editar datos'),
                          style: TextButton.styleFrom(
                            foregroundColor: kCrucenoGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isEditing)
                      Form(
                        key: _profileFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu nombre' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ciController,
                              keyboardType: TextInputType.number,
                              maxLength: 12,
                              decoration: const InputDecoration(
                                labelText: 'Cédula de identidad',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu CI' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Ingresa un correo';
                                final emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                return emailPattern.hasMatch(value.trim()) ? null : 'Correo inválido';
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Ingresa un teléfono';
                                final phonePattern = RegExp(r'^\+?\d{8,15}$');
                                return phonePattern.hasMatch(value.trim().replaceAll(' ', '')) ? null : 'Teléfono inválido';
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'Ciudad',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu ciudad' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Dirección',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(14)),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Ingresa tu dirección' : null,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveProfileChanges,
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('Guardar cambios'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kCrucenoGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          _ProfileInfoRow(label: 'Nombre completo', value: _fullName),
                          _ProfileInfoRow(label: 'Cédula de Identidad', value: _ci),
                          _ProfileInfoRow(label: 'Correo electrónico', value: _userEmail),
                          _ProfileInfoRow(label: 'Teléfono', value: _phone),
                          _ProfileInfoRow(label: 'Ciudad / Dirección', value: '$_city · $_address'),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seguridad',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileActionTile(
                      icon: Icons.pin_rounded,
                      title: 'Cambiar PIN',
                      subtitle: 'Actualiza tu clave de 6 dígitos',
                      trailing: const Icon(Icons.chevron_right_rounded, color: kCrucenoGreen),
                      onTap: _updatePin,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.fingerprint_rounded,
                      title: 'Biometría',
                      subtitle: 'Huella/Face ID',
                      trailing: Switch(
                        value: _biometricsEnabled,
                        activeThumbColor: kCrucenoGreen,
                        onChanged: (value) {
                          setState(() {
                            _biometricsEnabled = value;
                          });
                        },
                      ),
                      onTap: null,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.shield_rounded,
                      title: 'Autenticación en 2 pasos',
                      subtitle: _twoFactorEnabled
                          ? 'Estado: activo y verificado'
                          : 'Estado: desactivado',
                      trailing: Icon(
                        _twoFactorEnabled ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                        color: kCrucenoGreen,
                      ),
                      onTap: () {
                        setState(() {
                          _twoFactorEnabled = !_twoFactorEnabled;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuración',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileActionTile(
                      icon: Icons.notifications_active_rounded,
                      title: 'Notificaciones',
                      subtitle: 'Alertas y novedades',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        activeThumbColor: kCrucenoGreen,
                        onChanged: (value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                          _saveConfiguration();
                        },
                      ),
                      onTap: null,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Modo oscuro',
                      subtitle: 'Tema claro/oscuro',
                      trailing: Switch(
                        value: _darkModeEnabled,
                        activeThumbColor: kCrucenoGreen,
                        onChanged: (value) {
                          setState(() {
                            _darkModeEnabled = value;
                          });
                          _saveConfiguration();
                        },
                      ),
                      onTap: null,
                    ),
                    const SizedBox(height: 8),
                    _ProfileActionTile(
                      icon: Icons.security_rounded,
                      title: 'Protección avanzada',
                      subtitle: 'Seguridad reforzada activa',
                      trailing: const Icon(Icons.check_circle_rounded, color: kCrucenoGreen),
                      onTap: null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCrucenoGreen,
                    side: const BorderSide(color: kCrucenoGreen),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5C6470),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kCrucenoGreenSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kCrucenoGreen),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF5C6470))),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _montoController = TextEditingController(text: '25.00');
  final TextEditingController _codigoController = TextEditingController();
  Uint8List? _qrImageBytes;
  String? _qrImageName;
  late final AnimationController _scanLineController;

  bool get _isWeb => kIsWeb;
  bool get _isMobileCamera => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  Future<void> _pickQrImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    final file = result?.files.single;
    if (file == null) return;

    setState(() {
      _qrImageBytes = file.bytes;
      _qrImageName = file.name;
    });
  }

  void _simularEscaneo() {
    final codigo = 'BOL-${DateTime.now().millisecondsSinceEpoch % 900000 + 100000}';
    _codigoController.text = codigo;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('QR simulado detectado: $codigo')),
    );
  }

  Future<void> _confirmarPago() async {
    final valor = double.tryParse(_montoController.text.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido en BS.')),
      );
      return;
    }

    final activeUser = currentUser.value ?? await UserAccountStore.loadAccount();
    if (activeUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una cuenta activa para realizar el pago.')),
      );
      return;
    }

    if (valor > activeUser.balance) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo insuficiente para confirmar este pago.')),
      );
      return;
    }

    await UserAccountStore.updateBalance(activeUser.balance - valor);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pago confirmado por ${valor.toStringAsFixed(2)} BS')),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _montoController.dispose();
    _codigoController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  Widget _buildViewer() {
    if (_isWeb) {
      return Column(
        children: [
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, child) {
              final offset = _scanLineController.value * 180;
              return Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF101827),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kCrucenoGreen, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 24,
                      left: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cámara web',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    Positioned(
                      top: 40 + offset,
                      left: 90,
                      right: 90,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8FCBFF),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFF8FCBFF), blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Escaneando…',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codigoController,
            decoration: const InputDecoration(
              labelText: 'Código QR o identificación',
              prefixIcon: Icon(Icons.qr_code_2_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _simularEscaneo,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Simular escaneo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kCrucenoGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_isMobileCamera) {
      return Column(
        children: [
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: MobileScanner(
                controller: MobileScannerController(
                  detectionTimeoutMs: 2000,
                ),
                onDetect: (capture) {
                  final value = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
                  if (value == null || !mounted) return;

                  setState(() {
                    _codigoController.text = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codigoController,
            readOnly: false,
            decoration: const InputDecoration(
              labelText: 'Código QR escaneado',
              prefixIcon: Icon(Icons.qr_code_scanner_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar con QR')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escáner de pago',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                _isWeb
                    ? 'Modo navegador: escaneo simulado para evitar congelar Chrome. Moneda: Bolivianos (BS).'
                    : 'Escanea el QR con la cámara del dispositivo para confirmar el pago en Bolivianos (BS).',
                style: const TextStyle(color: Color(0xFF5C6470), fontSize: 15),
              ),
              const SizedBox(height: 18),
              _buildViewer(),
              const SizedBox(height: 18),
              TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto a pagar',
                  prefixText: '$kCurrencyCode ',
                  prefixStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kCrucenoGreen,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickQrImage,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Subir imagen de QR'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (_qrImageName != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kCrucenoGreenSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: kCrucenoGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _qrImageName ?? '',
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_qrImageBytes != null)
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _qrImageBytes!,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmarPago,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCrucenoGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Confirmar Pago'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReceiveQrScreen extends StatefulWidget {
  const ReceiveQrScreen({super.key});

  @override
  State<ReceiveQrScreen> createState() => _ReceiveQrScreenState();
}

class _ReceiveQrScreenState extends State<ReceiveQrScreen> {
  String _fullName = 'Usuario';
  String _accountNumber = '3419385-000-001';
  double _amount = 100.0;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    final account = await UserAccountStore.loadAccount();
    if (!mounted) return;

    final userKey = account?.user ?? 'usuario';
    final seed = userKey.toLowerCase().codeUnits.fold<int>(0, (sum, code) => sum + code) % 900000;
    final generatedAccount = '341${(100000 + seed).toString().padLeft(6, '0')}-000-001';

    setState(() {
      _fullName = account?.fullName ?? 'Usuario';
      _accountNumber = generatedAccount;
    });
  }

  String _formatValidUntil(DateTime date) {
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  String get _qrData {
    return 'BOLIVIA|$_fullName|$_accountNumber|${_amount.toStringAsFixed(2)}BS';
  }

  Future<void> _changeAmount() async {
    final controller = TextEditingController(text: _amount.toStringAsFixed(2));

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cambiar monto'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Monto en BS',
              prefixText: '$kCurrencyCode ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: kCrucenoGreen,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value != null && value > 0) {
                  Navigator.pop(dialogContext, controller.text.trim());
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un monto válido')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final newAmount = double.tryParse(result);
      if (newAmount != null && newAmount > 0) {
        setState(() {
          _amount = newAmount;
          _validUntil = DateTime.now().add(const Duration(days: 30));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobra con QR')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Tu código QR',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cobro a nombre de $_fullName',
                  style: const TextStyle(color: Color(0xFF5C6470), fontSize: 15),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 10),
                      )
                    ],
                  ),
                  child: QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 230,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCrucenoGreenSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Válido hasta: ${_formatValidUntil(_validUntil)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF172033),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'CTA: $_accountNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF172033),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Monto: ${_amount.toStringAsFixed(2)} BS',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kCrucenoGreen,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final scaffoldContext = context;
                      await Clipboard.setData(ClipboardData(text: _qrData));
                      if (!scaffoldContext.mounted) return;
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(content: Text('Información del QR copiada al portapapeles')),
                      );
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Compartir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCrucenoGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _changeAmount,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Cambiar monto'),
                    style: TextButton.styleFrom(
                      foregroundColor: kCrucenoGreen,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: kCrucenoGreen),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF172033),
      ),
    );
  }
}

class MovementItem extends StatelessWidget {
  const MovementItem({
    super.key,
    required this.title,
    required this.date,
    required this.value,
    required this.positive,
  });

  final String title;
  final String date;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: positive ? const Color(0xFFE8F9EF) : const Color(0xFFFFF2E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: positive ? const Color(0xFF1AA86E) : const Color(0xFFFA8B28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    color: Color(0xFF5C6470),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: positive ? const Color(0xFF1AA86E) : const Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }
}
