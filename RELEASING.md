# 上架與商店版（維護者筆記）

這份文件給維護者看：如何建置在各商店上架的官方版本。一般使用或自行編譯不需要看這份。

商店版 = 原始碼 + `config/release.json`（`"STORE_BUILD": true`）。沒有這個開關時，廣告、支持者購買、商店連線全部關閉。

## 支持者（商店版）

商店版所有功能都免費。底部有一條：手機／平板是 AdMob 橫幅，電腦版是「成為支持者」提示列（可暫時關閉）。

一次買斷 **支持者**（建議 US$0.99）就會移除那一條，不會多出任何功能。

| 商店 | 購買方式 | 備註 |
| --- | --- | --- |
| App Store（iOS + macOS） | 同一個非消耗型內購 `supporter` | 用 Universal Purchase，買一次 iPhone／iPad／Mac 通用 |
| Google Play | 應用程式內產品 `supporter` | |
| Microsoft Store | 耐用型附加元件 | Store ID 填到 `MS_STORE_ADDON_ID` |


## 本機試跑商店版

用 Google 的測試廣告 ID 與尚未建立的商品，看看畫面：

```bash
flutter run --dart-define=STORE_BUILD=true
```

## 上架設定

正式 ID 都不放進 repo（已列在 `.gitignore`）：

| 檔案 | 內容 |
| --- | --- |
| `config/release.json` | 複製 `config/release.example.json`：內購商品 ID、Microsoft Store 附加元件 ID、AdMob 橫幅廣告單元 ID |
| `android/admob.properties` | `appId=ca-app-pub-…~…`（AdMob Android App ID） |
| `ios/Flutter/Secrets.xcconfig` | `ADMOB_APP_ID = ca-app-pub-…~…`（AdMob iOS App ID） |

正式版建置都要帶上設定檔：

```bash
flutter build ipa --dart-define-from-file=config/release.json
```
```bash
flutter build macos --dart-define-from-file=config/release.json
```
```bash
flutter build appbundle --dart-define-from-file=config/release.json
```

Windows（要在 Windows 上執行）：先填好 `pubspec.yaml` 裡 `msix_config` 的發行者資訊，再：

```bash
flutter build windows --dart-define-from-file=config/release.json
```
```bash
dart run msix:create
```

各商店後台要做的事：

- **App Store Connect**：iOS 和 macOS 放在**同一個 App 紀錄**（Bundle ID 相同）以啟用 Universal Purchase；建立非消耗型內購 `supporter`；隱私標籤要申報廣告相關資料（iOS 有 AdMob）。Mac 版已開啟 App Sandbox。
- **Google Play**：建立應用程式內產品 `supporter`；填寫資料安全表單；新的個人開發者帳號要先完成 12 人、14 天的封閉測試。
- **Microsoft Partner Center**：保留名稱、建立耐用型附加元件，把 Store ID 填進 `config/release.json`，把產品身分識別填進 `msix_config`。內購只在從 Store 安裝（或與 Store 關聯）的 MSIX 版本有效。
- **AdMob**：建立 iOS／Android 兩個應用程式與橫幅廣告單元；在「隱私權與訊息」設定 GDPR 同意訊息（App 用 UMP 顯示）；在開發者網站放 `app-ads.txt`。
- 所有商店都需要**隱私權政策網址**；開發者名稱填「Easier Life」（Apple 個人帳號只能顯示本名，要顯示品牌名需以公司／行號註冊組織帳號）。
- **品牌網站**：隱私權政策與 `app-ads.txt` 放在 Easier Life 的網站上；`app-ads.txt` 必須在網域根目錄（例如 `https://easier.tw/app-ads.txt`）。網站上線後，把網址填進 `lib/brand.dart` 的 `Brand.website`，App 裡的「Easier Life 出品」就會變成連結。

測試內購：iOS／macOS 用 App Store Connect 的沙盒帳號，Android 用 Play Console 的授權測試人員。


## 識別資訊

- Bundle ID／Application ID：`tw.easier.mdviewer`（iOS 與 macOS 必須相同才能共用購買；第一次上架後不能改）
- 開發者／發行者名稱：Easier Life
- 隱私權政策：`PRIVACY.md`（網站上線後放一份到 Easier Life 網站，商店填網站網址）
