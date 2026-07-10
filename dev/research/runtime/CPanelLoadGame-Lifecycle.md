# Goal
Determine whether there is a live/reachable `CPanelLoadGame` instance that a custom NUI launcher could reuse, and identify the object ownership and lifetime model.

The important distinction is:

- the panel is not the payload builder
- the panel is the live native object that holds the state consumed by `CPanelLoadGame::SendLoadGameRequest()`

If the panel is already owned and activated by the client UI layer, custom integration may only need to bridge into that live panel state instead of recreating the full object graph externally.

# Why this matters for custom NUI launcher

The custom launcher already knows the save selection and can build the payload shape externally, but the native load path expects a live `CPanelLoadGame` instance with internal panel state.

If `CPanelLoadGame` is:

- allocated on demand,
- stored in the client app object,
- and reused while the panel is open,

then custom NUI integration might only need to reach the native panel lifecycle rather than reimplement loading.

# Static lifecycle findings

## Constructors / destructors

Relevant symbols:

- `CPanelLoadGame::CPanelLoadGame(int)` at `0x6fd1e0`
- `CPanelLoadGame::~CPanelLoadGame()` at `0x6fd2f0`
- `CPanelLoadGame::~CPanelLoadGame()` deleting dtor at `0x6fd360`

## Creator / destroyer functions

The panel is created and destroyed through the client app layer:

- `CClientExoApp::CreateLoadGamePanel(int)` at `0x636990`
- `CClientExoApp::DestroyLoadGamePanel(int)` at `0x6369a0`
- `CClientExoAppInternal::CreateLoadGamePanel(int)` at `0x63c020`
- `CClientExoAppInternal::DestroyLoadGamePanel(int)` at `0x63bfd0`

Static disassembly shows the internal app object owns the live panel pointer at offset `0xa0`.

### Create path

`CClientExoAppInternal::CreateLoadGamePanel(int)`:

- checks `this+0xa0`
- destroys any existing load panel if it is already present
- allocates a new `CPanelLoadGame`
- stores the pointer back into `this+0xa0`
- calls `CGuiModalPanel::Activate()`
- returns the live panel pointer

### Destroy path

`CClientExoAppInternal::DestroyLoadGamePanel(int)`:

- reads the pointer from `this+0xa0`
- deactivates the modal panel
- calls the virtual destructor
- clears `this+0xa0`

This is a classic on-demand owned-lifetime model, not a permanent global singleton.

## Load-panel openers

Functions that reach the create path:

- `CMainMenuPanel::HandleLoadButton()` at `0x822bd0`
- `CPlayModulePanel::HandleCancelButton()` at `0x82a670`
- `CPanelDeathMenu::OnLoadClose(int)` at `0x69e830`

Evidence from disassembly:

- `CMainMenuPanel::HandleLoadButton()` calls `CClientExoApp::CreateLoadGamePanel(int)`
- `CPlayModulePanel::HandleCancelButton()` also calls `CClientExoApp::CreateLoadGamePanel(int)` in one branch
- `CPanelDeathMenu::OnLoadClose(int)` calls `CClientExoApp::CreateLoadGamePanel(int)` and wires the callback back to the death menu

That means the load panel is reachable from both menu and in-game UI flows.

## Request path within the panel

Once the panel is alive, its load button path is:

`CPanelLoadGame::HandleOkButton()`
→ `CPanelLoadGame::HandleIngameOkCancelPanelExit(int)`
→ `CPanelLoadGame::SendLoadGameRequest()`

The actual request assembly happens in `CPanelLoadGame::SendLoadGameRequest()`.

# Candidate owner objects

| owner | evidence | interpretation |
|---|---|---|
| `CClientExoAppInternal` at offset `0xa0` | `CreateLoadGamePanel(int)` stores the panel there and `DestroyLoadGamePanel(int)` clears it | This is the concrete owner of the live `CPanelLoadGame*` |
| `CClientExoApp` wrapper | thin forwarding methods at `0x636990` / `0x6369a0` | Public facade that forwards into the internal app object |
| `g_pAppManager` | used by the opener functions before calling `CreateLoadGamePanel(int)` | Global entry into the client app / internal UI system |

# Object lifetime model

Best-supported interpretation:

