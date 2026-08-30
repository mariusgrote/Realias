-- Realias: rebuild an alias made on another Mac so it works on this one.
--
-- Use it by selecting the alias file (or files) in Finder and then launching
-- this app. Dropping files on the app is supported but rarely useful: macOS
-- resolves an alias before handing it over, which is exactly what fails for a
-- foreign alias.

on run
	try
		set selectedPaths to my finderSelection()
	on error errorMessage
		my logError("reading Finder selection: " & errorMessage)
		display dialog "Realias could not read the Finder selection:" & return & return & errorMessage buttons {"OK"} default button 1 with title "Realias" with icon stop
		return
	end try
	if selectedPaths is {} then
		display dialog "Select the alias file (or files) in Finder, then start Realias again." buttons {"OK"} default button 1 with title "Realias" with icon note
		return
	end if
	my localize(selectedPaths)
end run

on open droppedItems
	set droppedPaths to {}
	repeat with anItem in droppedItems
		set end of droppedPaths to POSIX path of (anItem as text)
	end repeat
	my localize(droppedPaths)
end open

-- Read Finder's selection as plain paths. Coercing an item to `alias` would
-- resolve the very alias files we need to inspect by hand, so build the path
-- from the container and the name instead.
on finderSelection()
	set selectedPaths to {}
	tell application "Finder"
		repeat with anItem in (get selection)
			try
				set end of selectedPaths to POSIX path of ((container of anItem as text) & (name of anItem))
			end try
		end repeat
	end tell
	return selectedPaths
end finderSelection

on localize(itemPaths)
	try
		set scriptPath to POSIX path of ((path to me as text) & "Contents:Resources:src:realias.py")
		set shellCommand to "/usr/bin/python3 " & quoted form of scriptPath & " --report"
		repeat with aPath in itemPaths
			set shellCommand to shellCommand & " " & quoted form of (aPath as text)
		end repeat
		set reportText to do shell script shellCommand
	on error errorMessage
		my logError(errorMessage)
		display dialog errorMessage buttons {"OK"} default button 1 with title "Realias" with icon stop
		return
	end try

	display dialog reportText buttons {"OK"} default button 1 with title "Realias" with icon note
end localize

-- Failures inside an app bundle are otherwise invisible; see
-- ~/Library/Logs/Realias.log
on logError(theText)
	try
		do shell script "echo " & quoted form of ((theText as text)) & " >> ~/Library/Logs/Realias.log"
	end try
end logError
