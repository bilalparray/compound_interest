import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const String _bannerAdUnitId = 'ca-app-pub-3821692834936093/3250384525';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  int _precision = 2;
  String _currency = '\$';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = (prefs.getBool('darkMode')) ?? false ? ThemeMode.dark : ThemeMode.light;
      _precision = prefs.getInt('precision') ?? 2;
      _currency = prefs.getString('currency') ?? '\$';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compounding Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: HomePage(
        onSettingsChanged: _loadSettings,
        precision: _precision,
        currency: _currency,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final int precision;
  final String currency;

  const HomePage({
    super.key,
    required this.onSettingsChanged,
    required this.precision,
    required this.currency,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  String _timeUnit = 'Years';
  String _frequency = 'Annual';
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _timeController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final double P = double.parse(_principalController.text);
    final double r = double.parse(_rateController.text) / 100;
    final double tInput = double.parse(_timeController.text);
    double t = tInput;
    switch (_timeUnit) {
      case 'Months':
        t /= 12;
        break;
      case 'Weeks':
        t /= 52;
        break;
      case 'Days':
        t /= 365;
        break;
    }
    final freqMap = {
      'Daily': 365,
      'Weekly': 52,
      'Monthly': 12,
      'Semi-Annual': 2,
      'Annual': 1
    };
    final n = freqMap[_frequency]!;
    final amount = P * pow((1 + r / n), n * t);
    final result = amount.toStringAsFixed(widget.precision);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ResultSheet(
        result: result,
        currency: widget.currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compounding Calculator'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(onChange: widget.onSettingsChanged),
                ),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(6),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputCard(
                children: [
                  _buildCurrencyInput(
                    controller: _principalController,
                    label: 'Principal Amount',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildCurrencyInput(
                    controller: _rateController,
                    label: 'Annual Interest Rate (%)',
                    icon: Icons.percent_outlined,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCurrencyInput(
                          controller: _timeController,
                          label: 'Investment Duration',
                          icon: Icons.timelapse_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _timeUnit,
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const ['Years', 'Months', 'Weeks', 'Days']
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _timeUnit = v!),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: InputDecoration(
                      labelText: 'Compounding Frequency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.autorenew_outlined),
                    ),
                    items: const ['Daily', 'Weekly', 'Monthly', 'Semi-Annual', 'Annual']
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _frequency = v!),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loadAd,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Load Ad"),
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calculate Compound Interest'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_isAdLoaded && _bannerAd != null)
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  height: _bannerAd!.size.height.toDouble(),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildCurrencyInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,10}')),
      ],
      keyboardType: TextInputType.number,
      validator: (v) {
        final val = double.tryParse(v ?? '');
        if (val == null || val < 0) return 'Please enter a valid positive number';
        return null;
      },
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

class ResultSheet extends StatelessWidget {
  final String result;
  final String currency;

  const ResultSheet({super.key, required this.result, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Future Value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$currency$result',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          _buildBottomSheetAd(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetAd() {
    return SizedBox(
      height: AdSize.banner.height.toDouble(),
      child: AdWidget(
        ad: BannerAd(
          adUnitId: _bannerAdUnitId,
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (ad) => debugPrint('Banner ad loaded'),
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
              debugPrint('Banner ad failed to load: $error');
            },
          ),
        )..load(),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final VoidCallback onChange;
  const SettingsPage({super.key, required this.onChange});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  int _precision = 2;
  String _currency = '\$';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = p.getBool('darkMode') ?? false;
      _precision = p.getInt('precision') ?? 2;
      _currency = p.getString('currency') ?? '\$';
    });
  }

  Future<void> _saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('darkMode', _darkMode);
    await p.setInt('precision', _precision);
    await p.setString('currency', _currency);
    widget.onChange();
  }

  void _launchPrivacy() async {
    const url = 'https://your-privacy-policy-url.com';
    if (await canLaunch(url)) await launch(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APPEARANCE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: _darkMode,
                    onChanged: (v) => setState(() {
                      _darkMode = v;
                      _saveSettings();
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FORMATTING',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.format_list_numbered),
                    title: const Text('Decimal Precision'),
                    trailing: DropdownButton<int>(
                      value: _precision,
                      items: List.generate(7, (i) => DropdownMenuItem(
                        value: i,
                        child: Text('$i decimal${i == 1 ? '' : 's'}'),
                      )),
                      onChanged: (v) => setState(() {
                        _precision = v!;
                        _saveSettings();
                      }),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text('Currency Symbol'),
                    trailing: DropdownButton<String>(
                      value: _currency,
                      items: const [
                        DropdownMenuItem(value: '\$', child: Text('Dollar (\$)')),
                        DropdownMenuItem(value: '€', child: Text('Euro (€)')),
                        DropdownMenuItem(value: '£', child: Text('Pound (£)')),
                        DropdownMenuItem(value: '₹', child: Text('Rupee (₹)')),
                      ],
                      onChanged: (v) => setState(() {
                        _currency = v!;
                        _saveSettings();
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _launchPrivacy,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('View Privacy Policy'),
          ),
        ],
      ),
    );
  }
}