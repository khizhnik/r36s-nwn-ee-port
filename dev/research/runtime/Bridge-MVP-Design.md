# Goal
Design the smallest explicit in-process native load bridge prototype for the PC harness.

The reverse-engineering phase is closed. The bridge should reuse the confirmed native load path instead of reconstructing payloads manually.

# Native sequence to reuse
```text
CreateLoadGamePanel()
→ CGuiTabSet::SelectTab(N)
→ CPanelLoadSave::HandleSelectSaveGame(N)
→ CPanelLoadGame::SendLoadGameRequest()
```

Confirmed supporting state:
- live `CPanelLoadGame*` is owned by `CClientExoAppInternal+0xa0`
- tab-selection widget is at `CPanelLoadGame+0x948`
- current selected index is `CPanelLoadGame+0x960`
- `HandleSelectSaveGame(N)` refreshes the selection-dependent UI/resources
- `SendLoadGameRequest()` reads the final selected index and constructs the native request payload

# Candidate bridge mechanisms

| Option | Complexity | Safety | In-process | Can call C++ member funcs | Receives `N` from custom NUI | MVP fit | R36S portability |
|---|---:|---:|---:|---:|---:|---:|---:|
| A. Tiny `LD_PRELOAD` / injected shared object | Low | Medium | Yes | Yes | Yes | **Best** | Medium |
| B. NWNX-style plugin | Medium | Medium | Yes | Yes | Yes | Possible | Medium |
| C. Existing NWScript / NUI script route | Low | High | Not by itself | Not directly | Yes | Weak for this use | Low |
| D. External controller + `ptrace`/`gdb` | High | Low | Yes, but intrusive | Yes | Yes | Not recommended | Low |
| E. Not viable / manual payload reconstruction | N/A | N/A | N/A | N/A | N/A | Rejected | N/A |

## Notes on each option

### A. Tiny `LD_PRELOAD` / injected shared object
This is the simplest explicit in-process MVP for the PC harness.

Why it fits:
- no game binary patching
- reversible by removing one preload environment variable
- can open a local socket/FIFO and accept a single `LOAD_SAVE_INDEX N` command
- can call native C++ methods directly once it resolves the live panel pointer
- can log every call and pointer used

Risks:
- PC-only unless separately ported
- requires careful version/offset validation

### B. NWNX-style plugin
This is plausible if the harness already supports a stable plugin load path, but it is heavier than a preload shim for a first prototype.

Why it is less attractive as MVP:
- more framework than needed
- higher integration cost
- less direct control of startup and lifecycle than a preload shim

### C. Existing NWScript / NUI script route
Useful for passing `N` into the game at a high level, but insufficient by itself for calling the native C++ member methods that drive the load pipeline.

It may still be useful later as the user-facing trigger that sends `N` to the in-process bridge.

### D. External controller + `ptrace`/`gdb`
Technically possible, but too invasive for a first prototype.

Why not MVP:
- intrusive
- harder to keep stable
- more likely to perturb timing
- awkward for repeated testing

### E. Manual payload reconstruction
Rejected for MVP.

We already know the native payload model, but re-creating it manually would bypass the native path we want to preserve and would be more fragile than reusing `SelectTab(N)` + `HandleSelectSaveGame(N)` + `SendLoadGameRequest()`.

# Recommended MVP mechanism
Use a tiny PC-only `LD_PRELOAD` shared object as an in-process bridge.

Why this is the simplest:
- explicit
- reversible
- easy to disable
- does not modify the NWN binary
- can call native C++ member methods in-process
- can receive `N` from the custom NUI via a simple local IPC endpoint
- can fail safely by refusing to act if expected symbols or pointers are missing

Recommended architecture:
1. Custom NUI sends `LOAD_SAVE_INDEX N` to a local IPC endpoint.
2. Preloaded shim receives `N`.
3. Shim resolves the live client/internal app pointers.
4. Shim verifies the load panel exists and is valid.
5. Shim calls native selection path:
   - `CGuiTabSet::SelectTab(N)`
   - `CPanelLoadSave::HandleSelectSaveGame(N)`
   - `CPanelLoadGame::SendLoadGameRequest()`
6. Shim logs each step and returns success/failure.

# Required native symbols
Minimum symbols for the bridge prototype:

