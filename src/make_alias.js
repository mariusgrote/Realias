// Create a genuine Finder alias file at `aliasPath` pointing to `targetPath`,
// using the same Cocoa API Finder itself uses.
// Usage: osascript -l JavaScript make_alias.js <targetPath> <aliasPath>
ObjC.import('Foundation');

function run(argv) {
	if (argv.length !== 2) throw new Error('usage: make_alias.js <target> <alias>');
	var target = $.NSURL.fileURLWithPath($(argv[0]));
	var aliasURL = $.NSURL.fileURLWithPath($(argv[1]));

	var err = Ref();
	var data = target.bookmarkDataWithOptionsIncludingResourceValuesForKeysRelativeToURLError(
		$.NSURLBookmarkCreationSuitableForBookmarkFile, $(), $(), err);
	if (!data.js) throw new Error('could not read target: ' + err[0].localizedDescription.js);

	var ok = $.NSURL.writeBookmarkDataToURLOptionsError(
		data, aliasURL, $.NSURLBookmarkCreationSuitableForBookmarkFile, err);
	if (!ok) throw new Error('could not write alias: ' + err[0].localizedDescription.js);

	return argv[1];
}
