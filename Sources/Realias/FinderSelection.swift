import Foundation

/// Read Finder's selection as plain paths.
///
/// Coercing an item to `alias` would resolve the very alias files we need to
/// inspect by hand, so the path is built from the container and the name
/// instead.
enum FinderSelection {
  private static let source = """
    set output to {}
    tell application "Finder"
    	repeat with anItem in (get selection)
    		try
    			set end of output to POSIX path of ((container of anItem as text) & (name of anItem))
    		end try
    	end repeat
    end tell
    return output
    """

  static func paths() throws -> [String] {
    guard let script = NSAppleScript(source: source) else {
      throw AliasError("could not compile the Finder query")
    }
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    if let error {
      let message = error[NSAppleScript.errorMessage] as? String
      throw AliasError(message ?? "AppleScript error \(error[NSAppleScript.errorNumber] ?? "")")
    }
    // Read the list item by item: macOS allows newlines in a file name, so
    // joining the paths into one string would split such a name in two.
    // `numberOfItems` is 0 for anything that is not a list.
    guard result.numberOfItems > 0 else { return [] }
    return (1...result.numberOfItems)
      .compactMap { result.atIndex($0)?.stringValue }
      .filter { !$0.isEmpty }
  }
}
