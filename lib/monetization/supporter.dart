import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windows_store_iap/windows_store_iap.dart';

import 'store_config.dart';

/// "支持者" (supporter): a one-time purchase that removes the bottom ad on
/// phones/tablets and the support bar on desktop. It unlocks no features —
/// everything else in the app is free.
class SupporterController extends ChangeNotifier {
  SupporterController(this._prefs) : isSupporter = _prefs.getBool(_kSupporter) ?? false;

  static const _kSupporter = 'isSupporter';

  final SharedPreferences _prefs;
  _StoreBackend? _store;

  bool isSupporter;

  /// Localised price from the store (e.g. "NT$30"); null until loaded.
  String? price;

  /// The store answered and the product exists.
  bool available = false;

  /// A purchase or restore is in progress.
  bool busy = false;

  /// The desktop support bar was closed for this session.
  bool barDismissed = false;

  /// Shows a short message to the user (wired to a SnackBar).
  void Function(String message)? onMessage;

  Future<void> init() async {
    final store = _store = _StoreBackend.forPlatform(this);
    if (store == null) return;
    try {
      available = await store.init();
      price = store.price;
    } catch (e) {
      available = false;
      debugPrint('Store unavailable: $e');
    }
    notifyListeners();
  }

  Future<void> buy() async {
    final store = _store;
    if (store == null || !available) {
      _say('目前無法連線到商店，請稍後再試');
      return;
    }
    _setBusy(true);
    try {
      await store.buy();
    } catch (e) {
      _say('購買沒有完成：$e');
      _setBusy(false);
    }
  }

  Future<void> restore() async {
    final store = _store;
    if (store == null || !available) {
      _say('目前無法連線到商店，請稍後再試');
      return;
    }
    _setBusy(true);
    try {
      await store.restore();
      // App Store / Play deliver restored purchases asynchronously.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!isSupporter) _say('沒有找到可以恢復的購買紀錄');
    } catch (e) {
      _say('恢復購買失敗：$e');
    } finally {
      _setBusy(false);
    }
  }

  void dismissBar() {
    barDismissed = true;
    notifyListeners();
  }

  void _grant({required bool announce}) {
    final wasSupporter = isSupporter;
    isSupporter = true;
    busy = false;
    _prefs.setBool(_kSupporter, true);
    notifyListeners();
    if (announce && !wasSupporter) _say('謝謝你的支持！');
  }

  void _setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  void _say(String message) => onMessage?.call(message);
}

abstract class _StoreBackend {
  _StoreBackend(this.owner);

  final SupporterController owner;

  static _StoreBackend? forPlatform(SupporterController owner) {
    if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) return _AppStoreBackend(owner);
    if (Platform.isWindows && StoreConfig.msStoreAddOnId.isNotEmpty) return _MicrosoftStoreBackend(owner);
    return null;
  }

  String? get price;

  /// Loads the product and silently checks for an existing purchase.
  Future<bool> init();

  Future<void> buy();

  Future<void> restore();
}

/// App Store (iOS + macOS, StoreKit 2) and Google Play via in_app_purchase.
class _AppStoreBackend extends _StoreBackend {
  _AppStoreBackend(super.owner);

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  bool _userRestore = false;

  @override
  String? get price => _product?.price;

  @override
  Future<bool> init() async {
    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      debugPrint('Purchase stream error: $e');
    });
    if (!await _iap.isAvailable()) return false;
    final response = await _iap.queryProductDetails({StoreConfig.supporterProductId});
    if (response.productDetails.isEmpty) {
      debugPrint('Product not found: ${response.notFoundIDs} ${response.error}');
      return false;
    }
    _product = response.productDetails.first;
    // StoreKit 2 reads current entitlements and Play queries owned items;
    // neither prompts the user, so this is safe on every launch.
    await _iap.restorePurchases();
    return true;
  }

  @override
  Future<void> buy() async {
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: _product!));
  }

  @override
  Future<void> restore() async {
    _userRestore = true;
    try {
      await _iap.restorePurchases();
    } finally {
      Future<void>.delayed(const Duration(seconds: 3), () => _userRestore = false);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == StoreConfig.supporterProductId) {
        switch (p.status) {
          case PurchaseStatus.purchased:
            owner._grant(announce: true);
          case PurchaseStatus.restored:
            owner._grant(announce: _userRestore);
          case PurchaseStatus.error:
            owner._say('購買沒有完成：${p.error?.message ?? '未知錯誤'}');
            owner._setBusy(false);
          case PurchaseStatus.canceled:
            owner._setBusy(false);
          case PurchaseStatus.pending:
            break;
        }
      }
      // Acknowledge/finish, or Play refunds the purchase after three days.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }
}

/// Microsoft Store durable add-on. Works only in the MSIX build installed
/// from (or associated with) the Store.
class _MicrosoftStoreBackend extends _StoreBackend {
  _MicrosoftStoreBackend(super.owner);

  final _iap = WindowsIap();
  String? _price;

  String get _id => StoreConfig.msStoreAddOnId;

  @override
  String? get price => _price;

  @override
  Future<bool> init() async {
    final products = await _iap.getProducts();
    _price = products.where((p) => p.storeId == _id).firstOrNull?.price;
    if (await _iap.checkPurchase(storeId: _id)) owner._grant(announce: false);
    return true;
  }

  @override
  Future<void> buy() async {
    final status = await _iap.makePurchase(_id);
    switch (status) {
      case StorePurchaseStatus.succeeded:
      case StorePurchaseStatus.alreadyPurchased:
        owner._grant(announce: true);
      case StorePurchaseStatus.notPurchased:
        owner._setBusy(false);
      case StorePurchaseStatus.networkError:
      case StorePurchaseStatus.serverError:
      case null:
        owner._say('Microsoft Store 暫時無法完成購買，請稍後再試');
        owner._setBusy(false);
    }
  }

  @override
  Future<void> restore() async {
    if (await _iap.checkPurchase(storeId: _id)) owner._grant(announce: true);
  }
}
