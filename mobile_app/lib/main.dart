import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const forest = Color(0xFF31563C);
const leaf = Color(0xFF527E5D);
const paper = Color(0xFFF7F8F4);
const pale = Color(0xFFE9F0E7);

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get supabaseConfigured =>
    supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const HelpUsApp());
}

class HelpUsApp extends StatelessWidget {
  const HelpUsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HelpUs',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: forest,
        primary: forest,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: forest,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8ECE5)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: pale,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!supabaseConfigured) return const BackendSetupScreen();
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        return session == null ? const PhoneLoginScreen() : const HelpUsHome();
      },
    );
  }
}

class BackendSetupScreen extends StatelessWidget {
  const BackendSetupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _HelpUsMark(),
                    const SizedBox(height: 18),
                    Text(
                      'HelpUs',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: forest,
                          ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Phone login is ready, but this app still needs its Supabase project URL, publishable key, phone OTP setup, and SMS provider.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF778278), height: 1.55),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Configure with --dart-define=SUPABASE_URL=… and --dart-define=SUPABASE_ANON_KEY=… then rebuild the APK.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: forest),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phone = TextEditingController(text: '+91 ');
  final _name = TextEditingController();
  final _otp = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  String _normalisedPhone() {
    final value = _phone.text.replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^\d{10}$').hasMatch(value)) return '+91$value';
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value) ? value : '';
  }

  Future<void> _sendCode() async {
    final phone = _normalisedPhone();
    if (phone.isEmpty) {
      _setMessage(
        'Enter a valid mobile number with country code, such as +91 98765 43210.',
        error: true,
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: true,
        data: {'display_name': _name.text.trim()},
      );
      setState(() {
        _otpSent = true;
        _busy = false;
        _phone.text = phone;
      });
      _setMessage('Code sent to $phone. It may take a minute to arrive.');
    } on AuthException catch (error) {
      setState(() => _busy = false);
      _setMessage(error.message, error: true);
    } catch (_) {
      setState(() => _busy = false);
      _setMessage(
        'Could not send the code. Check your number and try again.',
        error: true,
      );
    }
  }

  Future<void> _verifyCode() async {
    final phone = _normalisedPhone();
    final token = _otp.text.replaceAll(RegExp(r'\D'), '');
    if (token.length != 6) {
      _setMessage('Enter the 6-digit code sent to your phone.', error: true);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      if (mounted) setState(() => _busy = false);
    } on AuthException catch (error) {
      if (mounted) setState(() => _busy = false);
      _setMessage(error.message, error: true);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _setMessage(
        'That code did not work. Request a new code and try again.',
        error: true,
      );
    }
  }

  void _setMessage(String value, {bool error = false}) {
    if (mounted)
      setState(() {
        _message = value;
        _isError = error;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _HelpUsMark()),
                const SizedBox(height: 23),
                Text(
                  _otpSent ? 'Check your messages.' : 'Welcome to HelpUs.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: forest),
                ),
                const SizedBox(height: 7),
                Text(
                  _otpSent
                      ? 'Enter the code we sent to ${_normalisedPhone()}.'
                      : 'Sign in or create an account with your mobile number.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF778278), height: 1.5),
                ),
                const SizedBox(height: 23),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        if (!_otpSent) ...[
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Your name (new accounts)',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Mobile number',
                              prefixIcon: Icon(Icons.phone_android_rounded),
                              hintText: '+91 98765 43210',
                            ),
                          ),
                        ] else
                          TextField(
                            controller: _otp,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              labelText: '6-digit verification code',
                              counterText: '',
                            ),
                          ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: _isError ? const Color(0xFFFAEEE9) : pale,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(
                                fontSize: 11,
                                color: _isError
                                    ? const Color(0xFF9B4D3D)
                                    : forest,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : (_otpSent ? _verifyCode : _sendCode),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _otpSent
                                          ? 'Verify & continue'
                                          : 'Send one-time code',
                                    ),
                            ),
                          ),
                        ),
                        if (_otpSent)
                          TextButton(
                            onPressed: _busy ? null : _sendCode,
                            child: const Text('Send a new code'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your phone number stays private. We use it for account verification and vehicle alerts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF929B92),
                    fontSize: 10,
                    height: 1.5,
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

class _HelpUsMark extends StatelessWidget {
  const _HelpUsMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      color: const Color(0xFFDCE9DC),
      borderRadius: BorderRadius.circular(17),
    ),
    child: const Icon(
      Icons.directions_car_filled_rounded,
      color: forest,
      size: 29,
    ),
  );
}

