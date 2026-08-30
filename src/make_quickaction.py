"""Generate the Realias Finder Quick Action (a Services workflow bundle).

Usage: make_quickaction.py <Realias.app> <output .workflow path>

Unlike LaunchServices, the Services menu hands an alias file's own path to the
workflow without resolving it, so the shell action can pass "$@" straight to
realias.py.
"""

import os
import plistlib
import shutil
import sys

MENU_ITEM = "Create Local Alias"
BUNDLE_ID = "io.github.mariusgrote.realias.quickaction"

SHELL_SCRIPT = '''SCRIPT="{script}"
if [ ! -f "$SCRIPT" ]; then
	SCRIPT="/Applications/Realias.app/Contents/Resources/src/realias.py"
fi
REPORT="$(/usr/bin/python3 "$SCRIPT" --report "$@" 2>&1)"
/usr/bin/osascript -e 'on run {{reportText}}
display dialog reportText buttons {{"OK"}} default button 1 with title "Realias" with icon note
end run' "$REPORT"
'''


def info_plist():
    return {
        "CFBundleDisplayName": MENU_ITEM,
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": MENU_ITEM,
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1.0",
        "NSServices": [{
            "NSBackgroundColorName": "background",
            "NSIconName": "NSActionTemplate",
            "NSMenuItem": {"default": MENU_ITEM},
            "NSMessage": "runWorkflowAsService",
            "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
            "NSSendFileTypes": ["public.item"],
            "NSSendTypes": ["NSFilenamesPboardType"],
        }],
    }


def document_wflow(command):
    return {
        "AMApplicationBuild": "528",
        "AMApplicationVersion": "2.10",
        "AMDocumentVersion": "2",
        "actions": [{
            "action": {
                "AMActionVersion": "2.0.3",
                "AMApplication": ["Automator"],
                "AMParameterProperties": {
                    "COMMAND_STRING": {},
                    "CheckedForUserTask": {},
                    "inputMethod": {},
                    "shell": {},
                },
                "AMParameters": {
                    "COMMAND_STRING": command,
                    "CheckedForUserTask": False,
                    "inputMethod": 1,   # pass input as arguments
                    "shell": "/bin/zsh",
                },
                "BundleIdentifier": "com.apple.RunShellScript",
                "CFBundleVersion": "2.0.3",
                "CanShowSelectedItemsWhenRun": False,
                "CanShowWhenRun": True,
                "Category": ["AMCategoryUtilities"],
                "Class Name": "RunShellScriptAction",
                "InputUUID": "6C1A2F34-9E7B-4A5D-8F21-3B0D5E7C9A12",
                "Keywords": ["Shell"],
                "OutputUUID": "8D4B7E29-1C53-4F68-A92B-5E10D3C7F483",
                "UUID": "A1F30D62-47B9-4E85-B6C4-2D98E51A07F4",
                "UnlocalizedApplications": ["Automator"],
                "arguments": {
                    "0": {"default value": 0, "name": "inputMethod",
                          "required": "0", "type": "0", "uuid": "0"},
                    "1": {"default value": False, "name": "CheckedForUserTask",
                          "required": "0", "type": "0", "uuid": "1"},
                    "2": {"default value": "", "name": "source",
                          "required": "0", "type": "0", "uuid": "2"},
                    "3": {"default value": "/bin/zsh", "name": "shell",
                          "required": "0", "type": "0", "uuid": "3"},
                },
                "isViewVisible": 1,
                "location": "309.000000:253.000000",
                "nibPath": "/System/Library/Automator/Run Shell Script.action",
            },
            "isViewVisible": 1,
        }],
        "connectors": {},
        "workflowMetaData": {
            "applicationBundleIDsByPath": {},
            "applicationPaths": {},
            "inputMethodIdentifier": "com.apple.Automator.fileSystemObjects",
            "output": [],
            "serviceApplicationBundleID": "com.apple.finder",
            "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
            "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObjects",
            "serviceOutputTypeIdentifier": "com.apple.Automator.noData",
            "serviceProcessesInput": 0,
            "systemImageName": "NSActionTemplate",
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
        },
    }


def main(app_path, out_path):
    script = os.path.join(os.path.abspath(app_path),
                          "Contents", "Resources", "src", "realias.py")
    contents = os.path.join(out_path, "Contents")
    if os.path.exists(out_path):
        shutil.rmtree(out_path)
    os.makedirs(contents)

    with open(os.path.join(contents, "Info.plist"), "wb") as f:
        plistlib.dump(info_plist(), f)
    with open(os.path.join(contents, "document.wflow"), "wb") as f:
        plistlib.dump(document_wflow(SHELL_SCRIPT.format(script=script)), f)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