- `CPanelLoadGame` is allocated on demand
- the live pointer is kept in `CClientExoAppInternal+0xa0`
- the panel is destroyed when the UI closes or transitions away
- a later open creates a fresh object if needed

So the object is not globally persistent across closes, but it is live and reusable while the panel is open.

# `HandleOkButton()` state notes

`CPanelLoadGame::HandleOkButton()` is a transition gate, not the payload builder.

It reads additional panel state before deciding how to continue:

- `0x12e8` looks like a UI string or label used to guard a branch
- `0x1400` is a UI/panel pointer (`CServerOptionsPanel` is used downstream in the same function)
- `0x1410` is a mode/flag-like field used to decide whether to create a `CPanelOkCancel` confirmation popup

It may also allocate temporary UI objects for confirmation handling.

Important:

- these extra reads are upstream gate logic
- they are not the minimal state consumed by `SendLoadGameRequest()`

# Runtime validation plan

The smallest useful passive validation is to observe:

1. the opener function that creates the panel
2. the `CPanelLoadGame` constructor and destructor
3. `CPanelLoadGame::HandleOkButton()`
4. `CPanelLoadGame::SendLoadGameRequest()`
5. the destroy function that clears the owner pointer

What this proves:

- whether the same `CPanelLoadGame*` is returned by the create path and later seen in `HandleOkButton()` / `SendLoadGameRequest()`
- whether the object is torn down when the panel closes
- whether the load panel is really a live native object that can be reused while open

# Exact manual trace command

Proposed passive bpftrace experiment:

```bash
sudo bpftrace -e '
uprobe:/tmp/nwmain-linux-hardlink:"CPlayModulePanel::HandleCancelButton()" { printf("open-play  ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }
uprobe:/tmp/nwmain-linux-hardlink:"CMainMenuPanel::HandleLoadButton()" { printf("open-main  ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }
uprobe:/tmp/nwmain-linux-hardlink:"CClientExoAppInternal::CreateLoadGamePanel(int)" { printf("create     ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }
uretprobe:/tmp/nwmain-linux-hardlink:"CClientExoAppInternal::CreateLoadGamePanel(int)" { printf("created    ts=%lld pid=%d tid=%d panel=%p\\n", nsecs, pid, tid, retval); }
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadGame::CPanelLoadGame(int)" { printf("ctor       ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadGame::~CPanelLoadGame()" { printf("dtor       ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }
uprobe:/tmp/nwmain-linux-hardlink:"CClientExoAppInternal::DestroyLoadGamePanel(int)" { printf("destroy    ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadGame::HandleOkButton()" { printf("ok         ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }
uprobe:/tmp/nwmain-linux-hardlink:"CPanelLoadGame::SendLoadGameRequest()" { printf("load       ts=%lld pid=%d tid=%d this=%p\\n", nsecs, pid, tid, arg0); }'
```

This is read-only. It does not write memory or replace code.

# Interpretation

## Live panel reuse looks plausible?

Yes.

The strongest evidence is:

- the panel is created on demand by the client UI layer
- the pointer is stored in `CClientExoAppInternal+0xa0`
- the panel remains live until `DestroyLoadGamePanel(int)` clears that slot
- in-game UI paths can reach the same create function

## What would confirm it

The hypothesis is confirmed if the trace shows:

- a `CreateLoadGamePanel` call
- a `CPanelLoadGame` constructor with a specific `this` pointer
- later `HandleOkButton()` / `SendLoadGameRequest()` using the same `this`
- then `DestroyLoadGamePanel()` / destructor on close

## What would refute it

The hypothesis would be weakened if:

- the create path returns a different panel object than the one later seen in the load button path
- the panel is destroyed and recreated before each interaction
- no stable live `CPanelLoadGame*` exists while the load window is open

# Risks / unknowns

- The exact in-game menu path varies by UI branch (`MainMenuPanel`, `PlayModulePanel`, `DeathMenu`).
- `HandleOkButton()` has extra transition logic that may depend on modal state and server options state.
- The panel is live only while open; it is not a permanent singleton.
- This note does not prove whether custom NUI code can reach the live panel directly from outside the process.

# Next step

Run the passive trace above while opening the native Load window from an in-game flow, then press the native Load button once.

The output should show whether the same `CPanelLoadGame*` pointer is:

- created,
- used for `HandleOkButton()` / `SendLoadGameRequest()`,
- and then destroyed on close.
