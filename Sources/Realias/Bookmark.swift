import Foundation

/// Minimal reader for macOS alias-file bookmark data.
///
/// Extracts the target's POSIX path *without* resolving it, so it works for
/// aliases whose target does not exist on this machine.
enum Bookmark {
  private static let magicBook = Data("book".utf8)
  private static let magicMark = Data("mark".utf8)
  private static let tocMagic: UInt32 = 0xFFFF_FFFE

  private static let keyPath: UInt32 = 0x1004  // kBookmarkPath: array of path components
  private static let keyVolumePath: UInt32 = 0x2002  // kBookmarkVolumePath

  private static let typeString: UInt32 = 0x0101
  private static let typeArray: UInt32 = 0x0601

  private static func u32(_ data: Data, _ offset: Int) throws -> UInt32 {
    guard offset >= 0, offset + 4 <= data.count else {
      throw BookmarkError("read out of range")
    }
    return data.withUnsafeBytes {
      $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
    }.littleEndian
  }

  /// Return (type, payload) for the record at body offset `offset`.
  private static func record(_ data: Data, base: Int, offset: Int) throws -> (UInt32, Data) {
    let pos = base + offset
    guard pos >= 0, pos + 8 <= data.count else {
      throw BookmarkError("record out of range")
    }
    let length = Int(try u32(data, pos))
    let type = try u32(data, pos + 4)
    let start = pos + 8
    guard start + length <= data.count else {
      throw BookmarkError("record payload out of range")
    }
    return (type, data.subdata(in: start..<(start + length)))
  }

  /// Return [key: offset] merged over the whole TOC chain.
  private static func toc(_ data: Data, base: Int) throws -> [UInt32: UInt32] {
    var entries: [UInt32: UInt32] = [:]
    var tocOffset = try u32(data, base)
    var seen: Set<UInt32> = []

    while tocOffset != 0, !seen.contains(tocOffset) {
      seen.insert(tocOffset)
      let pos = base + Int(tocOffset)
      guard pos >= 0, pos + 20 <= data.count else {
        throw BookmarkError("TOC out of range")
      }
      let magic = try u32(data, pos + 4)
      guard magic == tocMagic else {
        throw BookmarkError(String(format: "bad TOC magic 0x%08x", magic))
      }
      let next = try u32(data, pos + 12)
      let count = Int(try u32(data, pos + 16))
      for i in 0..<count {
        let entry = pos + 20 + i * 12
        guard entry + 12 <= data.count else {
          throw BookmarkError("TOC entry out of range")
        }
        let key = try u32(data, entry)
        if entries[key] == nil {
          entries[key] = try u32(data, entry + 4)
        }
      }
      tocOffset = next
    }
    return entries
  }

  private static func string(_ payload: Data) throws -> String {
    guard let text = String(data: payload, encoding: .utf8) else {
      throw BookmarkError("string is not valid UTF-8")
    }
    return text
  }

  private static func stringArray(_ data: Data, base: Int, offset: Int) throws -> [String] {
    let (type, payload) = try record(data, base: base, offset: offset)
    guard type == typeArray else {
      throw BookmarkError(String(format: "expected array, got 0x%04x", type))
    }
    var items: [String] = []
    for i in stride(from: 0, to: max(payload.count - 3, 0), by: 4) {
      let itemOffset = try u32(payload, i)
      let (itemType, itemPayload) = try record(data, base: base, offset: Int(itemOffset))
      guard itemType == typeString else {
        throw BookmarkError(String(format: "expected string, got 0x%04x", itemType))
      }
      items.append(try string(itemPayload))
    }
    return items
  }

  /// Given raw bookmark bytes, return the recorded absolute POSIX path.
  static func targetPath(of data: Data) throws -> String {
    guard data.count >= 48,
      data.subdata(in: 0..<4) == magicBook,
      data.subdata(in: 8..<12) == magicMark
    else {
      throw BookmarkError("not bookmark data")
    }
    let base = Int(try u32(data, 16))
    guard base >= 12, base < data.count else {
      throw BookmarkError("bad header size \(base)")
    }

    let toc = try toc(data, base: base)
    guard let pathOffset = toc[keyPath] else {
      throw BookmarkError("no path in bookmark")
    }
    var path =
      "/" + (try stringArray(data, base: base, offset: Int(pathOffset))).joined(separator: "/")

    var volume = "/"
    if let volumeOffset = toc[keyVolumePath] {
      let (type, payload) = try record(data, base: base, offset: Int(volumeOffset))
      if type == typeString {
        volume = try string(payload)
      }
    }
    if volume != "", volume != "/" {
      while volume.hasSuffix("/") { volume.removeLast() }
      path = volume + path
    }
    return path
  }

  /// Read an alias file and return the path it records.
  static func targetPath(ofAliasAt path: String) throws -> String {
    guard let data = FileManager.default.contents(atPath: path) else {
      throw BookmarkError("could not read \(path)")
    }
    return try targetPath(of: data)
  }
}
