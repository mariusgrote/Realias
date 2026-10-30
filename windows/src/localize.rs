//! Turn an alias made on a Mac into a shortcut that works on this PC.
//!
//! Reads the alias without resolving it, rewrites the OneDrive prefix to this
//! PC's, and drops a `.lnk` next to the original. The original file is never
//! touched, so it keeps working on the Mac that created it.

use std::path::{Path, PathBuf};

use crate::error::Error;
use crate::settings::{NameSource, Settings};
use crate::{bookmark, remap, shortcut};

/// The name the new shortcut gets when nothing of that name is in the way.
/// The source's full name is kept, extension included, because Explorer
/// hides only the `.lnk`.
pub fn new_shortcut_name(original: &Path, target: &Path, settings: &Settings) -> String {
    format!(
        "{}{}.lnk",
        source_name(original, target, settings),
        settings.suffix
    )
}

fn source_name(original: &Path, target: &Path, settings: &Settings) -> String {
    let source = match settings.name_source {
        NameSource::Alias => original,
        NameSource::Target => target,
    };
    source
        .file_name()
        .unwrap_or(source.as_os_str())
        .to_string_lossy()
        .into_owned()
}

/// Pick a free path next to `original`, per the configured name source.
pub fn new_shortcut_path(
    original: &Path,
    target: &Path,
    settings: &Settings,
    exists: impl Fn(&Path) -> bool,
) -> PathBuf {
    let folder = original.parent().unwrap_or(Path::new(""));
    let mut candidate = folder.join(new_shortcut_name(original, target, settings));
    let stem = source_name(original, target, settings);
    let mut n = 2;
    while exists(&candidate) {
        candidate = folder.join(format!("{stem}{} {n}.lnk", settings.suffix));
        n += 1;
    }
    candidate
}

/// Create the Windows twin of `alias_file`; return the new shortcut's path.
pub fn run(alias_file: &Path, settings: &Settings) -> Result<PathBuf, Error> {
    let alias_file = std::path::absolute(alias_file).unwrap_or_else(|_| alias_file.to_path_buf());
    if !alias_file.is_file() {
        return Err(Error::new(format!("not a file: {}", alias_file.display())));
    }

    let name = alias_file
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    let foreign_target = bookmark::target_path_of_file(&alias_file)
        .map_err(|_| Error::new(format!("not a macOS alias file: {name}")))?;

    let target = remap::remap(&foreign_target)?;
    let shortcut = new_shortcut_path(&alias_file, &target, settings, Path::exists);
    shortcut::create(&target, &shortcut)?;
    Ok(shortcut)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn settings(name_source: NameSource) -> Settings {
        Settings {
            name_source,
            ..Settings::default()
        }
    }

    #[test]
    fn names_after_alias_or_target() {
        let original = Path::new("C:/OneDrive/Plan.pdf alias");
        let target = Path::new("C:/OneDrive/Projects/Plan.pdf");
        assert_eq!(
            new_shortcut_name(original, target, &settings(NameSource::Alias)),
            "Plan.pdf alias (Windows).lnk"
        );
        assert_eq!(
            new_shortcut_name(original, target, &settings(NameSource::Target)),
            "Plan.pdf (Windows).lnk"
        );
    }

    #[test]
    fn numbers_taken_names() {
        let original = Path::new("C:/OneDrive/Docs");
        let target = Path::new("C:/OneDrive/Documents");
        let taken = [
            Path::new("C:/OneDrive/Docs (Windows).lnk"),
            Path::new("C:/OneDrive/Docs (Windows) 2.lnk"),
        ];
        let path = new_shortcut_path(original, target, &settings(NameSource::Alias), |p| {
            taken.contains(&p)
        });
        assert_eq!(path, Path::new("C:/OneDrive/Docs (Windows) 3.lnk"));
    }
}
