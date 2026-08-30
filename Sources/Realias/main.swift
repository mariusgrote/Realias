import AppKit

// LaunchServices appends a process serial number when the bundle is opened
// from Finder; everything else on the command line is ours.
let arguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }

if arguments.isEmpty {
	let delegate = AppDelegate()
	let app = NSApplication.shared
	app.delegate = delegate
	app.run()
	exit(0)
}

exit(CLI.run(Array(arguments)))
