//! Minimal reader for macOS alias-file bookmark data.
//!
//! Extracts the target's POSIX path *without* resolving it. Port of
//! `Sources/Realias/Bookmark.swift`; keep the two in step.

use std::collections::{HashMap, HashSet};
use std::path::Path;

use crate::error::Error;

const MAGIC_BOOK: &[u8] = b"book";
const MAGIC_MARK: &[u8] = b"mark";
const TOC_MAGIC: u32 = 0xFFFF_FFFE;

const KEY_PATH: u32 = 0x1004; // kBookmarkPath: array of path components
const KEY_VOLUME_PATH: u32 = 0x2002; // kBookmarkVolumePath

const TYPE_STRING: u32 = 0x0101;
const TYPE_ARRAY: u32 = 0x0601;

fn u32_at(data: &[u8], offset: usize) -> Result<u32, Error> {
    data.get(offset..offset.wrapping_add(4))
        .map(|b| u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
        .ok_or_else(|| Error::new("read out of range"))
}

/// Return (type, payload) for the record at body offset `offset`.
fn record(data: &[u8], base: usize, offset: usize) -> Result<(u32, &[u8]), Error> {
    let pos = base
        .checked_add(offset)
        .ok_or_else(|| Error::new("record out of range"))?;
    if pos + 8 > data.len() {
        return Err(Error::new("record out of range"));
    }
    let length = u32_at(data, pos)? as usize;
    let kind = u32_at(data, pos + 4)?;
    let payload = data
        .get(pos + 8..(pos + 8).saturating_add(length))
        .ok_or_else(|| Error::new("record payload out of range"))?;
    Ok((kind, payload))
}

/// Return {key: offset} merged over the whole TOC chain.
fn toc(data: &[u8], base: usize) -> Result<HashMap<u32, u32>, Error> {
    let mut entries = HashMap::new();
    let mut toc_offset = u32_at(data, base)?;
    let mut seen = HashSet::new();

    while toc_offset != 0 && seen.insert(toc_offset) {
        let pos = base + toc_offset as usize;
        if pos + 20 > data.len() {
            return Err(Error::new("TOC out of range"));
        }
        let magic = u32_at(data, pos + 4)?;
        if magic != TOC_MAGIC {
            return Err(Error::new(format!("bad TOC magic 0x{magic:08x}")));
        }
        let next = u32_at(data, pos + 12)?;
        let count = u32_at(data, pos + 16)? as usize;
        for i in 0..count {
            let entry = pos + 20 + i * 12;
            if entry + 12 > data.len() {
                return Err(Error::new("TOC entry out of range"));
            }
            let key = u32_at(data, entry)?;
            let value = u32_at(data, entry + 4)?;
            entries.entry(key).or_insert(value);
        }
        toc_offset = next;
    }
    Ok(entries)
}

fn string(payload: &[u8]) -> Result<String, Error> {
    String::from_utf8(payload.to_vec()).map_err(|_| Error::new("string is not valid UTF-8"))
}

fn string_array(data: &[u8], base: usize, offset: usize) -> Result<Vec<String>, Error> {
    let (kind, payload) = record(data, base, offset)?;
    if kind != TYPE_ARRAY {
        return Err(Error::new(format!("expected array, got 0x{kind:04x}")));
    }
    payload
        .as_chunks::<4>()
        .0
        .iter()
        .map(|chunk| {
            let item_offset = u32::from_le_bytes(*chunk) as usize;
            let (item_kind, item_payload) = record(data, base, item_offset)?;
            if item_kind != TYPE_STRING {
                return Err(Error::new(format!(
                    "expected string, got 0x{item_kind:04x}"
                )));
            }
            string(item_payload)
        })
        .collect()
}

/// Given raw bookmark bytes, return the recorded absolute POSIX path.
pub fn target_path(data: &[u8]) -> Result<String, Error> {
    if data.len() < 48 || &data[0..4] != MAGIC_BOOK || &data[8..12] != MAGIC_MARK {
        return Err(Error::new("not bookmark data"));
    }
    let base = u32_at(data, 16)? as usize;
    if base < 12 || base >= data.len() {
        return Err(Error::new(format!("bad header size {base}")));
    }

    let toc = toc(data, base)?;
    let path_offset = toc
        .get(&KEY_PATH)
        .ok_or_else(|| Error::new("no path in bookmark"))?;
    let mut path = format!(
        "/{}",
        string_array(data, base, *path_offset as usize)?.join("/")
    );

    let mut volume = String::from("/");
    if let Some(&volume_offset) = toc.get(&KEY_VOLUME_PATH) {
        let (kind, payload) = record(data, base, volume_offset as usize)?;
        if kind == TYPE_STRING {
            volume = string(payload)?;
        }
    }
    if !volume.is_empty() && volume != "/" {
        path = format!("{}{path}", volume.trim_end_matches('/'));
    }
    Ok(path)
}

/// Read an alias file and return the path it records.
pub fn target_path_of_file(path: &Path) -> Result<String, Error> {
    let data = std::fs::read(path)
        .map_err(|e| Error::new(format!("could not read {}: {e}", path.display())))?;
    target_path(&data)
}

#[cfg(test)]
pub mod tests {
    use super::*;

    /// Build minimal bookmark bytes holding `components` and optionally a
    /// volume path — just the records `target_path` reads.
    pub fn make_bookmark(components: &[&str], volume: Option<&str>) -> Vec<u8> {
        fn push_record(body: &mut Vec<u8>, kind: u32, payload: &[u8]) -> u32 {
            let offset = body.len() as u32;
            body.extend_from_slice(&(payload.len() as u32).to_le_bytes());
            body.extend_from_slice(&kind.to_le_bytes());
            body.extend_from_slice(payload);
            while !body.len().is_multiple_of(4) {
                body.push(0);
            }
            offset
        }

        // Body offset 0 holds the offset of the first TOC; patched below.
        let mut body = vec![0u8; 4];
        let items: Vec<u32> = components
            .iter()
            .map(|c| push_record(&mut body, TYPE_STRING, c.as_bytes()))
            .collect();
        let array: Vec<u8> = items.iter().flat_map(|o| o.to_le_bytes()).collect();
        let mut entries = vec![(KEY_PATH, push_record(&mut body, TYPE_ARRAY, &array))];
        if let Some(volume) = volume {
            entries.push((
                KEY_VOLUME_PATH,
                push_record(&mut body, TYPE_STRING, volume.as_bytes()),
            ));
        }

        let toc_offset = body.len() as u32;
        body[0..4].copy_from_slice(&toc_offset.to_le_bytes());
        body.extend_from_slice(&0u32.to_le_bytes()); // TOC length, unused
        body.extend_from_slice(&TOC_MAGIC.to_le_bytes());
        body.extend_from_slice(&1u32.to_le_bytes()); // TOC id
        body.extend_from_slice(&0u32.to_le_bytes()); // next TOC
        body.extend_from_slice(&(entries.len() as u32).to_le_bytes());
        for (key, offset) in entries {
            body.extend_from_slice(&key.to_le_bytes());
            body.extend_from_slice(&offset.to_le_bytes());
            body.extend_from_slice(&0u32.to_le_bytes());
        }

        let header_size = 48u32;
        let mut data = Vec::new();
        data.extend_from_slice(MAGIC_BOOK);
        data.extend_from_slice(&(header_size + body.len() as u32).to_le_bytes());
        data.extend_from_slice(MAGIC_MARK);
        data.extend_from_slice(&0u32.to_le_bytes());
        data.extend_from_slice(&header_size.to_le_bytes());
        data.resize(header_size as usize, 0);
        data.extend_from_slice(&body);
        data
    }

    #[test]
    fn reads_path_components() {
        let data = make_bookmark(
            &[
                "Users",
                "other",
                "Library",
                "CloudStorage",
                "OneDrive-Contoso",
                "Plan.pdf",
            ],
            None,
        );
        assert_eq!(
            target_path(&data).unwrap(),
            "/Users/other/Library/CloudStorage/OneDrive-Contoso/Plan.pdf"
        );
    }

    #[test]
    fn prefixes_non_root_volume() {
        let data = make_bookmark(&["Projects", "Plan.pdf"], Some("/Volumes/Data/"));
        assert_eq!(
            target_path(&data).unwrap(),
            "/Volumes/Data/Projects/Plan.pdf"
        );
    }

    #[test]
    fn rejects_other_files() {
        assert!(target_path(b"%PDF-1.7 not an alias at all, just some bytes......").is_err());
        assert!(target_path(&[]).is_err());
    }

    #[test]
    fn survives_truncation() {
        let data = make_bookmark(&["Users", "other", "OneDrive", "a.txt"], None);
        for len in 0..data.len() {
            let _ = target_path(&data[..len]);
        }
    }

    /// Real aliases from `make_testalias.sh`, when present. They hold this
    /// Mac's user and tenant names, so they never enter the repo.
    #[test]
    fn reads_local_fixtures() {
        let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../testdata");
        let Ok(entries) = std::fs::read_dir(dir) else {
            return;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() {
                let target = target_path_of_file(&path).unwrap();
                assert!(target.starts_with('/'), "{}: {target}", path.display());
            }
        }
    }
}
