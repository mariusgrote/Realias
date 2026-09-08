# Realias

A Finder alias made on **another Mac**, inside a shared OneDrive, will not
resolve on yours. Realias reads it anyway and writes a working copy next to it.
The original is never touched, so it keeps working on the machine that made it.

## How it works

An alias file stores its target as *bookmark data*, which contains the target's
full POSIX path:

    /Users/otheruser/Library/CloudStorage/OneDrive-ContosoLtd/Projects/Plan.pdf

Realias reads that path **without resolving it**, because resolving is exactly
what fails for a foreign alias. It cuts everything up to and including the
OneDrive folder, re-attaches the rest to this Mac's OneDrive root, and if the
result exists, writes a new alias beside the original:

    /Users/you/Library/CloudStorage/OneDrive-ContosoLtd/Projects/Plan.pdf

Both OneDrive layouts work, `~/Library/CloudStorage/OneDrive-…` and the older
`~/OneDrive - …`.

## Usage

Right-click the alias in Finder → *Quick Actions* → **Create Local Alias**.
That is the whole thing.

Two other ways in: *Open With* → **Realias** shows a dialog and quits, and
launching Realias.app on its own opens a window with the settings, a file
picker, and a button that rebuilds the current Finder selection.

> Double-clicking the alias, or dropping it on the app icon, cannot work.
> macOS resolves an alias *before* handing it to any application, and that
> resolution is what fails here. The Quick Action, the picker and the Finder
> selection all pass the file over unresolved.

macOS asks once for permission to control Finder. Grants live in
System Settings → Privacy & Security → Automation.

## Settings

Two, both in the app window, both saved as you change them:

| Setting | Meaning |
| --- | --- |
| Suffix | Appended to the new alias's name, before the extension. |
| Name from | Name the copy after the alias file, or after the target it points at. |

An alias `My Shortcut` pointing at `…/Documents` becomes `My Shortcut (this
Mac)` or `Documents (this Mac)`. Taken names get a number appended.

They are stored in `UserDefaults`, so edit them from a terminal with
`defaults`, never by hand:

    defaults read io.github.mariusgrote.realias
    defaults write io.github.mariusgrote.realias suffix -string " (this Mac)"
    defaults delete io.github.mariusgrote.realias    # back to the defaults

## Command line

The app bundle *is* the command line tool:

    /Applications/Realias.app/Contents/MacOS/Realias ~/path/to/some.alias

It prints the path of each alias it creates. `--report` gives the summary the
app shows instead. For working on Realias itself, `--target-of` prints the path
an alias records, `--make-alias <target> <alias>` writes one, and
`--onedrive-roots` lists the OneDrive folders on this Mac.

## Building

One Swift package, no Xcode project, no dependencies. The toolchain from the
Command Line Tools is enough.

    ./build.sh     # builds Realias.app and stages the .workflow
    ./install.sh   # copies them to /Applications and ~/Library/Services

Install after every build, since the Quick Action calls the copy in
`/Applications`. `build.sh` ad-hoc signs the bundle, because macOS will not
give an unsigned app the Automation permission it needs to read the Finder
selection.

The icon is drawn in code, not stored as artwork: `./Tools/make_icon.sh`
re-renders `Resources/Realias.icns` from `Tools/make_icon.swift`. `build.sh`
only copies the result, so run it after changing the drawing.

Sources are one file per step: `Bookmark` reads the path, `Remap` rewrites it,
`AliasFile` writes the new alias, `Localize` chains the three. Errors from the
app bundle land in `~/Library/Logs/Realias.log`.

## Limits

- Targets must live inside OneDrive. Anything else is reported as unmappable.
- The new alias syncs too, so it shows up on the other Mac, where it will *not*
  resolve. The suffix keeps the two apart.

## License

MIT, see [LICENSE](LICENSE).
