import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/file_service.dart';
import 'store_config.dart';

/// AdMob on iOS/Android: asks for consent where the law requires it (EEA,
/// UK, …) through Google's UMP SDK, then initialises the ads SDK.
/// Supporters never reach this, so the SDK isn't even started for them.
class AdsController extends ChangeNotifier {
  bool _started = false;

  /// Consent flow finished and ads may be requested.
  bool ready = false;

  /// Users in regulated regions must be able to change their choice later.
  bool privacyOptionsRequired = false;

  Future<void> start() async {
    if (_started || !isMobilePlatform) return;
    _started = true;
    final consent = ConsentInformation.instance;
    final updated = Completer<void>();
    consent.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) debugPrint('Consent form: ${error.message}');
        });
        updated.complete();
      },
      (error) {
        // Offline or not configured: fall back to the stored consent state.
        debugPrint('Consent info update failed: ${error.message}');
        updated.complete();
      },
    );
    await updated.future;
    privacyOptionsRequired =
        await consent.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
    if (await consent.canRequestAds()) {
      await MobileAds.instance.initialize();
      ready = true;
    }
    notifyListeners();
  }

  Future<void> showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) debugPrint('Privacy options: ${error.message}');
      });
}

/// Anchored adaptive banner sized to the available width. Takes no space
/// until an ad has loaded, and reloads when the width changes (rotation,
/// split view).
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int _width = 0;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _load(int width) async {
    _width = width;
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null || width != _width) return;
    final ad = BannerAd(
      adUnitId: StoreConfig.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed: ${error.message}');
          ad.dispose();
          if (mounted && identical(_ad, ad)) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.truncate();
      if (width != _width) {
        // Defer: loading calls setState.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && width != _width) _load(width);
        });
      }
      final ad = _ad;
      if (ad == null || !_loaded) return const SizedBox(width: double.infinity);
      return SizedBox(
        width: double.infinity,
        height: ad.size.height.toDouble(),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      );
    });
  }
}
