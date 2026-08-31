import Foundation

/// Which name the new alias is built from.
enum NameSource: String, CaseIterable {
  case alias  // the name of the original alias file
  case target  // the name of the item the alias points at
}

/// User settings for Realias, kept in the app's standard preferences domain
/// (`~/Library/Preferences/io.github.mariusgrote.realias.plist`).
///
/// The file belongs to `cfprefsd`, so it is read and written only through
/// `UserDefaults` — never edited by hand. Anything unset falls back to
/// `defaults`, so there is nothing to create on first use.
struct Settings {
  var suffix: String
  var nameSource: NameSource

  static let defaults = Settings(suffix: " (this Mac)", nameSource: .alias)

  private enum Key {
    static let suffix = "suffix"
    static let nameSource = "nameSource"
  }

  /// The app's preferences. Launched from the bundle — as the Quick Action and
  /// Finder both do — that is the standard domain. A bare build in `.build`
  /// has no bundle identifier, so the domain is named explicitly to keep the
  /// command line on the same settings as the app.
  static let store: UserDefaults = {
    let domain = "io.github.mariusgrote.realias"
    if Bundle.main.bundleIdentifier == domain { return .standard }
    return UserDefaults(suiteName: domain) ?? .standard
  }()

  static func load() -> Settings {
    var settings = defaults
    if let suffix = store.string(forKey: Key.suffix) {
      settings.suffix = suffix
    }
    if let raw = store.string(forKey: Key.nameSource), let source = NameSource(rawValue: raw) {
      settings.nameSource = source
    }
    return settings
  }

  func save() {
    Settings.store.set(suffix, forKey: Key.suffix)
    Settings.store.set(nameSource.rawValue, forKey: Key.nameSource)
  }
}
