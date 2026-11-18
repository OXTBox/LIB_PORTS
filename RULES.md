# LIB_PORTS rules

Started 18 Nov 2026, after the Game Browser froze for about 30 seconds: two xt3d games benches were both
listening on port 8770 (Windows let the second one bind), the second overwrote the token file, and the
browser's 15-second `curl` checks went to whichever copy Windows picked.

1. **The registry is the one list.** Every port one of our programs listens on has a row in `ports.tsv`
   before the code that opens it is committed. A new server takes the lowest free port in 8771-8799.
   `tools/ports_check.py scan` flags any port number in our code that has no row.

2. **Look before you listen.** Before `accept connections on port`, a server checks whether something already
   answers on the port (`Ports.InUse`, 500 ms). If something does, it does not start. It says which port and
   which registry name instead, and it leaves the token file alone. A token file belongs to the live listener.

3. **Clients never hang the interface.** A health check (`/ping`) waits at most 2 seconds. A real request
   waits at most 15. Whatever blocks (`shell`, a blocking `open socket`, a long `read`) sets
   `the cursor to busy` first, and the window says what it is waiting for.

4. **Busy cursor (LiveCode HIG).** Every file access, every `shell()` and every `repeat` / `while` loop sets
   `the cursor to busy`. Inside a loop it goes inside the body, so the beach ball turns each time round.
   Use `watch` for one moderately long step.

5. **One copy per port.** A program that owns a port and finds itself started twice closes the new copy, not
   the old one. A copy that is stuck is closed by its owner (the settings window, or by hand), never by a
   client silently.

6. **Not ours, still listed.** Ports other programs use (LM Studio 1234, ComfyUI 8188) are in the registry
   too, so ours never collide with them.
