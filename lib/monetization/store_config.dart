import 'dart:io';

/// Configuration for the official store builds.
///
/// Release builds pass everything from a git-ignored file:
///
///   flutter build ios --dart-define-from-file=config/release.json
///
/// (copy `config/release.example.json`). The defaults are Google's public test
/// ad units, so a store build can be tried locally with
/// `--dart-define=STORE_BUILD=true`.
abstract final class StoreConfig {
  /// Ads and the supporter purchase exist only in the official store builds
  /// (`"STORE_BUILD": true` in config/release.json). Builds from source leave
  /// them off: no ads SDK start, no store queries, no purchase UI.
  static const enabled = bool.fromEnvironment('STORE_BUILD');

  /// The one-time "支持者" purchase. App Store (one product shared by iOS and
  /// macOS through universal purchase) and Google Play use this product ID.
  static const supporterProductId =
      String.fromEnvironment('SUPPORTER_PRODUCT_ID', defaultValue: 'supporter');

  /// Microsoft Store durable add-on Store ID (e.g. "9NBLGGH4R315"), shown in
  /// Partner Center. Empty → purchases are unavailable on Windows.
  static const msStoreAddOnId = String.fromEnvironment('MS_STORE_ADDON_ID');

  static const _androidTestBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _iosTestBanner = 'ca-app-pub-3940256099942544/2435281174';

  /// Adaptive banner ad unit for the bottom slot.
  static String get bannerAdUnitId => Platform.isAndroid
      ? const String.fromEnvironment('ADMOB_BANNER_ANDROID', defaultValue: _androidTestBanner)
      : const String.fromEnvironment('ADMOB_BANNER_IOS', defaultValue: _iosTestBanner);
}
