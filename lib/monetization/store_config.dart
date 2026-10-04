import 'dart:io';

/// Store product and ad identifiers.
///
/// The repository ships Google's public test ad units so anyone can build and
/// run the app. Release builds pass the real values:
///
///   flutter build ios --dart-define-from-file=config/release.json
///
/// `config/release.json` is git-ignored; copy `config/release.example.json`.
abstract final class StoreConfig {
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
