import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const String _bannerAdUnitId = 'ca-app-pub-3821692834936093/3250384525';

class ResultSheet extends StatefulWidget {
  final String result;
  final String currency;
  final int precision;

  const ResultSheet({
    super.key,
    required this.result,
    required this.currency,
    required this.precision,
  });

  @override
  _ResultSheetState createState() => _ResultSheetState();
}

class _ResultSheetState extends State<ResultSheet> {
  bool _copied = false;

  String get _formattedResult {
    final value = double.tryParse(widget.result) ?? 0.0;
    return value.toStringAsFixed(widget.precision);
  }

  void _copyToClipboard() async {
    final text = '${widget.currency}$_formattedResult';
    await Clipboard.setData(ClipboardData(text: text));
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
                  '${widget.currency}$_formattedResult',
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
