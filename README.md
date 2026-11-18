# LIB_PORTS

Every TCP port our programs listen on: one registry, the rules for using ports, and the checks.
Started 18 Nov 2026, after two xt3d games benches both listened on 8770 and froze the Game Browser.

| File | What |
|---|---|
| `ports.tsv` | The registry: port, name, who listens, which script starts it, its token file, who connects to it |
| `RULES.md` | The six rules: register first, look before you listen, clients never hang the interface, the busy cursor, one copy per port, other programs' ports listed too |
| `livecode/lib_ports.livecodescript` | `Ports.Number(name)`, `Ports.Name(port)`, `Ports.Listeners(port)` (process ids, from netstat), `Ports.Answers(port, ms)`, `Ports.MayListen(port)` |
| `tools/ports_check.py` | `live`: who listens now, with duplicates flagged. `scan`: port numbers in our code that have no registry row |

    python3 -I tools/ports_check.py live
    python3 -I tools/ports_check.py scan

## Lessons from 18 Nov

- On Windows, LiveCode's `accept connections on port` succeeds even when another program already listens
  there. Both copies listen, and each new connection goes to either one. `the result` stays empty.
- A listener that never accepts still looks "in use" to netstat, while a connection test just times out.
  So a timeout never means the port is free. `Ports.Listeners` asks Windows; `Ports.Answers` asks the program.
- `shell()` blocks the whole interface. A 15-second `curl` health check is 15 seconds of frozen window.

## Done on 18 Nov

- LIB_MCP `DevServer.Start` checks the port first (branch `one-copy-per-port`). A second copy gets a
  result beginning `DevServer: IN USE:`, leaves the token file alone, and the three launchers close it.
- The Game Browser talks to the bench over its own socket (`GB.Http`) and starts programs with
  `open process`. No `shell`, so no frozen window (LIB_DEV branch `game-browser-no-freeze`).

## The window: Ports.oxtstack

Open `Ports.oxtstack` in OXT-Beyond. It shows every port in the registry: who listens now (process ids),
whether it answers, and what needs attention ("TWO COPIES", "listening, NOT ANSWERING"). Click a row to see
its registry entry. **Close older copy** (enabled on a port with two listeners) asks Windows when each copy
started and, after you say yes, ends the older one. **Edit registry** opens `ports.tsv` in Notepad. The
status line gives the next free port for a new server.

Its stack script is `livecode/ports_window.livecodescript`. Edit that file, then in the Message Box:

    get textDecode(url ("binfile:<LIB_PORTS>/livecode/ports_window.livecodescript"), "UTF-8")
    delete line 1 of it
    set the script of stack "Ports" to it
