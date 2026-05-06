on run argv
    set appName to item 1 of argv

    tell application "System Events"
        set isRunning to (count of (every process whose name is appName)) > 0
    end tell

    if isRunning then
        tell application "System Events"
            set appProcess to first process whose name is appName
            if visible of appProcess and frontmost of appProcess then
                -- Hide the application
                set visible of appProcess to false
                log "Hiding " & appName
            else
                -- Show the application
                run script "tell application \"" & appName & "\" to activate"
                log "Showing " & appName
            end if
        end tell
    else
        -- Launch the application if not running
        run script "tell application \"" & appName & "\" to activate"
        delay 0.2 -- Give it more time to launch
        log "Launching " & appName
    end if
end run
