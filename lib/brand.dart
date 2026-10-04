/// The publisher. MD Viewer keeps its own name and icon; Easier Life shows up
/// as the maker (About, welcome screen, copyright, store listings).
abstract final class Brand {
  static const name = 'Easier Life';
  static const nameZh = '簡單點生活';
  static const copyright = '© 2026 Easier Life';
  static const logoAsset = 'assets/images/easier_life.png';

  /// Brand website. Empty until the new site is live; once set, the
  /// "Easier Life 出品" credits become links.
  static const website = '';
}
