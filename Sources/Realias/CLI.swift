import Foundation

enum CLI {
  static let usage = """
    usage: Realias [--report] <alias file> [...]
           Realias --target-of <alias file> [...]     print the recorded path
           Realias --make-alias <target> <alias>      write an alias file
           Realias --onedrive-roots                   list this Mac's OneDrive roots
    """

  static func run(_ arguments: [String]) -> Int32 {
    switch arguments.first {
    case "--onedrive-roots":
      for root in Remap.localRoots() { print(root) }
      return 0
    case "--target-of":
      return targetOf(Array(arguments.dropFirst()))
    case "--make-alias":
      return makeAlias(Array(arguments.dropFirst()))
    default:
      return localize(arguments)
    }
  }

  private static func targetOf(_ paths: [String]) -> Int32 {
    guard !paths.isEmpty else { return fail(usage, status: 2) }
    var status: Int32 = 0
    for path in paths {
      do {
        print(try Bookmark.targetPath(ofAliasAt: path))
      } catch {
        status = fail("\((path as NSString).lastPathComponent): \(error)")
      }
    }
    return status
  }

  private static func makeAlias(_ arguments: [String]) -> Int32 {
    guard arguments.count == 2 else { return fail(usage, status: 2) }
    do {
      try AliasFile.create(target: arguments[0], at: arguments[1])
    } catch {
      return fail("\(error)")
    }
    return 0
  }

  private static func localize(_ arguments: [String]) -> Int32 {
    let report = arguments.contains("--report")
    let paths = arguments.filter { $0 != "--report" }
    guard !paths.isEmpty else { return fail(usage, status: 2) }

    // In report mode the caller shows the text in a dialog, so always exit 0.
    if report {
      print(Report.run(paths: paths).text)
      return 0
    }

    let settings: Settings
    do {
      settings = try Settings.load()
    } catch {
      return fail("\(error)", status: 2)
    }

    var status: Int32 = 0
    for path in paths {
      do {
        print(try Localize.run(aliasFile: path, settings: settings))
      } catch {
        status = fail("\((path as NSString).lastPathComponent): \(error)")
      }
    }
    return status
  }

  @discardableResult
  private static func fail(_ message: String, status: Int32 = 1) -> Int32 {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    return status
  }
}
