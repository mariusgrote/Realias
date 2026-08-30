import Foundation

/// Create genuine Finder alias files with the same Cocoa API Finder uses.
enum AliasFile {
	static func create(target: String, at aliasPath: String) throws {
		let targetURL = URL(fileURLWithPath: target)
		let data: Data
		do {
			data = try targetURL.bookmarkData(options: .suitableForBookmarkFile,
				includingResourceValuesForKeys: nil, relativeTo: nil)
		} catch {
			throw AliasError("could not read target: \(error.localizedDescription)")
		}
		do {
			try URL.writeBookmarkData(data, to: URL(fileURLWithPath: aliasPath))
		} catch {
			throw AliasError("could not write alias: \(error.localizedDescription)")
		}
	}
}