- `CClientExoApp::CreateLoadGamePanel(int)` at `0x636990`
- `CClientExoAppInternal::CreateLoadGamePanel(int)` at `0x63c020`
- `CGuiTabSet::SelectTab(int)` at `0x596db0`
- `CPanelLoadSave::HandleSelectSaveGame(int)` at `0x6fd500`
- `CPanelLoadGame::SendLoadGameRequest()` at `0x6fa1d0`

Useful supporting symbols:
- `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` at `0x637960`
- `CPanelLoadGame::PostAttachmentInitialize()` at `0x6fe490`
- `CPanelLoadSave::PostAttachmentInitialize(int)` at `0x6f8610`

# Pointer discovery
Known live-object ownership:
- `g_pAppManager` is the global entry point into the client app
- `CClientExoAppInternal+0xa0` holds the live `CPanelLoadGame*`
- `CPanelLoadGame+0x948` is the embedded `CGuiTabSet`
- `CPanelLoadGame+0x960` is the current selected index

Practical discovery flow for the bridge:
1. resolve `g_pAppManager`
2. reach the client app / internal app object
3. read `internal+0xa0` for the live load panel
4. read `panel+0x948` for the tabset
5. verify the selected index field at `panel+0x960`

The bridge should refuse to proceed if any pointer is null or if the expected panel type/version does not match.

# Prototype API
Keep the first prototype intentionally crude and easy to observe.

Recommended MVP control plane:
- a UNIX domain socket or FIFO in `/tmp`
- one command only: `LOAD_SAVE_INDEX N`

Example command payload:
```text
LOAD_SAVE_INDEX 2
```

Alternative syntax if the IPC is line-oriented:
```text
load_save_index=2
```

Requirements:
- simple to send from the custom NUI
- simple to log
- easy to disable
- no need for a general RPC framework

# Logging
The prototype should log at least:
- received `N`
- resolved client/internal pointer(s)
- resolved `CPanelLoadGame*`
- resolved tabset pointer
- `CGuiTabSet::SelectTab(N)` called
- selected index after `SelectTab`
- `CPanelLoadSave::HandleSelectSaveGame(N)` called
- `CPanelLoadGame::SendLoadGameRequest()` called
- success/failure path and reason for failure

Prefer logging to a dedicated file under the PC harness logs directory and mirroring short status lines to stderr for quick debugging.

# Safety checks
The bridge must reject:
- `N < 0`
- `N >= visible save count`, if count can be determined safely
- null panel pointer
- null internal app pointer
- missing symbols
- unsupported binary version or unexpected object layout

It should fail closed:
- do nothing if validation fails
- leave the game running
- keep native behavior untouched

# PC harness test plan
1. Load the bridge only in the PC harness.
2. Start the game normally.
3. Open the native Load panel.
4. Send `LOAD_SAVE_INDEX N` to the bridge.
5. Verify the logs show:
   - the panel exists
   - `SelectTab(N)` was invoked
   - `HandleSelectSaveGame(N)` ran
   - `SendLoadGameRequest()` ran
6. Confirm the game reaches the normal load request path.

This test plan is intentionally minimal and PC-only.

# Why not payload reconstruction
We already confirmed the payload model:
- `arg1` = numeric save slot / prefix-like discriminator
- `s1` = save name / folder suffix
- `s2` = module name
- `arg4` = flags

However, reconstructing those values manually would duplicate native logic and increase fragility. The bridge should instead reuse the native panel selection and request path that NWN already implements.

# R36S portability notes
This MVP is PC-only by design.

Portability to R36S later is possible only if the same bridge idea is reimplemented in a form suitable for that environment, but that is explicitly out of scope for the first prototype.

Expected portability constraints:
- offsets and symbol availability must be revalidated
- the load bridge transport may need to change
- the preload-based approach may not be the final deployment mechanism on R36S

# Open risks
- whether the live panel is guaranteed to exist when the command arrives
- whether the bridge should create the panel itself or require the user to open it first
- how to discover the visible save count robustly without duplicating logic
- whether the selected index should be validated against the live `CGuiTabSet` or the save list
- whether the bridge should call `CreateLoadGamePanel()` or simply reuse the live panel if already open
- version drift in offsets or the panel owner path

None of these risks require new reverse engineering before a first PC-only prototype is attempted; they are implementation concerns.
