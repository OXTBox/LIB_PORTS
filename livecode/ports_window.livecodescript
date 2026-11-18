script "PortsWindowScript"
######################################################################################
## STACK SCRIPT of "Ports" (LIB_PORTS/Ports.oxtstack, 18 Nov 2026): the settings window for our ports.
## Built from this file (set the script of stack "Ports" to it); edit here, then build again.
##   Table   every port in ports.tsv: who listens now (process ids), does it answer, what's wrong
##   Click   a row: its registry entry below
##   Close older copy   when two processes listen on one port: ends the one started first (asks you)
##   Edit registry      opens ports.tsv in Notepad; Refresh reads it again
## Library: livecode/lib_ports.livecodescript (Ports.*). Rules: RULES.md.
######################################################################################

local sPorts    -- line n of the table = sPorts[n]
local sAll      -- [port] = listening process ids, from the last Refresh

on openStack
   PW.UseLib
   send "PW.Refresh" to me in 50 milliseconds     -- the window draws first
end openStack

function PW.Folder
   local tPath
   put the effective filename of this stack into tPath
   set the itemDelimiter to "/"
   delete item -1 of tPath
   return tPath
end PW.Folder

command PW.UseLib
   local tLib
   if "LibPorts" is among the lines of the stacksInUse then exit PW.UseLib
   put PW.Folder() & "/livecode/lib_ports.livecodescript" into tLib
   set the cursor to busy
   if there is a file tLib then start using stack tLib
end PW.UseLib

command PW.Say pText
   put pText into field "Status" of stack "Ports"
end PW.Say

-------------------------------------------------------------------- the table

on PW.Refresh
   local tPort, tRow, tPids, tState, tOut, tN, tProblems
   PW.UseLib
   set the defaultStack to "Ports"
   PW.Say "Asking Windows who listens (netstat)..."
   set the cursor to busy
   Ports.Load
   put Ports.AllListeners() into sAll
   put empty into sPorts
   put 0 into tN
   put 0 into tProblems
   repeat for each line tPort in Ports.List()
      set the cursor to busy
      put Ports.Row(tPort) into tRow
      put sAll[tPort] into tPids
      if tPids is empty then
         put "free" into tState
      else if the number of lines of tPids > 1 then
         put "TWO COPIES: close the older" into tState
         add 1 to tProblems
      else if Ports.Answers(tPort, 500) then
         put "running" into tState
      else if Ports.Answers(tPort, 2000) then     -- the first socket of a session is slow to open
         put "running" into tState
      else
         put "listening, NOT ANSWERING (stuck?)" into tState
         add 1 to tProblems
      end if
      replace return with ", " in tPids
      add 1 to tN
      put tPort into sPorts[tN]
      put tPort & tab & tRow["name"] & tab & tPids & tab & tState & return after tOut
   end repeat
   delete the last char of tOut
   put tOut into field "Table"
   put empty into field "Detail"
   PW.Buttons
   PW.Say tN && "ports in the registry;" && tProblems && "need attention. Next free port for a new server:" && Ports.NextFree(sAll) & \
         ". Refreshed" && the long time & "."
end PW.Refresh

on PW.Clicked pLine
   local tPort, tRow, tText, tKey, tPids
   if pLine is not an integer then exit PW.Clicked
   put sPorts[pLine] into tPort
   put Ports.Row(tPort) into tRow
   repeat for each item tKey in "port,name,listener,started_by,token_file,clients,notes"
      put tKey & ":" & tab & tRow[tKey] & return after tText
   end repeat
   put sAll[tPort] into tPids
   replace return with ", " in tPids
   put "listening now:" & tab & tPids after tText
   put tText into field "Detail" of stack "Ports"
   PW.Buttons
end PW.Clicked

on PW.Buttons
   local tLine
   put the hilitedLine of field "Table" of stack "Ports" into tLine
   if tLine is an integer then
      set the enabled of button "CloseOlder" of stack "Ports" to (the number of lines of sAll[sPorts[tLine]] > 1)
   else
      set the enabled of button "CloseOlder" of stack "Ports" to false
   end if
end PW.Buttons

-------------------------------------------------------------------- close the older copy

-- [pid] = its start time as yyyymmddhhmmss, from wmic
function PW.StartTimes pPids
   local tWhere, tOut, tLine, tTimes, tPid
   repeat for each line tPid in pPids
      if tWhere is not empty then put " or " after tWhere
      put "ProcessId=" & tPid after tWhere
   end repeat
   set the cursor to busy
   set the hideConsoleWindows to true
   put shell("wmic process where " & quote & tWhere & quote & " get ProcessId,CreationDate,Name /format:csv") into tOut
   replace numToChar(13) with empty in tOut
   set the itemDelimiter to ","
   repeat for each line tLine in tOut
      set the cursor to busy
      if item 4 of tLine is not an integer then next repeat
      put char 1 to 14 of item 2 of tLine into tTimes[item 4 of tLine]["start"]
      put item 3 of tLine into tTimes[item 4 of tLine]["name"]
   end repeat
   return tTimes
end PW.StartTimes

on PW.CloseOlder
   local tLine, tPort, tPids, tTimes, tOld, tPid, tWhen, tOut
   put the hilitedLine of field "Table" of stack "Ports" into tLine
   if tLine is not an integer then exit PW.CloseOlder
   put sPorts[tLine] into tPort
   put sAll[tPort] into tPids
   if the number of lines of tPids < 2 then exit PW.CloseOlder
   PW.Say "Asking Windows when each copy started (wmic)..."
   put PW.StartTimes(tPids) into tTimes
   repeat for each line tPid in tPids
      set the cursor to busy
      if tTimes[tPid]["start"] is empty then next repeat
      if tOld is empty or tTimes[tPid]["start"] < tTimes[tOld]["start"] then put tPid into tOld
   end repeat
   if tOld is empty then
      PW.Say "Could not tell which copy is older; close one by hand (Task Manager)."
      exit PW.CloseOlder
   end if
   put tTimes[tOld]["start"] into tWhen
   put char 9 to 10 of tWhen & ":" & char 11 to 12 of tWhen & ":" & char 13 to 14 of tWhen into tWhen
   answer "Port" && tPort && "(" & Ports.Name(tPort) & ") has" && the number of lines of tPids && "copies." & return & \
         "Close the older one: process" && tOld && "(" & tTimes[tOld]["name"] & "), started" && tWhen & "?" with "Cancel" or "Close it"
   if it is not "Close it" then
      PW.Say "Nothing closed."
      exit PW.CloseOlder
   end if
   set the cursor to busy
   set the hideConsoleWindows to true
   put shell("taskkill /PID " & tOld & " /F") into tOut
   PW.Say word 1 to -1 of tOut
   PW.Refresh
end PW.CloseOlder

on PW.OpenRegistry
   set the cursor to busy
   open process ("notepad.exe " & quote & PW.Win(PW.Folder() & "/ports.tsv") & quote) for neither
   PW.Say "ports.tsv is open in Notepad: save it there, then Refresh."
end PW.OpenRegistry

function PW.Win pPath
   replace "/" with "\" in pPath
   return pPath
end PW.Win
