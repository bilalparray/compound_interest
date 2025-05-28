import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
