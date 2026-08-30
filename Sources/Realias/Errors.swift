import Foundation

/// Every failure Realias reports is a sentence meant for the user, so the
/// error types differ only in what they let `localize` catch separately.
protocol RealiasError: Error, CustomStringConvertible {
	var message: String { get }
}

extension RealiasError {
	var description: String { message }
	var localizedDescription: String { message }
}

struct BookmarkError: RealiasError {
	let message: String
	init(_ message: String) { self.message = message }
}

struct RemapError: RealiasError {
	let message: String
	init(_ message: String) { self.message = message }
}

struct ConfigError: RealiasError {
	let message: String
	init(_ message: String) { self.message = message }
}

struct AliasError: RealiasError {
	let message: String
	init(_ message: String) { self.message = message }
}
