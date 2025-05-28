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
    _loadBannerAd();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  // ======================== BANNER ADS ========================
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3821692834936093/3250384525',
      // adUnitId: 'ca-app-pub-3940256099942544/9214589741', //test id
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, err) {
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

  Widget getBannerAdWidget() {
    final banner = BannerAd(
      adUnitId: 'ca-app-pub-3821692834936093/3250384525',
      // adUnitId: 'ca-app-pub-3940256099942544/9214589741', // test ad unit
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();

    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
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
          _isLoadingRewarded = false;
        },
      ),
    );
  }

  Future<void> showRewardedAd({
    required VoidCallback? onAdDismissed,
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
        onAdDismissed!(); // Always called when ad closes
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
