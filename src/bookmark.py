"""Minimal reader for macOS alias-file bookmark data.

Extracts the target's POSIX path *without* resolving it, so it works for
aliases whose target does not exist on this machine.
"""

import struct

MAGIC_BOOK = b"book"
MAGIC_MARK = b"mark"
TOC_MAGIC = 0xFFFFFFFE

KEY_PATH = 0x1004          # kBookmarkPath: array of path components
KEY_VOLUME_PATH = 0x2002   # kBookmarkVolumePath

TYPE_STRING = 0x0101
TYPE_ARRAY = 0x0601


class BookmarkError(Exception):
    pass


def _u32(data, off):
    return struct.unpack_from("<I", data, off)[0]


def _record(data, base, off):
    """Return (type, payload) for the record at body offset `off`."""
    pos = base + off
    if pos + 8 > len(data):
        raise BookmarkError("record out of range")
    length = _u32(data, pos)
    rtype = _u32(data, pos + 4)
    start = pos + 8
    end = start + length
    if end > len(data):
        raise BookmarkError("record payload out of range")
    return rtype, data[start:end]


def _toc(data, base):
    """Return {key: offset} merged over the whole TOC chain."""
    entries = {}
    toc_off = _u32(data, base)
    seen = set()
    while toc_off and toc_off not in seen:
        seen.add(toc_off)
        pos = base + toc_off
        if pos + 20 > len(data):
            raise BookmarkError("TOC out of range")
        magic = _u32(data, pos + 4)
        if magic != TOC_MAGIC:
            raise BookmarkError("bad TOC magic 0x%08x" % magic)
        next_toc = _u32(data, pos + 12)
        count = _u32(data, pos + 16)
        for i in range(count):
            e = pos + 20 + i * 12
            if e + 12 > len(data):
                raise BookmarkError("TOC entry out of range")
            key = _u32(data, e)
            entries.setdefault(key, _u32(data, e + 4))
        toc_off = next_toc
    return entries


def _string_array(data, base, off):
    rtype, payload = _record(data, base, off)
    if rtype != TYPE_ARRAY:
        raise BookmarkError("expected array, got 0x%04x" % rtype)
    out = []
    for i in range(0, len(payload) - 3, 4):
        item_off = struct.unpack_from("<I", payload, i)[0]
        itype, ipayload = _record(data, base, item_off)
        if itype != TYPE_STRING:
            raise BookmarkError("expected string, got 0x%04x" % itype)
        out.append(ipayload.decode("utf-8"))
    return out


def target_path(data):
    """Given raw bookmark bytes, return the recorded absolute POSIX path."""
    if len(data) < 48 or data[0:4] != MAGIC_BOOK or data[8:12] != MAGIC_MARK:
        raise BookmarkError("not bookmark data")
    base = _u32(data, 16)
    if not 12 <= base < len(data):
        raise BookmarkError("bad header size %d" % base)

    toc = _toc(data, base)
    if KEY_PATH not in toc:
        raise BookmarkError("no path in bookmark")
    path = "/" + "/".join(_string_array(data, base, toc[KEY_PATH]))

    volume = "/"
    if KEY_VOLUME_PATH in toc:
        vtype, vpayload = _record(data, base, toc[KEY_VOLUME_PATH])
        if vtype == TYPE_STRING:
            volume = vpayload.decode("utf-8")
    if volume not in ("", "/"):
        path = volume.rstrip("/") + path
    return path


def read_alias(path):
    with open(path, "rb") as f:
        return target_path(f.read())


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        print(read_alias(p))
