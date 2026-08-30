# Realias

Takes a Finder alias that was made on **another Mac** (under a different user
account) inside the shared OneDrive, and creates a second alias next to it that
works on **this** Mac. The original alias is never modified, so it keeps
working on the machine that made it.

## How it works

A macOS alias file stores its target as *bookmark data* — which contains the
target's full POSIX path, e.g.

    /Users/otheruser/Library/CloudStorage/OneDrive-ContosoLtd/Projects/Plan.pdf

Realias reads that path **without resolving it** (resolving is exactly
what fails for a foreign alias), cuts everything up to and including the
OneDrive folder, and re-attaches the remainder to this Mac's OneDrive root:

    /Users/you/Library/CloudStorage/OneDrive-ContosoLtd/Projects/Plan.pdf

If that file or folder exists, it writes a new alias beside the original.

Both OneDrive layouts are recognised — `~/Library/CloudStorage/OneDrive-…`
and the older `~/OneDrive - …`.

## Usage

**Quick Action (easiest):** right-click the alias in Finder →
*Quick Actions* → **Create Local Alias**.

**App:** select the alias file (or several) in Finder, then launch
**Realias.app**. Keep it in the Dock so that is one click.

Either way a dialog reports what was created, or why an alias could not be
mapped.

> Double-clicking the alias itself, or dropping it on the app, cannot work:
> macOS resolves an alias *before* handing it to any application, and that
> resolution is what fails for an alias from another Mac. The Quick Action and
> the Finder selection both hand over the alias file unresolved, which is why
> Realias uses them.

On first use macOS asks for permission (to control Finder for the app, to run
the workflow for the Quick Action). Approve once; see
System Settings → Privacy & Security → Automation.

## Settings

    ~/Library/Application Support/Realias/config.json

Created with the defaults the first time Realias runs. Open it with:

    open -e "$HOME/Library/Application Support/Realias/config.json"

```json
{
  "suffix": " (this Mac)",
  "name_source": "alias"
}
```

| Setting | Meaning |
| --- | --- |
| `suffix` | Appended to the name of the new alias, before the extension. Any text. |
| `name_source` | `alias` names the new file after the original alias; `target` names it after the item the alias points at. |

So an alias named `My Shortcut` pointing at `…/Documents` becomes
`My Shortcut (this Mac)` with `"name_source": "alias"`, and
`Documents (this Mac)` with `"target"`.

If a name is already taken, a number is appended.

## Command line

The app bundle *is* the command line tool:

    /Applications/Realias.app/Contents/MacOS/Realias ~/path/to/some.alias

Prints the path of each alias it creates. `--report` switches to the
human-readable summary the app and Quick Action display. Three more flags help
when working on Realias itself: `--target-of` prints the path an alias records,
`--make-alias <target> <alias>` writes an alias file, and `--onedrive-roots`
lists the OneDrive folders found on this Mac.

## Building and installing

Realias is a single Swift package — no Xcode project, no runtime
dependencies. The Swift toolchain that ships with the Command Line Tools is
enough.

    ./build.sh     # builds Realias.app and stages the .workflow
    ./install.sh   # copies them to /Applications and ~/Library/Services

The Quick Action calls `/Applications/Realias.app`, so install after every
build. `build.sh` ad-hoc signs the bundle, because macOS refuses an unsigned
app the Automation permission it needs to read the Finder selection.

## Layout

| File | Purpose |
| --- | --- |
| `Sources/Realias/Bookmark.swift` | Parses alias bookmark data; returns the recorded path |
| `Sources/Realias/Remap.swift` | Rewrites a foreign OneDrive path to this Mac's |
| `Sources/Realias/Config.swift` | Reads (and creates) `config.json` |
| `Sources/Realias/AliasFile.swift` | Writes a real Finder alias via the Cocoa bookmark API |
| `Sources/Realias/Localize.swift` | Ties it together: read → remap → write |
| `Sources/Realias/Report.swift` | The summary the dialog and Quick Action show |
| `Sources/Realias/FinderSelection.swift` | Asks Finder what is selected, unresolved |
| `Sources/Realias/App.swift` | The app: Finder selection → dialog |
| `Sources/Realias/CLI.swift` | Command line entry point |
| `Resources/Info.plist` | The app bundle's property list |
| `QuickAction/` | The Services workflow bundle, copied as-is by `build.sh` |
| `make_testalias.sh` | Builds a fake foreign alias in `testdata/` |

Errors that happen inside the app bundle are appended to
`~/Library/Logs/Realias.log`.

## Limits

- Targets must live inside OneDrive. Anything else is reported as unmappable.
- The new alias sits in the synced folder too, so it will appear on the other
  Mac as well — where it will *not* resolve. The suffix keeps the two apart.

## License

MIT — see [LICENSE](LICENSE).
