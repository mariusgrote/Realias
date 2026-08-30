import Foundation

/// Turn an alias made on another Mac into one that works on this Mac.
///
/// Reads the foreign alias without resolving it, rewrites the OneDrive prefix
/// to this machine's, and drops a new alias next to the original. The original
/// file is never touched, so it keeps working on the Mac that created it.
enum Localize {
  /// Pick a free name next to `original`, per the configured name source.
  static func newAliasPath(original: String, target: String, settings: Settings) -> String {
    let folder = (original as NSString).deletingLastPathComponent
    let source = settings.nameSource == .alias ? original : target
    let name = (source as NSString).lastPathComponent
    let stem = (name as NSString).deletingPathExtension
    let extensionPart = (name as NSString).pathExtension
    let dotExtension = extensionPart.isEmpty ? "" : "." + extensionPart

    func path(_ filename: String) -> String {
      (folder as NSString).appendingPathComponent(filename)
    }

    var candidate = path(stem + settings.suffix + dotExtension)
    var n = 2
    while FileManager.default.fileExists(atPath: candidate) {
      candidate = path("\(stem)\(settings.suffix) \(n)\(dotExtension)")
      n += 1
    }
    return candidate
  }

  /// Create the local twin of `aliasFile`; return the new alias's path.
  @discardableResult
  static func run(aliasFile: String, settings: Settings) throws -> String {
    let aliasFile = URL(fileURLWithPath: (aliasFile as NSString).expandingTildeInPath)
      .standardizedFileURL.path

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: aliasFile, isDirectory: &isDirectory),
      !isDirectory.boolValue
    else {
      throw AliasError("not a file: \(aliasFile)")
    }

    let foreignTarget: String
    do {
      foreignTarget = try Bookmark.targetPath(ofAliasAt: aliasFile)
    } catch is BookmarkError {
      throw AliasError("not a macOS alias file: \((aliasFile as NSString).lastPathComponent)")
    }

    if FileManager.default.fileExists(atPath: foreignTarget) {
      throw AliasError(
        "this alias already works here — nothing to do:\n"
          + (aliasFile as NSString).lastPathComponent)
    }

    let target: String
    do {
      target = try Remap.remap(foreignTarget)
    } catch let error as RemapError {
      throw AliasError(error.message)
    }

    let aliasPath = newAliasPath(original: aliasFile, target: target, settings: settings)
    try AliasFile.create(target: target, at: aliasPath)
    return aliasPath
  }
}
