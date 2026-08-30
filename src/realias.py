"""Turn an alias made on another Mac into one that works on this Mac.

Reads the foreign alias without resolving it, rewrites the OneDrive prefix to
this machine's, and drops a new alias next to the original. The original file
is never touched, so it keeps working on the Mac that created it.
"""

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bookmark
import config
import remap

MAKE_ALIAS_JS = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "make_alias.js")


class AliasError(Exception):
    pass


def _new_alias_path(original, target, settings):
    """Pick a free name next to `original`, per the configured name source."""
    folder = os.path.dirname(original)
    source = original if settings["name_source"] == "alias" else target
    stem, ext = os.path.splitext(os.path.basename(source))
    suffix = settings["suffix"]

    candidate = os.path.join(folder, stem + suffix + ext)
    n = 2
    while os.path.exists(candidate):
        candidate = os.path.join(folder, "%s%s %d%s" % (stem, suffix, n, ext))
        n += 1
    return candidate


def _create_alias(target, alias_path):
    result = subprocess.run(
        ["osascript", "-l", "JavaScript", MAKE_ALIAS_JS, target, alias_path],
        capture_output=True, text=True)
    if result.returncode != 0:
        raise AliasError(result.stderr.strip() or "could not create alias file")


def localize(alias_file, settings=None):
    """Create the local twin of `alias_file`; return the new alias's path."""
    if settings is None:
        settings = config.load()
    alias_file = os.path.abspath(alias_file)
    if not os.path.isfile(alias_file):
        raise AliasError("not a file: %s" % alias_file)
    try:
        foreign_target = bookmark.read_alias(alias_file)
    except bookmark.BookmarkError:
        raise AliasError("not a macOS alias file: %s"
                         % os.path.basename(alias_file))

    if os.path.exists(foreign_target):
        raise AliasError("this alias already works here — nothing to do:\n%s"
                         % os.path.basename(alias_file))

    try:
        target = remap.remap(foreign_target)
    except remap.RemapError as e:
        raise AliasError(str(e))

    alias_path = _new_alias_path(alias_file, target, settings)
    _create_alias(target, alias_path)
    return alias_path


def main(argv):
    report = "--report" in argv
    paths = [a for a in argv if a != "--report"]
    if not paths:
        print("usage: realias.py [--report] <alias file> [...]",
              file=sys.stderr)
        return 2

    try:
        settings = config.load()
    except config.ConfigError as e:
        print(str(e), file=sys.stderr if not report else sys.stdout)
        return 0 if report else 2

    lines = []
    failed = False
    for path in paths:
        name = os.path.basename(path)
        try:
            created = localize(path, settings)
            lines.append("OK  %s\n    -> %s" % (name, os.path.basename(created)))
            if not report:
                print(created)
        except AliasError as e:
            failed = True
            lines.append("--  %s\n    %s" % (name, str(e).replace("\n", "\n    ")))
            if not report:
                print("%s: %s" % (name, e), file=sys.stderr)

    # In report mode the caller shows the text in a dialog, so always exit 0.
    if report:
        print("\n\n".join(lines))
        return 0
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
