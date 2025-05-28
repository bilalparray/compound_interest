import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Centralized URL launcher helper
  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
  }

  void _launchPrivacy() {
    const privacyUrl =
        'https://bilalparray.github.io/resume/compounding-calculator-privacy.html';
    _launchUrl(privacyUrl);
  }

  Future<void> _shareApp() async {
    const playStoreLink =
        'https://play.google.com/store/apps/details?id=com.bilalparray07.compoundingcalculator';
    await Share.share(
      'Check out this Compounding Calculator app:\n$playStoreLink',
      subject: 'Compounding Calculator',
    );
  }

  void _contactViaEmail() {
    // Build the mailto: URL string manually
    const emailAddress = 'parraybilal34@gmail.com';
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      query: Uri.encodeFull(
        'subject=Feedback for Compounding Calculator&body=',
      ),
    ).toString();

    _launchUrl(mailtoUri);
  }

  void _checkForUpdates() {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.bilalparray07.compoundingcalculator';
    _launchUrl(playStoreUrl);
  }

  void _leaveReview() {
    final reviewUrl = Uri(
      scheme: 'https',
      host: 'play.google.com',
      path: '/store/apps/details',
      queryParameters: {
        'id': 'com.bilalparray07.compoundingcalculator',
        'action': 'write-review',
      },
    ).toString();

    _launchUrl(reviewUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ───────────────────────────────────────────────────────────────
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

          // ───────────────────────────────────────────────────────────────
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

          // ───────────────────────────────────────────────────────────────
          OutlinedButton(
            onPressed: _launchPrivacy,
            child: const Text('View Privacy Policy'),
          ),

          const SizedBox(height: 24),

          // ───────────────────────────────────────────────────────────────
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share App'),
                  subtitle: const Text('Tell friends about this app'),
                  onTap: _shareApp,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Contact Developer'),
                  subtitle: const Text('parraybilal34@gmail.com'),
                  onTap: _contactViaEmail,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('Check for Updates'),
                  subtitle: const Text('Go to Play Store'),
                  onTap: _checkForUpdates,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.rate_review_outlined),
                  title: const Text('Feedback & Review'),
                  subtitle: const Text('Leave a review on Play Store'),
                  onTap: _leaveReview,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
