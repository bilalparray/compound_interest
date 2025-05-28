// lib/main.dart

import 'package:compounding_calculator/chart.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:compounding_calculator/admob.dart';
import 'package:compounding_calculator/settings.dart';

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
      debugShowCheckedModeBanner: false,
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
      final double rate = double.parse(_rateController.text);
      if (rate > 1000) {
        _rateFocus.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annual rate cannot exceed 1000%')),
        );
        return;
      }

      FocusScope.of(context).unfocus();

      final double P = double.parse(_principalController.text);
      final double rPercent = rate; // still “in percent”
      final double rawTime = double.parse(_timeController.text); // e.g. “2.5”

      // We’ll calculate “t in years” here just to compute the final amount if needed.
      double tInYears = rawTime;
      switch (_timeUnit) {
        case 'Months':
          tInYears /= 12;
          break;
        case 'Weeks':
          tInYears /= 52;
          break;
        case 'Days':
          tInYears /= 365;
          break;
        // 'Years' => leave tInYears as is
      }

      final freqMap = {
        'Daily': 365,
        'Weekly': 52,
        'Monthly': 12,
        'Semi-Annual': 2,
        'Annual': 1,
      };
      final int n = freqMap[_frequency]!;

      // We compute A here just so we can show a SnackBar or do anything else if needed.
      // But bottom sheet is gone—so we’ll go straight to ChartPage.
      final double A = P * pow((1 + (rPercent / 100) / n), n * tInYears);

      AdService().showRewardedAd(
        onAdDismissed: () {},
      );
      // → Instead of showing a bottom sheet, push to ChartPage:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChartPage(
            principal: P,
            annualRatePercent: rPercent,
            timeValue: rawTime,
            timeUnit: _timeUnit,
            frequencyStr: _frequency,
            currency: widget.currency,
            precision: widget.precision,
          ),
        ),
      );
    } else {
      // existing error‐focus logic:
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
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val < 0 || val > 1000) {
                      return 'Enter a valid rate between 0 and 1000';
                    }
                    return null;
                  },
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
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => AdService().showRewardedAd(
                  onAdDismissed: () => AdService().showInterstitialAd(),
                ),
                icon: const Icon(Icons.volunteer_activism_rounded),
                label: const Text('Support to keep this app free'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_outlined, size: 24),
                label: const Text('Calculate Compound Interest'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildCurrencyInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
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
      validator: validator ??
          (v) {
            final val = double.tryParse(v ?? '');
            if (val == null || val < 0) return 'Enter a valid positive number';
            return null;
          },
    );
  }
}
