import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const forest = Color(0xFF31563C);
const leaf = Color(0xFF527E5D);
const paper = Color(0xFFF7F8F4);
const pale = Color(0xFFE9F0E7);

void main() => runApp(const HelpUsApp());

class HelpUsApp extends StatelessWidget {
  const HelpUsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HelpUs',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest, surface: Colors.white),
          appBarTheme: const AppBarTheme(backgroundColor: paper, foregroundColor: forest, elevation: 0),
          cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE8ECE5)))),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: pale,
            labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        home: const HelpUsHome(),
      );
}

class HelpUsHome extends StatefulWidget {
  const HelpUsHome({super.key});

  @override
  State<HelpUsHome> createState() => _HelpUsHomeState();
}

class _HelpUsHomeState extends State<HelpUsHome> {
  int _tab = 0;
  bool _parkingAlerts = true;
  bool _vehicleDetails = true;
  bool _location = false;
  final List<Vehicle> _vehicles = [Vehicle('Honda City', 'KA 03 AB 1234', '2022 · White', tagId: 'HU-DEMO-001')];

  void _notice(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: forest));

  Future<void> _addVehicle() async {
    final tagId = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const TagScannerScreen()));
    if (tagId == null || !mounted) return;
    final name = TextEditingController();
    final registration = TextEditingController();
    final result = await showDialog<Vehicle>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a vehicle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Make & model', hintText: 'e.g. Honda City')),
          const SizedBox(height: 12),
          TextField(controller: registration, decoration: const InputDecoration(labelText: 'Registration number', hintText: 'KA 03 AB 1234')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (name.text.trim().isNotEmpty && registration.text.trim().isNotEmpty) {
              Navigator.pop(dialogContext, Vehicle(name.text.trim(), registration.text.trim().toUpperCase(), 'Added just now', tagId: tagId));
            }
          }, child: const Text('Save vehicle')),
        ],
      ),
    );
    name.dispose();
    registration.dispose();
    if (result != null && mounted) setState(() => _vehicles.add(result));
  }

  void _sendAlert() async {
    final note = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Send a quick alert', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Choose a helpful note for the owner.'),
          const SizedBox(height: 18),
          _alertOption(context, Icons.lightbulb_outline, 'Lights may be on', 'Your headlights might still be on.'),
          _alertOption(context, Icons.local_parking_outlined, 'Parking concern', 'Your vehicle might be blocking someone.'),
          _alertOption(context, Icons.favorite_border, 'Something else', 'I noticed something that may need your attention.'),
        ]),
      )),
    );
    if (note != null && mounted) _notice('Demo alert not sent. Backend connection is needed.');
  }

  Widget _alertOption(BuildContext context, IconData icon, String label, String value) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: pale, foregroundColor: leaf, child: Icon(icon)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pop(context, value),
      );

  @override
  Widget build(BuildContext context) {
    final screens = [_overview(), _garage(), _alerts(), _settings()];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFDCE9DC), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.directions_car_filled_rounded, size: 19, color: forest)),
          const SizedBox(width: 9),
          const Text('HelpUs', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5)),
        ]),
        actions: [IconButton(onPressed: () { setState(() => _tab = 2); }, icon: const Icon(Icons.notifications_none_rounded)), const SizedBox(width: 8)],
      ),
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_tab), child: screens[_tab]))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), label: 'Vehicles'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _overview() => ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 26), children: [
        const Text('MONDAY, 17 NOVEMBER', style: TextStyle(color: leaf, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('A little peace of mind, Alex.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.8)),
        const SizedBox(height: 5),
        const Text("Here's what's happening with your vehicles.", style: TextStyle(color: Color(0xFF778278))),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('YOUR VEHICLES', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: leaf, fontWeight: FontWeight.bold))), _statusChip('Tag active')]),
          const SizedBox(height: 13),
          Container(height: 142, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFEDF2EA), borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.directions_car_filled_rounded, size: 88, color: Color(0xFF82AD8B)))),
          const SizedBox(height: 12),
          Text(_vehicles.first.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${_vehicles.first.subtitle} · ${_vehicles.first.registration}', style: const TextStyle(color: Color(0xFF78847A), fontSize: 11)),
          const SizedBox(height: 5),
          Text('QR tag · ${_vehicles.first.tagId}', style: const TextStyle(color: leaf, fontSize: 9, fontWeight: FontWeight.w600)),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('You’re in the loop.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), TextButton(onPressed: () => setState(() => _tab = 2), child: const Text('See all'))]),
          _activity(Icons.near_me_outlined, 'Someone checked in on your car', 'Parking concern · Bengaluru', '10:42 am'),
          const Divider(height: 18),
          _activity(Icons.qr_code_2_rounded, 'Your tag was scanned', 'Owner contact page opened', 'Yesterday'),
        ]))),
        const SizedBox(height: 12),
        Card(color: const Color(0xFFF0F4ED), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFDCE9D8), child: Icon(Icons.favorite_border, color: leaf)), title: const Text('Your privacy is in your hands.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: const Text('Your phone number is hidden. You choose how people can reach you.', style: TextStyle(fontSize: 11)), onTap: () => setState(() => _tab = 3))),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: _sendAlert, icon: const Icon(Icons.notifications_active_outlined), label: const Text('Preview a quick alert')),
        const SizedBox(height: 8),
        const Center(child: Text('HelpUs demo · alerts and calls are not connected', style: TextStyle(fontSize: 10, color: Color(0xFF929B92)))),
      ]);

  Widget _garage() => ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        const Text('YOUR GARAGE', style: TextStyle(color: leaf, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text('My vehicles', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Manage tags and what scanners can see.', style: TextStyle(color: Color(0xFF778278))),
        const SizedBox(height: 18),
        ..._vehicles.map((vehicle) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: pale, child: const Icon(Icons.directions_car_filled, color: leaf)), title: Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${vehicle.subtitle}\n${vehicle.registration}\nQR tag · ${vehicle.tagId}'), isThreeLine: true, trailing: _statusChip('Active')))),
        OutlinedButton.icon(onPressed: _addVehicle, icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan tag & add vehicle')),
      ]);

  Widget _alerts() => ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        const Text('YOUR NOTIFICATIONS', style: TextStyle(color: leaf, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text('Scan alerts', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Helpful updates from people who scanned your vehicle.', style: TextStyle(color: Color(0xFF778278))),
        const SizedBox(height: 18),
        _alertCard(Icons.near_me_outlined, 'Someone checked in on your car', 'Parking concern · Bengaluru, Karnataka', 'Today at 10:42 am · Honda City', '“Your headlights might still be on.”'),
        _alertCard(Icons.qr_code_2_rounded, 'Your tag was scanned', 'Owner contact page opened', 'Yesterday at 6:18 pm · Honda City', null),
        _alertCard(Icons.check_circle_outline, 'Your tag is ready to help', 'Setup completed successfully', '12 Nov · Honda City', null),
        const SizedBox(height: 8),
        const Center(child: Text('Example activity · live notifications need an account service', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF929B92)))),
      ]);

  Widget _settings() => ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        const Text('YOUR PREFERENCES', style: TextStyle(color: leaf, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.bold)),
        const SizedBox(height: 7),
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Choose how your information is shared.', style: TextStyle(color: Color(0xFF778278))),
        const SizedBox(height: 18),
        Card(child: Column(children: [
          _setting('Keep my phone number private', 'Your number is never shown on the scan page.', Switch(value: true, onChanged: (_) => _notice('Your number stays private in this demo.'))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _setting('Allow parking alerts', 'Let scanners send a quick note.', Switch(value: _parkingAlerts, onChanged: (v) => setState(() => _parkingAlerts = v))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _setting('Show vehicle details', 'Help scanners identify the right vehicle.', Switch(value: _vehicleDetails, onChanged: (v) => setState(() => _vehicleDetails = v))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _setting('Share my location', 'Only share when you choose to.', Switch(value: _location, onChanged: (v) => setState(() => _location = v))),
        ])),
        const SizedBox(height: 14),
        Card(color: const Color(0xFFF4F1E9), child: const ListTile(leading: Icon(Icons.info_outline, color: leaf), title: Text('Demo app', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Sign-in, masked calling, SMS and cloud sync need a backend service.', style: TextStyle(fontSize: 11)))),
      ]);

  Widget _setting(String title, String subtitle, Widget trailing) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ListTile(contentPadding: EdgeInsets.zero, title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 10)), trailing: trailing));

  Widget _activity(IconData icon, String title, String detail, String time) => Row(children: [
        CircleAvatar(radius: 17, backgroundColor: pale, foregroundColor: leaf, child: Icon(icon, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)), const SizedBox(height: 3), Text(detail, style: const TextStyle(color: Color(0xFF879187), fontSize: 10))])),
        Text(time, style: const TextStyle(color: Color(0xFF9AA39A), fontSize: 9)),
      ]);

  Widget _alertCard(IconData icon, String title, String detail, String time, String? message) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: pale, foregroundColor: leaf, child: Icon(icon, size: 18)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(color: Color(0xFF748075), fontSize: 10)),
                const SizedBox(height: 7),
                Text(time, style: const TextStyle(color: Color(0xFF929B92), fontSize: 9)),
                if (message != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(8)),
                    child: Text(message, style: const TextStyle(fontSize: 10, color: Color(0xFF647265))),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      );

  Widget _statusChip(String label) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(20)), child: Text('● $label', style: const TextStyle(color: leaf, fontSize: 9, fontWeight: FontWeight.w700)));
}

