# Goal
Determine the native load-request lifecycle after pressing the real Load button, using the focused 5-probe set:

- `CPanelLoadGame::HandleOkButton`
- `CPanelLoadGame::SendLoadGameRequest`
- `CClientExoApp::SendLoadGameRequest`
- `CNWCMessage::SendPlayerToServerModule_LoadGame`
- `CServerExoApp::LoadGame`

The selection/preview/portrait refresh lifecycle was already confirmed earlier; this trace is about the actual load-request path.

# Files analyzed
- `dev/pc/logs/host-trace-load-request-20260702-220746.setup.log`
- `dev/pc/logs/host-trace-load-request-20260702-220746.perf-record.log`
- `dev/pc/logs/host-trace-load-request-20260702-220746.data`
- `dev/pc/logs/host-trace-load-request-20260702-220746.txt`

# Probe setup
The setup log confirms all five probes were installed successfully:

- `probe_nwmain:nwn_load_ok`
- `probe_nwmain:nwn_load_req`
- `probe_nwmain:nwn_client_send_load`
- `probe_nwmain:nwn_net_load_game`
- `probe_nwmain:nwn_server_load_game`

Relevant setup evidence:

- real NWN PID accepted: `2910023`
- accepted executable:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
- accepted inode:
  - `6058891`
- perf record command:
  - `sudo perf record -o '...220746.data' -e 'probe_nwmain:nwn_load_ok' -e 'probe_nwmain:nwn_load_req' -e 'probe_nwmain:nwn_client_send_load' -e 'probe_nwmain:nwn_net_load_game' -e 'probe_nwmain:nwn_server_load_game' -p '2910023'`

# Recording
Recording was attached to the real NWN process, not the helper shell or `sleep`:

- `PERF_RECORD_CMD` used `-p '2910023'`
- `perf record` exited after Ctrl+C with:
  - `Captured and wrote 0.390 MB ... (14 samples)`
- `Total Lost Samples: 0`

# Hit counts
`perf report --stdio` shows:

- `probe_nwmain:nwn_load_ok`: 3 samples
- `probe_nwmain:nwn_load_req`: 2 samples
- `probe_nwmain:nwn_client_send_load`: 3 samples
- `probe_nwmain:nwn_net_load_game`: 3 samples
- `probe_nwmain:nwn_server_load_game`: 3 samples

No event has zero hits, but `nwn_load_req` is missing from one of the three observed load activations.

# Timeline
Chronological `perf script` samples:

1. `3120695.494779` `nwmain-linux` pid `2910023` tid `2910023` cpu `010`
   - event: `probe_nwmain:nwn_load_ok`
   - ip: `0x55fab6ef99a0`

2. `3120697.258773` `nwmain-linux` pid `2910023` tid `2910023` cpu `013`
   - event: `probe_nwmain:nwn_load_req`
   - ip: `0x55fab6efa1d0`

3. `3120697.258785` `nwmain-linux` pid `2910023` tid `2910023` cpu `013`
   - event: `probe_nwmain:nwn_client_send_load`
   - ip: `0x55fab6e37960`

4. `3120697.258787` `nwmain-linux` pid `2910023` tid `2910023` cpu `013`
   - event: `probe_nwmain:nwn_net_load_game`
   - ip: `0x55fab70027b0`

5. `3120697.357582` `nwmain-linux` pid `2910023` tid `2910023` cpu `004`
   - event: `probe_nwmain:nwn_server_load_game`
   - ip: `0x55fab71fe780`

6. `3120705.875887` `nwmain-linux` pid `2910023` tid `2910023` cpu `013`
   - event: `probe_nwmain:nwn_load_ok`
   - ip: `0x55fab6ef99a0`

7. `3120707.066956` `nwmain-linux` pid `2910023` tid `2910023` cpu `007`
   - event: `probe_nwmain:nwn_load_req`
   - ip: `0x55fab6efa1d0`

8. `3120707.066966` `nwmain-linux` pid `2910023` tid `2910023` cpu `007`
   - event: `probe_nwmain:nwn_client_send_load`
   - ip: `0x55fab6e37960`

9. `3120707.066968` `nwmain-linux` pid `2910023` tid `2910023` cpu `007`
   - event: `probe_nwmain:nwn_net_load_game`
   - ip: `0x55fab70027b0`

10. `3120707.226612` `nwmain-linux` pid `2910023` tid `2910023` cpu `002`
    - event: `probe_nwmain:nwn_server_load_game`
    - ip: `0x55fab71fe780`

11. `3120717.497779` `nwmain-linux` pid `2910023` tid `2910023` cpu `008`
    - event: `probe_nwmain:nwn_load_ok`
    - ip: `0x55fab6ef99a0`

12. `3120717.512292` `nwmain-linux` pid `2910023` tid `2910023` cpu `006`
    - event: `probe_nwmain:nwn_client_send_load`
    - ip: `0x55fab6e37960`

13. `3120717.512295` `nwmain-linux` pid `2910023` tid `2910023` cpu `006`
    - event: `probe_nwmain:nwn_net_load_game`
    - ip: `0x55fab70027b0`

14. `3120717.513056` `nwmain-linux` pid `2910023` tid `2910023` cpu `006`
    - event: `probe_nwmain:nwn_server_load_game`
    - ip: `0x55fab71fe780`

# Load-request chain interpretation
The trace strongly supports the following chain:

`CPanelLoadGame::HandleOkButton`
→ `CPanelLoadGame::SendLoadGameRequest`
→ `CClientExoApp::SendLoadGameRequest`
→ `CNWCMessage::SendPlayerToServerModule_LoadGame`
→ `CServerExoApp::LoadGame`

However, the chain is not strictly linear on every activation:

- `CPanelLoadGame::HandleOkButton` fired 3 times.
- `CPanelLoadGame::SendLoadGameRequest` fired only 2 times.
- The client/app/network/server steps fired 3 times each.

That means the trace does **not** show `SendLoadGameRequest` on every load-button activation, even though the deeper request path still completed.

# Earliest useful native entry point
The earliest confirmed native entry point for this load flow is:

`CPanelLoadGame::HandleOkButton`

Reason:
- it fired on all three observed load-button attempts
- it is the first native callback in the request path
- it is the earliest stable point the custom launcher could potentially align with

The earliest more specific load-request assembly point is:

`CPanelLoadGame::SendLoadGameRequest`

But it did not fire on every observed activation, so it is a better probe for request assembly than for the absolute earliest user-visible transition.

# Meaning for custom NUI launcher
For future custom-launcher integration, the key conclusion is:

- the native button callback is definitely reachable (`HandleOkButton`)
- the actual request path does reach client, message, and server load execution
- `SendLoadGameRequest` is useful, but not a guaranteed single choke point for every activation

So the custom launcher should likely aim to reproduce the state immediately before the native request path, while treating `HandleOkButton` as the earliest confirmed boundary and `SendLoadGameRequest` as the earliest specific request-assembly candidate.

# Conclusion
This trace confirms that pressing the native Load button can drive the full native load-request chain through to server-side `LoadGame`.

It also shows that `CPanelLoadGame::SendLoadGameRequest` is not visible on every observed load-button activation, so the path is slightly more nuanced than a single strict linear sequence.

## Status
PARTIAL LOAD REQUEST TRACE