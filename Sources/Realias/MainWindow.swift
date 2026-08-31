import AppKit
import SwiftUI

/// What a manual launch of Realias shows: the settings, plus a way to pick
/// alias files to rebuild.
///
/// Settings are written to `config.json` as they change, so there is no Save
/// button — the file is the single source of truth and stays editable by hand.
final class MainModel: ObservableObject {
  @Published var suffix: String {
    didSet { save() }
  }
  @Published var nameSource: NameSource {
    didSet { save() }
  }

  /// The report from the last rebuild, shown below the buttons.
  @Published var report: String = ""
  /// A problem with config.json itself, or with saving it.
  @Published var problem: String?

  init() {
    let loaded: Settings
    do {
      loaded = try Settings.load()
    } catch {
      loaded = .defaults
      // Assigning below would trigger `save()` and overwrite the broken file,
      // so the note is set after the initial values are in place.
      self.suffix = loaded.suffix
      self.nameSource = loaded.nameSource
      self.problem = "\(error)\n\nShowing the defaults; changing anything here replaces the file."
      return
    }
    self.suffix = loaded.suffix
    self.nameSource = loaded.nameSource
  }

  var settings: Settings {
    Settings(suffix: suffix, nameSource: nameSource)
  }

  /// An example of the name a rebuilt alias gets with the current settings.
  var preview: String {
    Localize.newAliasName(original: "Plan alias", target: "Plan.pdf", settings: settings)
  }

  func reset() {
    suffix = Settings.defaults.suffix
    nameSource = Settings.defaults.nameSource
  }

  var isDefault: Bool {
    suffix == Settings.defaults.suffix && nameSource == Settings.defaults.nameSource
  }

  private func save() {
    do {
      try settings.save()
      problem = nil
    } catch {
      problem = "Could not write \(Settings.path):\n\(error.localizedDescription)"
    }
  }

  /// Ask for alias files and rebuild them. The panel must not resolve
  /// aliases — resolving is exactly what fails for an alias from another Mac.
  func chooseFiles() {
    let panel = NSOpenPanel()
    panel.message = "Select the alias files made on the other Mac."
    panel.prompt = "Rebuild"
    panel.resolvesAliases = false
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true
    guard panel.runModal() == .OK else { return }
    run(paths: panel.urls.map(\.path))
  }

  func useFinderSelection() {
    let paths: [String]
    do {
      paths = try FinderSelection.paths()
    } catch {
      Log.write("reading Finder selection: \(error)")
      report = "Could not read the Finder selection:\n\n\(error)"
      return
    }
    guard !paths.isEmpty else {
      report = "Nothing is selected in Finder."
      return
    }
    run(paths: paths)
  }

  private func run(paths: [String]) {
    report = Report.run(paths: paths).text
  }
}

struct MainView: View {
  @ObservedObject var model: MainModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Form {
        TextField("Suffix:", text: $model.suffix)
        Picker("Name from:", selection: $model.nameSource) {
          Text("The alias file").tag(NameSource.alias)
          Text("The item it points at").tag(NameSource.target)
        }
        LabeledContent("Example:") {
          Text(model.preview).foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)

      HStack {
        Button("Reset to Defaults", action: model.reset)
          .disabled(model.isDefault)
        Spacer()
        Button("Use Finder Selection", action: model.useFinderSelection)
        Button("Choose Alias Files…", action: model.chooseFiles)
          .keyboardShortcut(.defaultAction)
      }

      if let problem = model.problem {
        Text(problem)
          .font(.callout)
          .foregroundStyle(.red)
          .textSelection(.enabled)
      }

      if !model.report.isEmpty {
        Divider()
        ScrollView {
          Text(model.report)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minHeight: 100)
      }
    }
    .padding(20)
    .frame(width: 460)
    .frame(minHeight: 300, alignment: .top)
  }
}

/// Holds the one window so a second launch reuses it rather than stacking.
enum MainWindow {
  private static var window: NSWindow?

  static func show() {
    if let window {
      window.makeKeyAndOrderFront(nil)
      return
    }
    let created = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered,
      defer: false)
    created.title = "Realias"
    created.contentView = NSHostingView(rootView: MainView(model: MainModel()))
    created.center()
    created.isReleasedWhenClosed = false
    created.makeKeyAndOrderFront(nil)
    window = created
  }
}
