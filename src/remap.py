"""Map a POSIX path recorded on another Mac onto this Mac's OneDrive root."""

import os
import re

HOME = os.path.expanduser("~")
CLOUDSTORAGE = os.path.join(HOME, "Library", "CloudStorage")

# "OneDrive - Contoso Ltd" and "OneDrive-ContosoLtd" are the same library
# under two layouts, so compare names with spaces/dashes stripped.
_NORMALIZE = re.compile(r"[\s\-_]+")


class RemapError(Exception):
    pass


def _normalize(name):
    return _NORMALIZE.sub("", name).lower()


def _is_onedrive(name):
    return _normalize(name).startswith("onedrive")


def local_roots():
    """Every OneDrive root that exists on this Mac, newest layout first."""
    roots = []
    if os.path.isdir(CLOUDSTORAGE):
        for name in sorted(os.listdir(CLOUDSTORAGE)):
            if _is_onedrive(name):
                roots.append(os.path.join(CLOUDSTORAGE, name))
    for name in sorted(os.listdir(HOME)):
        if _is_onedrive(name):
            roots.append(os.path.join(HOME, name))
    return roots


def split_onedrive(path):
    """Return (onedrive folder name, path relative to it) for a foreign path."""
    parts = [p for p in path.split("/") if p]
    for i, part in enumerate(parts):
        if _is_onedrive(part):
            return part, "/".join(parts[i + 1:])
    raise RemapError("path is not inside OneDrive:\n%s" % path)


def remap(path):
    """Rewrite a foreign OneDrive path to the equivalent path on this Mac."""
    foreign_root, relative = split_onedrive(path)
    roots = local_roots()
    if not roots:
        raise RemapError("no OneDrive folder found on this Mac")

    matching = [r for r in roots
                if _normalize(os.path.basename(r)) == _normalize(foreign_root)]
    candidates = matching or roots

    for root in candidates:
        candidate = os.path.join(root, relative)
        if os.path.exists(candidate):
            return candidate

    # Nothing exists; report against the best-guess root so the message is useful.
    raise RemapError("target not found on this Mac:\n%s"
                     % os.path.join(candidates[0], relative))
