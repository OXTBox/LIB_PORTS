script "LibPorts"
######################################################################################
## LIB_PORTS (18 Nov 2026): the registry of our TCP ports, and "look before you listen".
##   start using stack "<projects>/LIB_PORTS/livecode/lib_ports.livecodescript"
##   Ports.Number("xt3d-bench-mcp")  -> 8770     (from ../ports.tsv)
##   Ports.Name(8770)                -> xt3d-bench-mcp
##   Ports.Row(8770)                 -> array: port name listener started_by token_file clients notes
##   Ports.Listeners(8770)           -> the process ids listening on it, one per line (Windows' netstat)
##   Ports.AllListeners()            -> [port] = process ids, for every listening port (one netstat)
##   Ports.InUse(8770)               -> true when any process listens on it
##   Ports.NextFree()                -> the lowest free port in 8771-8799 for a new server
##   Ports.Answers(8770, 500)        -> true when a connection opens within 500 ms. A listener that does
##                                      not answer is stuck (18 Nov: the plain bench on 8768 listened
##                                      and accepted nothing); a timeout never means "free"
##   Ports.MayListen(8770)           -> empty, or why not (in use; or not in the registry)
## The rules: ../RULES.md. A server calls Ports.MayListen before "accept connections".
######################################################################################

constant kTimeoutMs = 500

local sRows        -- [port] = array of the registry's columns
local sByName      -- [name] = port
local sProbe       -- [socket id] = "open" or "error" while Ports.InUse waits

-------------------------------------------------------------------- the registry

function Ports.File
   local tPath
   put the effective filename of stack "LibPorts" into tPath
   set the itemDelimiter to "/"
   delete item -1 of tPath      -- livecode
   delete item -1 of tPath      -- LIB_PORTS
   return tPath & "/ports.tsv"
end Ports.File

command Ports.Load
   local tText, tLine, tCols, tPort, tRow, tI
   put empty into sRows
   put empty into sByName
   set the cursor to busy
   if there is not a file Ports.File() then return "no registry at" && Ports.File()
   put textDecode(URL ("binfile:" & Ports.File()), "UTF-8") into tText
   replace numToChar(13) with empty in tText
   put "port name listener started_by token_file clients notes" into tCols
   set the itemDelimiter to tab
   repeat for each line tLine in tText
      set the cursor to busy
      if tLine is empty or char 1 of tLine is "#" then next repeat
      put item 1 of tLine into tPort
      if tPort is not an integer then next repeat
      put empty into tRow
      repeat with tI = 1 to 7
         put item tI of tLine into tRow[word tI of tCols]
      end repeat
      put tRow into sRows[tPort]
      put tPort into sByName[item 2 of tLine]
   end repeat
   return empty
end Ports.Load

function Ports.Row pPort
   if sRows is not an array then Ports.Load
   return sRows[pPort]
end Ports.Row

function Ports.Number pName
   if sRows is not an array then Ports.Load
   return sByName[pName]
end Ports.Number

function Ports.Name pPort
   if sRows is not an array then Ports.Load
   return sRows[pPort]["name"]
end Ports.Name

-- every registered port, ascending
function Ports.List
   local tKeys
   if sRows is not an array then Ports.Load
   put the keys of sRows into tKeys
   sort lines of tKeys ascending numeric
   return tKeys
end Ports.List

-------------------------------------------------------------------- is anyone there?

-- every listening TCP port on this PC: [port] = its process ids, one per line. One netstat call.
function Ports.AllListeners
   local tOut, tLine, tAddr, tPort, tAll
   set the cursor to busy
   if the platform is not "Win32" then return empty
   set the hideConsoleWindows to true
   put shell("netstat -ano -p tcp") into tOut
   repeat for each line tLine in tOut
      set the cursor to busy
      if word 4 of tLine is not "LISTENING" then next repeat
      put word 2 of tLine into tAddr
      set the itemDelimiter to ":"
      put item -1 of tAddr into tPort
      if word 5 of tLine is among the lines of tAll[tPort] then next repeat
      if tAll[tPort] is not empty then put return after tAll[tPort]
      put word 5 of tLine after tAll[tPort]
   end repeat
   return tAll
end Ports.AllListeners

-- the process ids listening on pPort, one per line (two lines: two copies, the 18 Nov trouble)
function Ports.Listeners pPort
   local tAll
   if the platform is not "Win32" then
      set the cursor to busy
      return line 1 to -1 of shell("lsof -nP -t -iTCP:" & pPort & " -sTCP:LISTEN 2>/dev/null")
   end if
   put Ports.AllListeners() into tAll
   return tAll[pPort]
end Ports.Listeners

-- the lowest port in 8771-8799 with no registry row and nothing listening on it
function Ports.NextFree pAll
   local tPort
   if sRows is not an array then Ports.Load
   repeat with tPort = 8771 to 8799
      set the cursor to busy
      if tPort is among the lines of the keys of sRows then next repeat
      if pAll[tPort] is not empty then next repeat
      return tPort
   end repeat
   return empty
end Ports.NextFree

function Ports.InUse pPort
   return Ports.Listeners(pPort) is not empty
end Ports.InUse

-- true when a connection to pPort on this PC opens within pMs milliseconds
function Ports.Answers pPort, pMs
   local tSock, tStart, tState
   if pMs is not an integer then put kTimeoutMs into pMs
   put "127.0.0.1:" & pPort & "|portsprobe" & the milliseconds into tSock
   put empty into sProbe[tSock]
   put the milliseconds into tStart
   set the cursor to busy
   open socket to tSock with message "Ports.OnProbeOpen"
   if the result is not empty then
      delete variable sProbe[tSock]
      return false
   end if
   repeat until sProbe[tSock] is not empty or the milliseconds - tStart > pMs
      set the cursor to busy
      wait 20 milliseconds with messages
   end repeat
   put sProbe[tSock] into tState
   if tState is empty then
      -- still connecting: closing it now lets its late error land on the next socket (18 Nov,
      -- error 10038). It is closed when it opens or fails.
      put "abandoned" into sProbe[tSock]
      return false
   end if
   delete variable sProbe[tSock]
   close socket tSock
   return tState is "open"
end Ports.Answers

on Ports.OnProbeOpen pSocket
   if pSocket is not among the lines of the keys of sProbe then exit Ports.OnProbeOpen
   if sProbe[pSocket] is "abandoned" then
      delete variable sProbe[pSocket]
      close socket pSocket
   else
      put "open" into sProbe[pSocket]
   end if
end Ports.OnProbeOpen

on socketError pSocket, pErr
   if pSocket is among the lines of the keys of sProbe then
      if sProbe[pSocket] is "abandoned" then
         delete variable sProbe[pSocket]
      else
         put "error" into sProbe[pSocket]
      end if
   else
      pass socketError
   end if
end socketError

-- RULES.md rule 2: empty when this program may listen on pPort, else why not
function Ports.MayListen pPort
   local tPids
   if Ports.Row(pPort) is not an array then
      return "port" && pPort && "is not in LIB_PORTS/ports.tsv: add its row first"
   end if
   put Ports.Listeners(pPort) into tPids
   if tPids is not empty then
      replace return with ", " in tPids
      return "port" && pPort && "(" & Ports.Name(pPort) & ") is already in use by process" && tPids & ": another copy is running"
   end if
   return empty
end Ports.MayListen
