import Foundation

/// Map a POSIX path recorded on another Mac onto this Mac's OneDrive root.
enum Remap {
  static let home = NSHomeDirectory()
  static var cloudStorage: String {
    (home as NSString).appendingPathComponent("Library/CloudStorage")
  }

  // "OneDrive - Contoso Ltd" and "OneDrive-ContosoLtd" are the same library
  // under two layouts, so compare names with spaces/dashes stripped.
  private static func normalized(_ name: String) -> String {
    name.lowercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
  }

  private static func isOneDrive(_ name: String) -> Bool {
    normalized(name).hasPrefix("onedrive")
  }

  private static func entries(of directory: String) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []).sorted()
  }

  /// Every OneDrive root that exists on this Mac, newest layout first.
  static func localRoots() -> [String] {
    var roots: [String] = []
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: cloudStorage, isDirectory: &isDirectory),
      isDirectory.boolValue
    {
      for name in entries(of: cloudStorage) where isOneDrive(name) {
        roots.append((cloudStorage as NSString).appendingPathComponent(name))
      }
    }
    for name in entries(of: home) where isOneDrive(name) {
      roots.append((home as NSString).appendingPathComponent(name))
    }
    return roots
  }

  /// Return (OneDrive folder name, path relative to it) for a foreign path.
  static func splitOneDrive(_ path: String) throws -> (root: String, relative: String) {
    let parts = path.split(separator: "/").map(String.init)
    for (i, part) in parts.enumerated() where isOneDrive(part) {
      return (part, parts[(i + 1)...].joined(separator: "/"))
    }
    throw RemapError("path is not inside OneDrive:\n\(path)")
  }

  /// Rewrite a foreign OneDrive path to the equivalent path on this Mac.
  static func remap(_ path: String) throws -> String {
    let (foreignRoot, relative) = try splitOneDrive(path)
    let roots = localRoots()
    if roots.isEmpty {
      throw RemapError("no OneDrive folder found on this Mac")
    }

    let matching = roots.filter {
      normalized(($0 as NSString).lastPathComponent) == normalized(foreignRoot)
    }
    let candidates = matching.isEmpty ? roots : matching

    for root in candidates {
      let candidate = (root as NSString).appendingPathComponent(relative)
      if FileManager.default.fileExists(atPath: candidate) {
        return candidate
      }
    }

    // Nothing exists; report against the best-guess root so the message is useful.
    let guess = (candidates[0] as NSString).appendingPathComponent(relative)
    throw RemapError("target not found on this Mac:\n\(guess)")
  }
}
