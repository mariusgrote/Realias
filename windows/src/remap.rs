//! Map a POSIX path recorded on a Mac onto this PC's OneDrive root.
//!
//! Counterpart of `Sources/Realias/Remap.swift`. The matching logic is pure
//! and takes the roots and an existence check as arguments, so it is tested
//! on any platform; only `local_roots` looks at the machine.

use std::path::{Path, PathBuf};

use unicode_normalization::UnicodeNormalization;

use crate::error::Error;

/// "OneDrive - Contoso Ltd" and "OneDrive-ContosoLtd" are the same library
/// under different layouts, so compare names with spaces/dashes stripped.
fn normalized(name: &str) -> String {
    name.nfc()
        .flat_map(char::to_lowercase)
        .filter(|c| !c.is_whitespace() && *c != '-' && *c != '_')
        .collect()
}

fn is_onedrive(name: &str) -> bool {
    normalized(name).starts_with("onedrive")
}

/// Return (OneDrive folder name, path components below it) for a Mac path.
pub fn split_onedrive(path: &str) -> Result<(String, Vec<String>), Error> {
    let parts: Vec<&str> = path.split('/').filter(|p| !p.is_empty()).collect();
    parts
        .iter()
        .position(|p| is_onedrive(p))
        .map(|i| {
            let relative = parts[i + 1..].iter().map(|s| s.to_string()).collect();
            (parts[i].to_string(), relative)
        })
        .ok_or_else(|| Error::new(format!("path is not inside OneDrive:\n{path}")))
}

/// Rewrite a Mac OneDrive path onto one of `roots`, preferring the root
/// whose name matches the Mac's OneDrive folder.
pub fn remap_onto(
    path: &str,
    roots: &[PathBuf],
    exists: impl Fn(&Path) -> bool,
) -> Result<PathBuf, Error> {
    let (foreign_root, relative) = split_onedrive(path)?;
    if roots.is_empty() {
        return Err(Error::new("no OneDrive folder found on this PC"));
    }

    let matching: Vec<&PathBuf> = roots
        .iter()
        .filter(|root| {
            root.file_name()
                .is_some_and(|n| normalized(&n.to_string_lossy()) == normalized(&foreign_root))
        })
        .collect();
    let candidates: Vec<&PathBuf> = if matching.is_empty() {
        roots.iter().collect()
    } else {
        matching
    };

    // macOS may record names decomposed (NFD); Windows stores them composed.
    let spellings = [
        relative.clone(),
        relative.iter().map(|c| c.nfc().collect()).collect(),
    ];
    for root in &candidates {
        for components in &spellings {
            let candidate = components.iter().fold((*root).clone(), |p, c| p.join(c));
            if exists(&candidate) {
                return Ok(candidate);
            }
        }
    }

    // Nothing exists; report against the best-guess root so the message is useful.
    let guess = spellings[1]
        .iter()
        .fold(candidates[0].clone(), |p, c| p.join(c));
    Err(Error::new(format!(
        "target not found on this PC:\n{}",
        guess.display()
    )))
}

/// Rewrite a Mac OneDrive path to the equivalent path on this PC.
pub fn remap(path: &str) -> Result<PathBuf, Error> {
    remap_onto(path, &local_roots(), Path::exists)
}

/// Every OneDrive root on this PC: those the OneDrive client advertises,
/// then any `OneDrive…` folder in the user profile.
pub fn local_roots() -> Vec<PathBuf> {
    let mut roots: Vec<PathBuf> = Vec::new();
    let mut add = |path: PathBuf| {
        if path.is_dir() && !roots.contains(&path) {
            roots.push(path);
        }
    };

    for var in ["OneDriveCommercial", "OneDriveConsumer", "OneDrive"] {
        if let Some(value) = std::env::var_os(var) {
            add(PathBuf::from(value));
        }
    }
    for folder in registry_roots() {
        add(folder);
    }
    if let Some(profile) = std::env::var_os("USERPROFILE") {
        let mut names: Vec<_> = std::fs::read_dir(profile)
            .into_iter()
            .flatten()
            .flatten()
            .filter(|e| is_onedrive(&e.file_name().to_string_lossy()))
            .map(|e| e.path())
            .collect();
        names.sort();
        names.into_iter().for_each(&mut add);
    }
    roots
}

