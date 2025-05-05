import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Singleton pattern
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Ad instances
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // Ad loading states
  bool _isLoadingInterstitial = false;
  bool _isLoadingRewarded = false;

  // Initialize all ads
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  // ======================== BANNER ADS ========================
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3821692834936093/3250384525',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => print('Banner ad loaded'),
        onAdFailedToLoad: (ad, err) {
          print('Banner failed: ${err.message}');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  Widget getBannerAd() {
    return _bannerAd != null
        ? SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          )
        : const SizedBox();
  }
  Widget get bannerWidget => _bannerAd != null
    ? SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      )
    : const SizedBox();

  // ===================== INTERSTITIAL ADS =====================
  void _loadInterstitialAd() {
    if (_isLoadingInterstitial) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3821692834936093/2221650256',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (err) {
          print('Interstitial failed: ${err.message}');
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  void showInterstitialAd({
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) {
    if (_interstitialAd == null) {
      onAdFailed?.call();
      _loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onAdDismissed?.call();
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        onAdFailed?.call();
        _loadInterstitialAd();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null; // Prevent duplicate shows
  }

  // ======================= REWARDED ADS =======================
  void _loadRewardedAd() {
    if (_isLoadingRewarded) return;
    _isLoadingRewarded = true;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3821692834936093/7668599813',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
        },
        onAdFailedToLoad: (err) {
          print('Rewarded failed: ${err.message}');
          _isLoadingRewarded = false;
        },
      ),
    );
  }

  Future<void> showRewardedAd({
    required VoidCallback onAdDismissed,
    VoidCallback? onRewardEarned,
    VoidCallback? onAdFailed,
  }) async {
    if (_rewardedAd == null) {
      onAdFailed?.call();
      _loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onAdDismissed(); // Always called when ad closes
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        onAdFailed?.call();
        _loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewardEarned?.call(); // Optional reward handling
      },
    );
    _rewardedAd = null; // Prevent duplicate shows
  }

  // ====================== LIFECYCLE MANAGEMENT ======================
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}