//! User settings, kept under `HKCU\Software\Realias`.
//!
//! Anything unset falls back to the defaults, so there is nothing to create
//! on first use. Edit them with `reg`:
//!
//!     reg add HKCU\Software\Realias /v Suffix /t REG_SZ /d " (PC)" /f
//!     reg add HKCU\Software\Realias /v NameSource /t REG_SZ /d target /f

/// Which name the new shortcut is built from.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NameSource {
    /// The name of the original alias file.
    Alias,
    /// The name of the item the alias points at.
    // Only the registry sets it, and that exists on Windows alone.
    #[cfg_attr(not(windows), allow(dead_code))]
    Target,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Settings {
    pub suffix: String,
    pub name_source: NameSource,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            suffix: " (Windows)".to_string(),
            name_source: NameSource::Alias,
        }
    }
}

#[cfg(windows)]
const REGISTRY_KEY: &str = r"Software\Realias";

impl Settings {
    #[cfg(windows)]
    pub fn load() -> Settings {
        use winreg::RegKey;
        use winreg::enums::HKEY_CURRENT_USER;

        let mut settings = Settings::default();
        let Ok(key) = RegKey::predef(HKEY_CURRENT_USER).open_subkey(REGISTRY_KEY) else {
            return settings;
        };
        if let Ok(suffix) = key.get_value::<String, _>("Suffix") {
            settings.suffix = suffix;
        }
        match key.get_value::<String, _>("NameSource").as_deref() {
            Ok("alias") => settings.name_source = NameSource::Alias,
            Ok("target") => settings.name_source = NameSource::Target,
            _ => {}
        }
        settings
    }

    #[cfg(not(windows))]
    pub fn load() -> Settings {
        Settings::default()
    }
}
