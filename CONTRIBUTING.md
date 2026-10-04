# 貢獻指南

謝謝你願意幫忙！

## 授權

送出的貢獻（PR、patch）依 [Apache License 2.0](LICENSE) 第 5 條，以同一授權納入專案，不需要另外簽署 CLA。
建議用 `git commit -s` 加上 [DCO](https://developercertificate.org/) 簽名，表示你有權提交這些程式碼。

## 開發

```bash
flutter pub get
flutter analyze
flutter test
```

送 PR 前請確認 `flutter analyze` 沒有問題、`flutter test` 全部通過。

## 請不要修改

- 名稱與圖示相關檔案（見 [TRADEMARKS.md](TRADEMARKS.md)）
- 商店與廣告設定（`lib/monetization/store_config.dart` 的預設值是 Google 公開的測試 ID，正式 ID 不會放進 repo）
