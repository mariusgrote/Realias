import Foundation

/// Runs Realias over a list of files and formats the human-readable summary
/// the app dialog and the Quick Action show.
enum Report {
  struct Outcome {
    let text: String
    let createdPaths: [String]
    let failed: Bool
  }

  static func run(paths: [String]) -> Outcome {
    let settings = Settings.load()
    var lines: [String] = []
    var created: [String] = []
    var failed = false

    for path in paths {
      let name = (path as NSString).lastPathComponent
      do {
        let alias = try Localize.run(aliasFile: path, settings: settings)
        created.append(alias)
        lines.append("OK  \(name)\n    -> \((alias as NSString).lastPathComponent)")
      } catch {
        failed = true
        let message = "\(error)".replacingOccurrences(of: "\n", with: "\n    ")
        lines.append("--  \(name)\n    \(message)")
      }
    }

    return Outcome(text: lines.joined(separator: "\n\n"), createdPaths: created, failed: failed)
  }
}
