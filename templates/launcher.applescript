on run
  my dispatchEvent("run", "")
end run

on reopen
  my dispatchEvent("run", "")
end reopen

on open theItems
  repeat with oneItem in theItems
    my dispatchEvent("file", POSIX path of oneItem)
  end repeat
end open

on open location thisURL
  my dispatchEvent("url", thisURL)
end open location

on dispatchEvent(kind, value)
  set monitorPath to "__MONITOR_PATH__"
  set commandText to quoted form of monitorPath & " event " & quoted form of kind
  if value is not "" then
    set commandText to commandText & space & quoted form of value
  end if
  do shell script "/bin/sh -c " & quoted form of (commandText & " >/dev/null 2>&1 &")
end dispatchEvent
