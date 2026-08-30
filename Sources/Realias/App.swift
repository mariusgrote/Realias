import AppKit

/// Realias as a Finder-facing app: select the alias file (or files) in Finder,
/// then launch Realias. Dropping files on the app is supported but rarely
/// useful, because macOS resolves an alias before handing it over — which is
/// exactly what fails for a foreign alias.
final class AppDelegate: NSObject, NSApplicationDelegate {
	private var hasRun = false

	func application(_ application: NSApplication, open urls: [URL]) {
		runOnce { self.localize(paths: urls.map(\.path)) }
	}

	// AppKit's counterpart to `application(_:open:)`: it fires only when the
	// app was launched without documents, so the two paths cannot both run.
	func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
		runOnce { self.runFromFinderSelection() }
		return true
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)

		// Safety net for a launch that delivers neither callback: a late dialog
		// beats an app that sits there doing nothing. `runOnce` keeps it from
		// duplicating work the real callback already did.
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
			runOnce { runFromFinderSelection() }
		}
	}

	/// The first caller wins and does the work; every caller ends the app.
	private func runOnce(_ body: () -> Void) {
		guard !hasRun else { return }
		hasRun = true
		body()
		NSApp.terminate(nil)
	}

	private func runFromFinderSelection() {
		let paths: [String]
		do {
			paths = try FinderSelection.paths()
		} catch {
			Log.write("reading Finder selection: \(error)")
			alert("Realias could not read the Finder selection:\n\n\(error)", style: .critical)
			return
		}
		if paths.isEmpty {
			alert("Select the alias file (or files) in Finder, then start Realias again.")
			return
		}
		localize(paths: paths)
	}

	private func localize(paths: [String]) {
		let outcome = Report.run(paths: paths)
		alert(outcome.text)
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