/// `UserFolder` of every account under `HKCU\Software\Microsoft\OneDrive\Accounts`.
#[cfg(windows)]
fn registry_roots() -> Vec<PathBuf> {
    use winreg::RegKey;
    use winreg::enums::HKEY_CURRENT_USER;

    let Ok(accounts) =
        RegKey::predef(HKEY_CURRENT_USER).open_subkey(r"Software\Microsoft\OneDrive\Accounts")
    else {
        return Vec::new();
    };
    accounts
        .enum_keys()
        .flatten()
        .filter_map(|name| accounts.open_subkey(name).ok())
        .filter_map(|account| account.get_value::<String, _>("UserFolder").ok())
        .map(PathBuf::from)
        .collect()
}

#[cfg(not(windows))]
fn registry_roots() -> Vec<PathBuf> {
    Vec::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    const MAC_PATH: &str =
        "/Users/other/Library/CloudStorage/OneDrive-ContosoLtd/Projects/Plan.pdf";

    fn roots() -> Vec<PathBuf> {
        vec![
            PathBuf::from("C:/Users/me/OneDrive - Personal"),
            PathBuf::from("C:/Users/me/OneDrive - Contoso Ltd"),
        ]
    }

    #[test]
    fn splits_both_mac_layouts() {
        let (root, relative) = split_onedrive(MAC_PATH).unwrap();
        assert_eq!(root, "OneDrive-ContosoLtd");
        assert_eq!(relative, ["Projects", "Plan.pdf"]);

        let (root, _) = split_onedrive("/Users/other/OneDrive - Contoso Ltd/a.txt").unwrap();
        assert_eq!(root, "OneDrive - Contoso Ltd");
    }

    #[test]
    fn rejects_paths_outside_onedrive() {
        assert!(split_onedrive("/Users/other/Documents/a.txt").is_err());
    }

    #[test]
    fn prefers_matching_root() {
        let expected = Path::new("C:/Users/me/OneDrive - Contoso Ltd")
            .join("Projects")
            .join("Plan.pdf");
        let found = remap_onto(MAC_PATH, &roots(), |p| p == expected).unwrap();
        assert_eq!(found, expected);
    }

    #[test]
    fn falls_back_to_any_root() {
        let expected = Path::new("C:/Users/me/OneDrive - Personal")
            .join("Projects")
            .join("Plan.pdf");
        let path = "/Users/other/Library/CloudStorage/OneDrive-Fabrikam/Projects/Plan.pdf";
        let found = remap_onto(path, &roots(), |p| p == expected).unwrap();
        assert_eq!(found, expected);
    }

    #[test]
    fn finds_composed_spelling_of_decomposed_name() {
        let decomposed = "/Users/other/OneDrive-ContosoLtd/Bu\u{0308}ro/a.txt";
        let expected = Path::new("C:/Users/me/OneDrive - Contoso Ltd")
            .join("B\u{00fc}ro")
            .join("a.txt");
        let found = remap_onto(decomposed, &roots(), |p| p == expected).unwrap();
        assert_eq!(found, expected);
    }

    #[test]
    fn reports_best_guess_when_missing() {
        let error = remap_onto(MAC_PATH, &roots(), |_| false).unwrap_err();
        assert!(
            error.to_string().contains("OneDrive - Contoso Ltd"),
            "{error}"
        );
    }

    #[test]
    fn reports_missing_onedrive() {
        assert!(remap_onto(MAC_PATH, &[], |_| true).is_err());
    }
}
