-- Scroll workload for run-bench.sh -m keys.
-- Sends Page Down to the Galley process identified by pid, then returns.
-- Requires Accessibility permission for whatever runs osascript.

on run argv
	set targetPid to (item 1 of argv) as integer
	set steps to (item 2 of argv) as integer

	tell application "System Events"
		set galley to the first process whose unix id is targetPid
		set frontmost of galley to true
		delay 0.5

		repeat steps times
			key code 121 -- Page Down
			delay 0.15
		end repeat

		-- Go back up so the next trial starts from the same place
		repeat steps times
			key code 116 -- Page Up
			delay 0.05
		end repeat
	end tell
end run
