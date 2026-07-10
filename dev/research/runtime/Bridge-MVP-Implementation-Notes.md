# What was implemented

A minimal PC-harness bridge prototype was implemented as a shared object under `dev/pc/bridge/`.

It exports one function:

```cpp
extern "C" BridgeResult nwn_bridge_load_save_index(int index);
```

The implementation resolves the live native panel state and performs the confirmed native sequence:

```text
SelectTab(index)
→ HandleSelectSaveGame(index)
→ SendLoadGameRequest()
```

The prototype logs to:

```text
dev/pc/logs/native-load-bridge.log
```

# What is intentionally not implemented

- no generic RPC framework
- no R36S integration
- no automatic NUI transport
- no payload reconstruction
- no auto-trigger of a load request from a constructor
- no patching of NWN

# Build command

```bash
make -C dev/pc/bridge
```

The shared object is built at:

```text
dev/pc/bridge/build/libnwn_load_bridge.so
```

# Exported symbols

- `nwn_bridge_load_save_index`

Returned result model:
- `BridgeStatus`
- `BridgeResult`

# How to test manually

This prototype is intentionally not auto-triggered into a load request.

The first manual validation step is to load the shared object in the PC harness later and call:

```cpp
nwn_bridge_load_save_index(1)
```

For the first prototype, the native Load panel should already be open manually.

# Known blockers

- The library is built, but it is not yet wired into NWN launch.
- The public API is exported, but no IPC transport has been attached yet.
- The bridge currently expects the native load panel to already be open.

# Next step

Load the shared object in a controlled PC-harness test and verify that `nwn_bridge_load_save_index(N)` reaches the native load pipeline and logs the expected state transitions.

# Debug command poller

For the first PC-only manual test, the bridge also includes a tiny debug poller that is compiled into the same shared object.

It is disabled by default. Enable it with:

```bash
NWN_LOAD_BRIDGE_DEBUG_POLL=1
```

When enabled, the constructor starts a low-frequency background thread that watches:

```text
/tmp/nwn_load_bridge_command
```

Accepted command format:

```text
LOAD_SAVE_INDEX N
```

The poller deletes the command file after reading it and forwards the request to the exported bridge API:

```cpp
nwn_bridge_load_save_index(N)
```

# How to launch with LD_PRELOAD

Example launch shape:

```bash
LD_PRELOAD=/absolute/path/to/dev/pc/bridge/build/libnwn_load_bridge.so \
NWN_LOAD_BRIDGE_DEBUG_POLL=1 \
DISPLAY=:0 \
XAUTHORITY="$HOME/.Xauthority" \
dev/pc/scripts/run-nui-bootstrap.sh test 03_r36s_bootstrap_nui_window
```

# How to send one test command

Once the native Load panel is open, from another terminal:

```bash
echo 'LOAD_SAVE_INDEX 1' > /tmp/nwn_load_bridge_command
```

# Expected logs

Bridge log file:

```text
dev/pc/logs/native-load-bridge.log
```

Expected entries:

- debug poller enabled
- command file observed
- `LoadSaveByIndex(1)` dispatched
- selected tab updated
- save callback invoked
- load request sent

# Safety notes

- The poller is disabled unless `NWN_LOAD_BRIDGE_DEBUG_POLL=1` is set.
- The constructor does not auto-trigger a load by itself.
- The poller does not auto-trigger a load by itself.
- The poller only forwards parsed `LOAD_SAVE_INDEX N` commands to the exported bridge API.
- Invalid commands are rejected and logged.

# First LD_PRELOAD test result

The first debug-poller test showed the intended command flow:

- the poller consumed the command successfully
- the exported bridge API was called
- resolution failed with `unsupported binary: nwmain-linux base not found`
- repeated poller startup showed `LD_PRELOAD` was inherited by helper processes, which is why process gating was needed

The fix is:

- gate poller startup by checking `/proc/self/exe` basename == `nwmain-linux`
- in the resolver, accept the empty-name main executable entry from `dl_iterate_phdr`
- use that entry's `dlpi_addr` as `exe_base`

# Successful retest

After fixing the preload path and process gating, the bridge successfully loaded inside the real `nwmain-linux` process and executed the native load sequence.

Observed bridge log evidence:

- `debug poller: enabled exe=.../nwmain-linux`
- `debug poller: command content='LOAD_SAVE_INDEX 1'`
- `debug poller: dispatch LoadSaveByIndex(1)`
- `resolve symbols ok exe=... base=...`
- `resolve pointers ok ... panel=... tabset=... visible_count=3 current=0`
- `call SelectTab ... idx=1`
- `after SelectTab current=1`
- `call HandleSelectSaveGame ... idx=1`
- `after HandleSelectSaveGame current=1`
- `call SendLoadGameRequest ... current=1`
- `status: ok`

This confirms the prototype bridge can reach the confirmed native load path from a simple command-file trigger when loaded into the correct `nwmain-linux` process.
