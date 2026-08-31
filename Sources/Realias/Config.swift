import Foundation

/// Which name the new alias is built from.
enum NameSource: String, CaseIterable {
  case alias  // the name of the original alias file
  case target  // the name of the item the alias points at
}

/// User settings for Realias, stored as JSON next to the app's data.
///
/// The file is created with the defaults on first use, so it is always there
/// to edit.
struct Settings {
  var suffix: String
  var nameSource: NameSource

  static let defaults = Settings(suffix: " (this Mac)", nameSource: .alias)

  static let directory = (NSHomeDirectory() as NSString)
    .appendingPathComponent("Library/Application Support/Realias")
  static let path = (directory as NSString).appendingPathComponent("config.json")

  private var json: [String: Any] {
    ["suffix": suffix, "name_source": nameSource.rawValue]
  }

  private func write() throws {
    try FileManager.default.createDirectory(
      atPath: Settings.directory,
      withIntermediateDirectories: true)
    var data = try JSONSerialization.data(
      withJSONObject: json,
      options: [.prettyPrinted, .sortedKeys])
    data.append(0x0A)
    try data.write(to: URL(fileURLWithPath: Settings.path))
  }

  static func load() throws -> Settings {
    guard FileManager.default.fileExists(atPath: path) else {
      try? defaults.write()
      return defaults
    }

    let data: Data
    do {
      data = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
      throw ConfigError("could not read \(path):\n\(error.localizedDescription)")
    }

    let parsed: Any
    do {
      parsed = try JSONSerialization.jsonObject(with: data)
    } catch {
      throw ConfigError("\(path) is not valid JSON:\n\(error.localizedDescription)")
    }
    guard let stored = parsed as? [String: Any] else {
      throw ConfigError("\(path) must contain a JSON object")
    }

    var settings = defaults
    if let suffix = stored["suffix"] {
      guard let text = suffix as? String else {
        throw ConfigError("\"suffix\" must be text")
      }
      settings.suffix = text
    }
    if let source = stored["name_source"] {
      guard let text = source as? String, let value = NameSource(rawValue: text) else {
        throw ConfigError(
          "\"name_source\" must be one of: "
            + NameSource.allCases.map(\.rawValue).joined(separator: ", "))
      }
      settings.nameSource = value
    }
    return settings
  }
}
