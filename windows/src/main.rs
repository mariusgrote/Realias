// A GUI-subsystem binary, so the Explorer menu entry opens no console window.
// The command line reattaches to its parent's console in `main`.
#![cfg_attr(not(test), windows_subsystem = "windows")]

mod bookmark;
mod error;
mod localize;
mod remap;
mod settings;
mod shortcut;

use std::path::{Path, PathBuf};
use std::process::ExitCode;

use settings::Settings;

const USAGE: &str = "\
usage: realias [--report] <alias file> [...]
       realias --gui <alias file> [...]      show the report in a dialog
       realias --target-of <alias file> [...] print the recorded path
       realias --onedrive-roots               list this PC's OneDrive roots
       realias --install | --uninstall        add/remove the Explorer menu entry
       realias --version";

const VERSION: &str = match option_env!("REALIAS_VERSION") {
    Some(version) => version,
    None => env!("CARGO_PKG_VERSION"),
};

fn main() -> ExitCode {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    if arguments.first().map(String::as_str) != Some("--gui") {
        attach_console();
    }

    match arguments.first().map(String::as_str) {
        Some("--gui") => gui(&arguments[1..]),
        Some("--target-of") => target_of(&arguments[1..]),
        Some("--onedrive-roots") => {
            for root in remap::local_roots() {
                println!("{}", root.display());
            }
            ExitCode::SUCCESS
        }
        Some("--install") => result(install::install()),
        Some("--uninstall") => result(install::uninstall()),
        Some("--version") => {
            println!("realias {VERSION}");
            ExitCode::SUCCESS
        }
        Some("--help" | "-h") | None => fail(USAGE, 2),
        Some(_) => localize_all(&arguments),
    }
}

struct Outcome {
    text: String,
    failed: bool,
}

/// Run over `paths` and format the summary the dialog shows.
fn report(paths: &[String]) -> Outcome {
    let settings = Settings::load();
    let mut lines = Vec::new();
    let mut failed = false;
    for path in paths {
        let name = file_name(Path::new(path));
        match localize::run(Path::new(path), &settings) {
            Ok(shortcut) => lines.push(format!("OK  {name}\n    -> {}", file_name(&shortcut))),
            Err(error) => {
                failed = true;
                let message = error.to_string().replace('\n', "\n    ");
                lines.push(format!("--  {name}\n    {message}"));
            }
        }
    }
    Outcome {
        text: lines.join("\n\n"),
        failed,
    }
}

fn localize_all(arguments: &[String]) -> ExitCode {
    let report_mode = arguments.iter().any(|a| a == "--report");
    let paths: Vec<String> = arguments
        .iter()
        .filter(|a| *a != "--report")
        .cloned()
        .collect();
    if paths.is_empty() {
        return fail(USAGE, 2);
    }

    // In report mode the caller shows the text itself, so always exit 0.
    if report_mode {
        println!("{}", report(&paths).text);
        return ExitCode::SUCCESS;
    }

    let settings = Settings::load();
    let mut status = ExitCode::SUCCESS;
    for path in &paths {
        match localize::run(Path::new(path), &settings) {
            Ok(shortcut) => println!("{}", shortcut.display()),
            Err(error) => status = fail(&format!("{}: {error}", file_name(Path::new(path))), 1),
        }
    }
    status
}

fn target_of(paths: &[String]) -> ExitCode {
    if paths.is_empty() {
        return fail(USAGE, 2);
    }
    let mut status = ExitCode::SUCCESS;
    for path in paths {
        match bookmark::target_path_of_file(Path::new(path)) {
            Ok(target) => println!("{target}"),
            Err(error) => status = fail(&format!("{}: {error}", file_name(Path::new(path))), 1),
        }
    }
    status
}

fn gui(paths: &[String]) -> ExitCode {
    if paths.is_empty() {
        message_box(USAGE, true);
        return ExitCode::from(2);
    }
    let outcome = report(paths);
    message_box(&outcome.text, outcome.failed);
    ExitCode::SUCCESS
}

fn file_name(path: &Path) -> String {
    path.file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.display().to_string())
}

fn result(outcome: Result<(), error::Error>) -> ExitCode {
    match outcome {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => fail(&error.to_string(), 1),
    }
}

fn fail(message: &str, status: u8) -> ExitCode {
    eprintln!("{message}");
    ExitCode::from(status)
}

fn exe_path() -> Result<PathBuf, error::Error> {
    std::env::current_exe()
        .map_err(|e| error::Error::new(format!("could not locate realias.exe: {e}")))
}

#[cfg(windows)]
fn attach_console() {
    use windows::Win32::System::Console::{ATTACH_PARENT_PROCESS, AttachConsole};
    // Fails when there is no parent console, e.g. launched from Explorer.
    let _ = unsafe { AttachConsole(ATTACH_PARENT_PROCESS) };
}

#[cfg(not(windows))]
fn attach_console() {}

#[cfg(windows)]
fn message_box(text: &str, failed: bool) {
    use windows::Win32::UI::WindowsAndMessaging::{
        MB_ICONINFORMATION, MB_ICONWARNING, MB_OK, MessageBoxW,
    };
    use windows::core::HSTRING;

    let icon = if failed {
        MB_ICONWARNING
    } else {
        MB_ICONINFORMATION
    };
    unsafe {
        MessageBoxW(
            None,
            &HSTRING::from(text),
            &HSTRING::from("Realias"),
            MB_OK | icon,
        );
    }
}

#[cfg(not(windows))]
fn message_box(text: &str, _failed: bool) {
    println!("{text}");
}

/// The Explorer context-menu entry, per user, so no admin rights are needed.
///
/// Registered on `*` because alias names like `Plan.pdf alias` carry no
/// usable extension. Windows 11 lists it under "Show more options".
mod install {
    use crate::error::Error;

    #[cfg(windows)]
    const MENU_KEY: &str = r"Software\Classes\*\shell\Realias";

    #[cfg(windows)]
    pub fn install() -> Result<(), Error> {
        use winreg::RegKey;
        use winreg::enums::HKEY_CURRENT_USER;

        let exe = crate::exe_path()?;
        let exe = exe.display();
        let fail = |e: std::io::Error| Error::new(format!("could not write registry: {e}"));
        let (menu, _) = RegKey::predef(HKEY_CURRENT_USER)
            .create_subkey(MENU_KEY)
            .map_err(fail)?;
        menu.set_value("", &"Create Windows Shortcut")
            .map_err(fail)?;
        menu.set_value("Icon", &format!("\"{exe}\",0"))
            .map_err(fail)?;
        let (command, _) = menu.create_subkey("command").map_err(fail)?;
        command
            .set_value("", &format!("\"{exe}\" --gui \"%1\""))
            .map_err(fail)?;
        println!("Explorer menu entry installed for {exe}");
        Ok(())
    }

    #[cfg(windows)]
    pub fn uninstall() -> Result<(), Error> {
        use winreg::RegKey;
        use winreg::enums::HKEY_CURRENT_USER;

        match RegKey::predef(HKEY_CURRENT_USER).delete_subkey_all(MENU_KEY) {
            Ok(()) => println!("Explorer menu entry removed"),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(Error::new(format!("could not write registry: {e}"))),
        }
        Ok(())
    }

    #[cfg(not(windows))]
    pub fn install() -> Result<(), Error> {
        crate::exe_path()?;
        Err(Error::new("--install is only available on Windows"))
    }

    #[cfg(not(windows))]
    pub fn uninstall() -> Result<(), Error> {
        Err(Error::new("--uninstall is only available on Windows"))
    }
}
