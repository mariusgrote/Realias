//! Write Windows shortcut (`.lnk`) files through the Shell's own `IShellLinkW`,
//! the same way Explorer's "Create shortcut" does.

use std::path::Path;

use crate::error::Error;

#[cfg(windows)]
pub fn create(target: &Path, at: &Path) -> Result<(), Error> {
    use windows::Win32::System::Com::{
        CLSCTX_INPROC_SERVER, COINIT_APARTMENTTHREADED, CoCreateInstance, CoInitializeEx,
        IPersistFile,
    };
    use windows::Win32::UI::Shell::{IShellLinkW, ShellLink};
    use windows::core::{HSTRING, Interface};

    let fail = |e: windows::core::Error| Error::new(format!("could not write shortcut: {e}"));
    unsafe {
        // S_FALSE (already initialised on this thread) counts as success.
        CoInitializeEx(None, COINIT_APARTMENTTHREADED)
            .ok()
            .map_err(fail)?;
        let link: IShellLinkW =
            CoCreateInstance(&ShellLink, None, CLSCTX_INPROC_SERVER).map_err(fail)?;
        link.SetPath(&HSTRING::from(target.as_os_str()))
            .map_err(fail)?;
        if let Some(folder) = target.parent().filter(|_| target.is_file()) {
            link.SetWorkingDirectory(&HSTRING::from(folder.as_os_str()))
                .map_err(fail)?;
        }
        let file: IPersistFile = link.cast().map_err(fail)?;
        file.Save(&HSTRING::from(at.as_os_str()), true)
            .map_err(fail)?;
    }
    Ok(())
}

#[cfg(not(windows))]
pub fn create(_target: &Path, _at: &Path) -> Result<(), Error> {
    Err(Error::new("shortcuts can only be written on Windows"))
}