class Vehicle {
  const Vehicle(this.name, this.registration, this.subtitle, {this.tagId = 'HU-DEMO-001'});
  final String name;
  final String registration;
  final String subtitle;
  final String tagId;
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
    final match = RegExp(r'^(?:HELPUS:|helpus://tag/|https?://(?:www\.)?helpus\.[^/]+/tag/)([A-Za-z0-9_-]{4,64})/?$', caseSensitive: false).firstMatch(raw);
    return match?.group(1)?.toUpperCase();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.map((barcode) => barcode.rawValue).whereType<String>().firstWhere((raw) => _tagIdFrom(raw) != null, orElse: () => '');
    if (value.isEmpty) {
      if (!_handled && mounted) setState(() => _error = 'That QR code is not a HelpUs vehicle tag.');
      return;
    }
    final tagId = _tagIdFrom(value);
    if (tagId == null) return;
    _handled = true;
    Navigator.of(context).pop(tagId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan your HelpUs tag'), leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))),
        body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(children: [
          const Text('Scan first. Register second.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: forest)),
          const SizedBox(height: 6),
          const Text('Point your camera at the QR code on the HelpUs tag. Vehicle registration unlocks only after a valid tag is recognised.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF78847A), height: 1.45)),
          const SizedBox(height: 20),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Stack(fit: StackFit.expand, children: [
            MobileScanner(onDetect: _onDetect),
            IgnorePointer(child: Center(child: Container(width: 236, height: 236, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(22))))),
            Positioned(left: 14, right: 14, bottom: 14, child: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .62), borderRadius: BorderRadius.circular(10)), child: Text(_error ?? 'Keep the HelpUs QR code inside the frame', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)))),
          ]))),
          const SizedBox(height: 14),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 15, color: leaf), SizedBox(width: 6), Flexible(child: Text('A HelpUs-format QR unlocks the form. Live tag verification needs a server.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF69776B))))]),
        ]))),
      );
}
