import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService extends ChangeNotifier {
  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  // Use test IDs for development; replace with your own for production.
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/5224354917';
    return 'ca-app-pub-3940256099942544/1712485313';
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    return 'ca-app-pub-3940256099942544/2934735716';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/1033173712';
    return 'ca-app-pub-3940256099942544/4411468910';
  }

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isRewardedAdLoaded = false;
  bool _isInterstitialLoaded = false;

  bool get isRewardedAdLoaded => _isRewardedAdLoaded;

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          notifyListeners();
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedAdLoaded = false;
              notifyListeners();
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _isRewardedAdLoaded = false;
          notifyListeners();
          // Retry after a delay so ad can load later
          Future.delayed(const Duration(seconds: 3), () {
            if (!_isRewardedAdLoaded) loadRewardedAd();
          });
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (!_isRewardedAdLoaded || _rewardedAd == null) {
      loadRewardedAd();
      notifyListeners();
      return false;
    }
    final completer = Completer<bool>();
    _rewardedAd!.show(onUserEarnedReward: (_, __) {
      if (!completer.isCompleted) completer.complete(true);
    });
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isRewardedAdLoaded = false;
        notifyListeners();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    return completer.future;
  }

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (_) => _isInterstitialLoaded = false,
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (!_isInterstitialLoaded || _interstitialAd == null) {
      loadInterstitialAd();
      return;
    }
    _interstitialAd!.show();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
