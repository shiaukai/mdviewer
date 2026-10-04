<p align="center"><img src="assets/icon/icon.png" width="128" alt="MD Viewer"></p>

# MD Viewer

一個用 Flutter 寫的 Markdown 閱讀器，支援 macOS、Windows、iOS、Android。由 **Easier Life 簡單點生活** 出品。

## 版面配置

版面依 **視窗寬度** 決定（`lib/layout/breakpoints.dart`），旋轉、調整視窗大小或進入 iPad 分割畫面時會即時切換，並保留閱讀位置。

| 模式 | 條件 | 畫面 |
| --- | --- | --- |
| `mobile` | 寬 < 600（且不是寬 ≥ 480 的橫向） | 上方 AppBar、左側滑出檔案清單、底部大綱 |
| `medium` | 寬 ≥ 600，或橫向且寬 ≥ 480 | 電腦版：工具列＋可拖曳寬度的側邊欄＋內文，大綱從右側滑出 |
| `wide` | 寬 ≥ 1000 | 電腦版：側邊欄＋內文＋固定在右側的大綱 |

- 手機直向 → `mobile`；手機轉橫向 → `medium`（電腦版）
- 平板直向／橫向都夠寬 → 直接是電腦版
- 電腦視窗拉窄到 600 以下 → 也會變成手機版

## 功能

- GitHub 風格 Markdown：表格、任務清單、刪除線、自動連結、`> [!NOTE]` 提示區塊
- 程式碼高亮、語言標籤、一鍵複製
- 圖片：網路圖、相對路徑、data URI、SVG（含 shields.io 徽章）；點圖可放大
- 常見 README HTML：`<p align="center">`、`<img>`、`<br>`、`<details>`、`<kbd>`，HTML 註解會隱藏
- YAML front matter 顯示成程式碼區塊
- 大綱：點擊跳轉、捲動時自動標示目前章節
- 文件內錨點 `[x](#標題)`、相對連結到其他 `.md`（可帶 `#錨點`）
- 淺色／深色／跟隨系統、文字大小 80%–160%
- 記住最近開啟的檔案，重開 App 會回到上次的文件
- 電腦版：開啟資料夾（側邊欄樹狀列出所有 `.md`）、拖曳檔案或資料夾、外部編輯存檔後自動重新載入、鍵盤快捷鍵（⌘/Ctrl + O、⇧O、R、B、+、-、0、,）
- 系統「打開方式」：macOS Finder、iOS「檔案」分享、Android「開啟方式」、Windows（Store 版會關聯 `.md`）

## 免費使用與「支持者」

所有功能都免費。底部有一條：手機／平板是 AdMob 橫幅，電腦版是「成為支持者」提示列（可暫時關閉）。

一次買斷 **支持者**（建議 US$0.99）就會移除那一條，不會多出任何功能。

| 商店 | 購買方式 | 備註 |
| --- | --- | --- |
| App Store（iOS + macOS） | 同一個非消耗型內購 `supporter` | 用 Universal Purchase，買一次 iPhone／iPad／Mac 通用 |
| Google Play | 應用程式內產品 `supporter` | |
| Microsoft Store | 耐用型附加元件 | Store ID 填到 `MS_STORE_ADDON_ID` |

## 開發

```bash
flutter pub get
flutter test
flutter run -d macos      # 或 windows / iPhone 模擬器 / Android 裝置
```

把測試用的 `.md` 放進 iOS 模擬器（出現在「檔案」App › 我的 iPhone）：

```bash
tool/sim_add_files.sh 你的檔案.md
```

沒有任何設定也能直接執行：廣告用的是 Google 公開的測試 ID（會顯示 "Test mode"），內購在商品建立前會顯示「目前無法連線到商店」。

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

## 專案結構

```
lib/
  main.dart                 啟動、接收系統傳入的檔案
  app.dart                  MaterialApp、主題、語系
  layout/breakpoints.dart   手機／電腦版的寬度判斷
  state/                    AppState（檔案、設定、最近開啟）、ViewerController（跳轉、目前章節）
  services/                 檔案讀取／選擇／監看、資料夾掃描、原生 channel
  models/md_document.dart   文件、標題解析（GitHub slug）
  markdown/                 樣式、程式碼區塊、圖片、HTML 轉換、提示區塊
  ui/                       HomePage、DesktopShell、MobileShell、閱讀器、大綱、側邊欄、底部支持列
  monetization/             支持者購買（App Store／Play／Microsoft Store）、AdMob 與同意視窗、商店 ID
```

## 平台備註

- **macOS**：開啟 App Sandbox（Mac App Store 要求）。使用者開過的檔案與資料夾會存成 security-scoped bookmark，重開後仍可讀取。只開單一檔案時，同資料夾的圖片需要授權資料夾才看得到——App 會顯示「授權資料夾」提示；用「開啟資料夾」開的文件不受影響。
- **iOS / Android**：開啟的檔案會複製一份到 App 內（「我的檔案」），之後不需要原始檔也能再開。因為只複製單一檔案，文件內的 **相對路徑圖片與連結在手機上無法使用**（網路圖片正常）。
- **Windows**：用命令列參數開檔；Store 的 MSIX 版本會註冊 `.md` 等副檔名的「開啟方式」。
- Bundle ID／Application ID 是 `tw.easier.mdviewer`（iOS 與 macOS 必須相同才能共用購買；第一次上架後就不能再改）。

## Logo 與 App 圖示

Logo 定義在 `tool/generate_icons.dart`（SVG），修改後重新產生各平台圖示：

```bash
flutter test tool/generate_icons.dart
dart run flutter_launcher_icons
```

## 授權

程式碼以 [Apache License 2.0](LICENSE) 開源，第三方套件授權可在 App 的「設定 › 開源授權」查看。

「MD Viewer」名稱與 Logo 不在授權範圍內，發佈修改版請換成自己的名稱與圖示，詳見 [TRADEMARKS.md](TRADEMARKS.md)。貢獻方式見 [CONTRIBUTING.md](CONTRIBUTING.md)。