class HelpUsHome extends StatefulWidget {
  const HelpUsHome({super.key});

  @override
  State<HelpUsHome> createState() => _HelpUsHomeState();
}

class _HelpUsHomeState extends State<HelpUsHome> {
  int _tab = 0;
  bool _keepPhonePrivate = true;
  bool _parkingAlerts = true;
  bool _vehicleDetails = true;
  bool _location = false;
  final List<Vehicle> _vehicles = [];
  final List<Map<String, dynamic>> _scanAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadAlerts();
    _loadPreferences();
  }

  Future<void> _loadVehicles() async {
    try {
      final rows = await Supabase.instance.client
          .from('vehicles')
          .select()
          .order('created_at', ascending: false);
      final loaded = (rows as List).map((row) {
        final data = Map<String, dynamic>.from(row as Map);
        final facts = [
          data['model_year']?.toString(),
          data['color']?.toString(),
        ].where((value) => value != null && value.isNotEmpty).join(' · ');
        return Vehicle(
          data['make_model'] as String,
          data['registration_number'] as String,
          facts,
          tagId: data['tag_code'] as String,
          isActive: data['is_active'] as bool? ?? true,
        );
      }).toList();
      if (mounted)
        setState(() {
          _vehicles
            ..clear()
            ..addAll(loaded);
        });
    } catch (_) {
      if (mounted)
        _notice(
          'Could not load your vehicles. Pull to refresh or sign in again.',
        );
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final rows = await Supabase.instance.client
          .from('scan_alerts')
          .select('id,event_type,message,city,created_at,vehicles(make_model)')
          .order('created_at', ascending: false);
      if (mounted)
        setState(() {
          _scanAlerts
            ..clear()
            ..addAll(
              (rows as List).map(
                (row) => Map<String, dynamic>.from(row as Map),
              ),
            );
        });
    } catch (_) {
      if (mounted) _notice('Could not load scan alerts.');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select(
            'keep_phone_private,allow_parking_alerts,show_vehicle_details,share_location',
          )
          .eq('id', userId)
          .maybeSingle();
      if (profile != null && mounted)
        setState(() {
          _keepPhonePrivate = profile['keep_phone_private'] as bool? ?? true;
          _parkingAlerts = profile['allow_parking_alerts'] as bool? ?? true;
          _vehicleDetails = profile['show_vehicle_details'] as bool? ?? true;
          _location = profile['share_location'] as bool? ?? false;
        });
    } catch (_) {
      if (mounted) _notice('Could not load your privacy settings.');
    }
  }

  Future<void> _savePreference(
    String column,
    bool value,
    void Function(bool) apply,
  ) async {
    apply(value);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('profiles')
          .update({
            column: value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
    } catch (_) {
      _notice('Could not save that setting. Please try again.');
      await _loadPreferences();
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: forest,
      ),
    );

  Future<void> _addVehicle() async {
    final tagId = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const TagScannerScreen()));
    if (tagId == null || !mounted) return;
    final name = TextEditingController();
    final registration = TextEditingController();
    final result = await showDialog<Vehicle>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Make & model',
                hintText: 'e.g. Honda City',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: registration,
              decoration: const InputDecoration(
                labelText: 'Registration number',
                hintText: 'KA 03 AB 1234',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty &&
                  registration.text.trim().isNotEmpty) {
                Navigator.pop(
                  dialogContext,
                  Vehicle(
                    name.text.trim(),
                    registration.text.trim().toUpperCase(),
                    'Added just now',
                    tagId: tagId,
                  ),
                );
              }
            },
            child: const Text('Save vehicle'),
          ),
        ],
      ),
    );
    name.dispose();
    registration.dispose();
    if (result != null && mounted) {
      try {
        await Supabase.instance.client.rpc(
          'register_vehicle',
          params: {
            'p_tag_code': result.tagId,
            'p_make_model': result.name,
            'p_registration_number': result.registration,
            'p_vehicle_type': 'car',
            'p_model_year': null,
            'p_color': '',
          },
        );
        await _loadVehicles();
        _notice('Vehicle registered to your HelpUs account.');
      } on PostgrestException catch (error) {
        _notice(error.message);
      } catch (_) {
        _notice(
          'Could not register the vehicle. Check your connection and try again.',
        );
      }
    }
  }

  void _sendAlert() async {
    final note = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send a quick alert',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Choose a helpful note for the owner.'),
              const SizedBox(height: 18),
              _alertOption(
                context,
                Icons.lightbulb_outline,
                'Lights may be on',
                'Your headlights might still be on.',
              ),
              _alertOption(
                context,
                Icons.local_parking_outlined,
                'Parking concern',
                'Your vehicle might be blocking someone.',
              ),
              _alertOption(
                context,
                Icons.favorite_border,
                'Something else',
                'I noticed something that may need your attention.',
              ),
            ],
          ),
        ),
      ),
    );
    if (note != null && mounted)
      _notice('Demo alert not sent. Backend connection is needed.');
  }

  Widget _alertOption(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: pale,
      foregroundColor: leaf,
      child: Icon(icon),
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.pop(context, value),
  );

  @override
  Widget build(BuildContext context) {
    final screens = [_overview(), _garage(), _alerts(), _settings()];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE9DC),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                size: 19,
                color: forest,
              ),
            ),
            const SizedBox(width: 9),
            const Text(
              'HelpUs',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _tab = 2);
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(key: ValueKey(_tab), child: screens[_tab]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            label: 'Vehicles',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _overview() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
    children: [
      const Text(
        'MONDAY, 17 NOVEMBER',
        style: TextStyle(
          color: leaf,
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'A little peace of mind, ${Supabase.instance.client.auth.currentUser?.phone ?? 'there'}.',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.8),
      ),
      const SizedBox(height: 5),
      const Text(
        "Here's what's happening with your vehicles.",
        style: TextStyle(color: Color(0xFF778278)),
      ),
      const SizedBox(height: 20),
      if (_vehicles.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'YOUR VEHICLES',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: leaf,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _statusChip('Tag active'),
                  ],
                ),
                const SizedBox(height: 13),
                Container(
                  height: 142,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.directions_car_filled_rounded,
                      size: 88,
                      color: Color(0xFF82AD8B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _vehicles.first.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_vehicles.first.subtitle} · ${_vehicles.first.registration}',
                  style: const TextStyle(
                    color: Color(0xFF78847A),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'QR tag · ${_vehicles.first.tagId}',
                  style: const TextStyle(
                    color: leaf,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      if (_vehicles.isEmpty)
        Card(
          color: const Color(0xFFF0F4ED),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: leaf,
                  size: 36,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your garage is ready.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan a HelpUs tag to register your first vehicle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF778278), fontSize: 11),
                ),
                const SizedBox(height: 11),
                FilledButton.icon(
                  onPressed: _addVehicle,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan tag'),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'You’re in the loop.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _tab = 2),
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (_scanAlerts.isEmpty)
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: pale,
                    child: Icon(Icons.notifications_none_rounded, color: leaf),
                  ),
                  title: Text(
                    'No scan alerts yet',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  subtitle: Text(
                    'Updates will appear here when a visitor contacts you.',
                    style: TextStyle(fontSize: 10),
                  ),
                )
              else
                ..._scanAlerts
                    .take(2)
                    .map(
                      (alert) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: _activity(
                          Icons.near_me_outlined,
                          _alertTitle(alert),
                          _alertDetail(alert),
                          _alertTime(alert),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        color: const Color(0xFFF0F4ED),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFDCE9D8),
            child: Icon(Icons.favorite_border, color: leaf),
          ),
          title: const Text(
            'Your privacy is in your hands.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: const Text(
            'Your phone number is hidden. You choose how people can reach you.',
            style: TextStyle(fontSize: 11),
          ),
          onTap: () => setState(() => _tab = 3),
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _sendAlert,
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Preview a quick alert'),
      ),
      const SizedBox(height: 8),
      const Center(
        child: Text(
          'HelpUs demo · alerts and calls are not connected',
          style: TextStyle(fontSize: 10, color: Color(0xFF929B92)),
        ),
      ),
    ],
  );

  Widget _garage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
    children: [
      const Text(
        'YOUR GARAGE',
        style: TextStyle(
          color: leaf,
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        'My vehicles',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Manage tags and what scanners can see.',
        style: TextStyle(color: Color(0xFF778278)),
      ),
      const SizedBox(height: 18),
      ..._vehicles.map(
        (vehicle) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: pale,
              child: const Icon(Icons.directions_car_filled, color: leaf),
            ),
            title: Text(
              vehicle.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${vehicle.subtitle}\n${vehicle.registration}\nQR tag · ${vehicle.tagId}',
            ),
            isThreeLine: true,
            trailing: _statusChip('Active'),
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _addVehicle,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan tag & add vehicle'),
      ),
    ],
  );

  Widget _alerts() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
    children: [
      const Text(
        'YOUR NOTIFICATIONS',
        style: TextStyle(
          color: leaf,
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        'Scan alerts',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Helpful updates from people who scanned your vehicle.',
        style: TextStyle(color: Color(0xFF778278)),
      ),
      const SizedBox(height: 18),
      if (_scanAlerts.isEmpty)
        const Card(
          child: ListTile(
            leading: Icon(Icons.notifications_none_rounded, color: leaf),
            title: Text(
              'No scan alerts yet',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'When someone sends a note through your tag, it will appear here.',
              style: TextStyle(fontSize: 11),
            ),
          ),
        )
      else
        ..._scanAlerts.map(
          (alert) => _alertCard(
            Icons.near_me_outlined,
            _alertTitle(alert),
            _alertDetail(alert),
            _alertTime(alert),
            alert['message'] as String?,
          ),
        ),
      const SizedBox(height: 8),
      const Center(
        child: Text(
          'Alerts come from verified HelpUs tag scans.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Color(0xFF929B92)),
        ),
      ),
    ],
  );

  Widget _settings() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
    children: [
      const Text(
        'YOUR PREFERENCES',
        style: TextStyle(
          color: leaf,
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        'Settings',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Choose how your information is shared.',
        style: TextStyle(color: Color(0xFF778278)),
      ),
      const SizedBox(height: 18),
      Card(
        child: Column(
          children: [
            _setting(
              'Keep my phone number private',
              'Your number is never shown on the scan page.',
              Switch(
                value: _keepPhonePrivate,
                onChanged: (v) => _savePreference(
                  'keep_phone_private',
                  v,
                  (value) => setState(() => _keepPhonePrivate = value),
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _setting(
              'Allow parking alerts',
              'Let scanners send a quick note.',
              Switch(
                value: _parkingAlerts,
                onChanged: (v) => _savePreference(
                  'allow_parking_alerts',
                  v,
                  (value) => setState(() => _parkingAlerts = value),
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _setting(
              'Show vehicle details',
              'Help scanners identify the right vehicle.',
              Switch(
                value: _vehicleDetails,
                onChanged: (v) => _savePreference(
                  'show_vehicle_details',
                  v,
                  (value) => setState(() => _vehicleDetails = value),
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _setting(
              'Share my location',
              'Only share when you choose to.',
              Switch(
                value: _location,
                onChanged: (v) => _savePreference(
                  'share_location',
                  v,
                  (value) => setState(() => _location = value),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: ListTile(
          leading: const Icon(Icons.phone_android_rounded, color: leaf),
          title: const Text(
            'Signed in with phone',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            Supabase.instance.client.auth.currentUser?.phone ?? '',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: TextButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            child: const Text('Sign out'),
          ),
        ),
      ),
      const SizedBox(height: 9),
      const Center(
        child: Text(
          'Vehicle scans and alerts need active tag records and server-side events.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Color(0xFF929B92)),
        ),
      ),
    ],
  );

  String _alertTitle(Map<String, dynamic> alert) =>
      switch (alert['event_type']) {
        'parking' => 'Parking note for your vehicle',
        'lights' => 'Lights may need your attention',
        'other' => 'A visitor sent you a note',
        _ => 'Your HelpUs tag was scanned',
      };

  String _alertDetail(Map<String, dynamic> alert) {
    final vehicle = alert['vehicles'];
    final model = vehicle is Map ? vehicle['make_model']?.toString() : null;
    return [
      if ((alert['city'] as String? ?? '').isNotEmpty) alert['city'],
      model,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
  }

  String _alertTime(Map<String, dynamic> alert) {
    final parsed = DateTime.tryParse(alert['created_at']?.toString() ?? '');
    return parsed?.toLocal().toString().substring(0, 16) ?? 'Recently';
  }

  Widget _setting(String title, String subtitle, Widget trailing) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)),
      trailing: trailing,
    ),
  );

  Widget _activity(
    IconData icon,
    String title,
    String detail,
    String time,
  ) => Row(
    children: [
      CircleAvatar(
        radius: 17,
        backgroundColor: pale,
        foregroundColor: leaf,
        child: Icon(icon, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(color: Color(0xFF879187), fontSize: 10),
            ),
          ],
        ),
      ),
      Text(time, style: const TextStyle(color: Color(0xFF9AA39A), fontSize: 9)),
    ],
  );

  Widget _alertCard(
    IconData icon,
    String title,
    String detail,
    String time,
    String? message,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: pale,
            foregroundColor: leaf,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF748075),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  time,
                  style: const TextStyle(color: Color(0xFF929B92), fontSize: 9),
                ),
                if (message != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF647265),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _statusChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: pale,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '● $label',
      style: const TextStyle(
        color: leaf,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class Vehicle {
  const Vehicle(
    this.name,
    this.registration,
    this.subtitle, {
    this.tagId = '',
    this.isActive = true,
  });
  final String name;
  final String registration;
  final String subtitle;
  final String tagId;
  final bool isActive;
}

class TagScannerScreen extends StatefulWidget {
  const TagScannerScreen({super.key});

  @override
  State<TagScannerScreen> createState() => _TagScannerScreenState();
}

class _TagScannerScreenState extends State<TagScannerScreen> {
  bool _handled = false;
  String? _error;

  String? _tagIdFrom(String value) {
    final raw = value.trim();
    final match = RegExp(
      r'^(?:HELPUS:|helpus://tag/|https?://(?:www\.)?helpus\.[^/]+/tag/)([A-Za-z0-9_-]{4,64})/?$',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1)?.toUpperCase();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((raw) => _tagIdFrom(raw) != null, orElse: () => '');
    if (value.isEmpty) {
      if (!_handled && mounted)
        setState(() => _error = 'That QR code is not a HelpUs vehicle tag.');
      return;
    }
    final tagId = _tagIdFrom(value);
    if (tagId == null) return;
    _handled = true;
    Navigator.of(context).pop(tagId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan your HelpUs tag'),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            const Text(
              'Scan first. Register second.',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: forest,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Point your camera at the QR code on the HelpUs tag. Vehicle registration unlocks only after a valid tag is recognised.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF78847A), height: 1.45),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(onDetect: _onDetect),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 236,
                          height: 236,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error ?? 'Keep the HelpUs QR code inside the frame',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 15, color: leaf),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'A HelpUs-format QR unlocks the form. Live tag verification needs a server.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF69776B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
