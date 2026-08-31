import AppKit

/// Realias has two ways in.
///
/// Handed files directly — "Open With", or the Quick Action — it rebuilds them,
/// reports, and quits. Launched on its own it opens the main window, where the
/// settings live and alias files can be picked.
///
/// Note that dropping an alias on the app icon cannot work: macOS resolves an
/// alias before handing it over, and that resolution is what fails for a
/// foreign alias. The window's file picker asks for no resolution, so it can.
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var handledDocuments = false

  func application(_ application: NSApplication, open urls: [URL]) {
    handledDocuments = true
    let outcome = Report.run(paths: urls.map(\.path))
    alert(outcome.text)
    NSApp.terminate(nil)
  }

  // AppKit's counterpart to `application(_:open:)`: it fires only when the
  // app was launched without documents, so the two paths cannot both run.
  func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
    MainWindow.show()
    return true
  }

  // Clicking the Dock icon of the already-running app brings the window back.
  func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows: Bool
  ) -> Bool {
    MainWindow.show()
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.mainMenu = Self.menu()
    NSApp.activate(ignoringOtherApps: true)

    // Safety net for a launch that delivers neither callback: a window beats an
    // app that sits there doing nothing. `MainWindow.show` is idempotent, and
    // the flag keeps it from appearing behind a report that is already up.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
      guard !handledDocuments else { return }
      MainWindow.show()
    }
  }

  /// Without a menu bar there is no Quit, and no Cut/Copy/Paste in the
  /// settings field — AppKit routes those through menu items.
  private static func menu() -> NSMenu {
    func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
      let item = NSMenuItem()
      item.submenu = NSMenu(title: title)
      items.forEach(item.submenu!.addItem)
      return item
    }
    func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
      NSMenuItem(title: title, action: action, keyEquivalent: key)
    }

    let main = NSMenu()
    main.addItem(
      submenu(
        "Realias",
        [
          item("Hide Realias", #selector(NSApplication.hide(_:)), "h"),
          .separator(),
          item("Quit Realias", #selector(NSApplication.terminate(_:)), "q"),
        ]))
    main.addItem(
      submenu(
        "Edit",
        [
          item("Undo", Selector(("undo:")), "z"),
          item("Redo", Selector(("redo:")), "Z"),
          .separator(),
          item("Cut", #selector(NSText.cut(_:)), "x"),
          item("Copy", #selector(NSText.copy(_:)), "c"),
          item("Paste", #selector(NSText.paste(_:)), "v"),
          item("Select All", #selector(NSText.selectAll(_:)), "a"),
        ]))
    main.addItem(
      submenu(
        "Window",
        [
          item("Close", #selector(NSWindow.performClose(_:)), "w"),
          item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
        ]))
    return main
  }

  private func alert(_ text: String, style: NSAlert.Style = .informational) {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = "Realias"
    alert.informativeText = text
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}

/// Failures inside an app bundle are otherwise invisible; see
/// ~/Library/Logs/Realias.log
enum Log {
  static func write(_ text: String) {
    let path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs/Realias.log")
    guard let data = (text + "\n").data(using: .utf8) else { return }
    if let handle = FileHandle(forWritingAtPath: path) {
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    } else {
      try? data.write(to: URL(fileURLWithPath: path))
    }
  }
}
