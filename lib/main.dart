import 'package:compounding_calculator/admob.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await MobileAds.instance.initialize();
    await AdService().initialize();
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
      _themeMode = (prefs.getBool('darkMode') ?? false)
          ? ThemeMode.dark
          : ThemeMode.light;
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

  late final FocusNode _principalFocus;
  late final FocusNode _rateFocus;
  late final FocusNode _timeFocus;

  String _timeUnit = 'Years';
  String _frequency = 'Annual';

  @override
  void initState() {
    super.initState();
    _principalFocus = FocusNode();
    _rateFocus = FocusNode();
    _timeFocus = FocusNode();
  }

  @override
  void dispose() {
    _principalController.dispose();
    _rateController.dispose();
    _timeController.dispose();
    _principalFocus.dispose();
    _rateFocus.dispose();
    _timeFocus.dispose();
    super.dispose();
  }

  void _calculate() {
    final isValid = _formKey.currentState!.validate();

    if (isValid) {
      FocusScope.of(context).unfocus();

      final double P = double.parse(_principalController.text);
      final double r = double.parse(_rateController.text) / 100;
      double t = double.parse(_timeController.text);
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
        'Annual': 1,
      };
      final n = freqMap[_frequency]!;
      final amount = P * pow((1 + r / n), n * t);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ResultSheet(
          amount: amount,
          currency: widget.currency,
          precision: widget.precision,
        ),
      );
    } else {
      if (_principalController.text.isEmpty ||
          double.tryParse(_principalController.text) == null ||
          double.parse(_principalController.text) < 0) {
        _principalFocus.requestFocus();
      } else if (_rateController.text.isEmpty ||
          double.tryParse(_rateController.text) == null ||
          double.parse(_rateController.text) < 0) {
        _rateFocus.requestFocus();
      } else {
        _timeFocus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compounding Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SettingsPage(onChange: widget.onSettingsChanged),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputCard(children: [
                _buildCurrencyInput(
                  controller: _principalController,
                  focusNode: _principalFocus,
                  label: 'Principal Amount',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 16),
                _buildCurrencyInput(
                  controller: _rateController,
                  focusNode: _rateFocus,
                  label: 'Annual Rate (%)',
                  icon: Icons.percent_outlined,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildCurrencyInput(
                        controller: _timeController,
                        focusNode: _timeFocus,
                        label: 'Duration',
                        icon: Icons.timelapse_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _frequency,
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.autorenew_outlined),
                  ),
                  items: const [
                    'Daily',
                    'Weekly',
                    'Monthly',
                    'Semi-Annual',
                    'Annual'
                  ]
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _frequency = v!),
                ),
              ]),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => AdService().showRewardedAd(
                    onAdDismissed: () => AdService().showInterstitialAd()),
                child: const Text('Support to keep this app free'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calculate Compound Interest'),
              ),
              const SizedBox(height: 12),
              AdService().bannerWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildCurrencyInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,10}'))
      ],
      keyboardType: TextInputType.number,
      validator: (v) {
        final val = double.tryParse(v ?? '');
        if (val == null || val < 0) return 'Enter a valid positive number';
        return null;
      },
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _precision = prefs.getInt('precision') ?? 2;
      _currency = prefs.getString('currency') ?? '\$';
    });
  }

  Future<void> _saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    widget.onChange();
  }

  Future<void> _savePrecision(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('precision', value);
    widget.onChange();
  }

  Future<void> _saveCurrency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', value);
    widget.onChange();
  }

  void _launchPrivacy() async {
    const url =
        'https://bilalparray.github.io/resume/compounding-calculator-privacy.html';
    if (await canLaunch(url)) await launch(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance',
                      style: Theme.of(context).textTheme.labelLarge),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: _darkMode,
                    onChanged: (v) {
                      setState(() => _darkMode = v);
                      _saveDarkMode(v);
                    },
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
                  Text('Formatting',
                      style: Theme.of(context).textTheme.labelLarge),
                  ListTile(
                    leading: const Icon(Icons.format_list_numbered),
                    title: const Text('Decimal Precision'),
                    trailing: DropdownButton<int>(
                      value: _precision,
                      items: List.generate(
                        7,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text('$i decimal${i == 1 ? '' : 's'}'),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() => _precision = v!);
                        _savePrecision(v!);
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text('Currency Symbol'),
                    trailing: DropdownButton<String>(
                      value: _currency,
                      items: const [
                        DropdownMenuItem(
                            value: '\$', child: Text('Dollar (\$)')),
                        DropdownMenuItem(value: '€', child: Text('Euro (€)')),
                        DropdownMenuItem(value: '£', child: Text('Pound (£)')),
                        DropdownMenuItem(value: '₹', child: Text('Rupee (₹)')),
                      ],
                      onChanged: (v) {
                        setState(() => _currency = v!);
                        _saveCurrency(v!);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _launchPrivacy,
            child: const Text('View Privacy Policy'),
          ),
        ],
      ),
    );
  }
}

class ResultSheet extends StatefulWidget {
  final double amount;
  final String currency;
  final int precision;

  const ResultSheet({
    super.key,
    required this.amount,
    required this.currency,
    required this.precision,
  });

  @override
  _ResultSheetState createState() => _ResultSheetState();
}

class _ResultSheetState extends State<ResultSheet> {
  bool _copied = false;

  String get _formattedResult {
    final pattern =
        // ignore: prefer_interpolation_to_compose_strings
        widget.precision == 0 ? '#,##0' : '#,##0.' + '0' * widget.precision;
    final format = NumberFormat(pattern, 'en_US');
    return widget.currency + format.format(widget.amount);
  }

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _formattedResult));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

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
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formattedResult,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onPressed: _copyToClipboard,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildBottomSheetAd(),
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
          adUnitId: 'ca-app-pub-3821692834936093/3250384525',
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
