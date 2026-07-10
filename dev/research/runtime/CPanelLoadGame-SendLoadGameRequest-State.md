# Goal
Determine what native object state must already exist before calling `CPanelLoadGame::SendLoadGameRequest()`, so the custom launcher can judge whether direct invocation is realistic.

This is the integration target now. The earlier selection/preview lifecycle is already confirmed, and the request-payload chain is known. The remaining question is what panel state `SendLoadGameRequest()` actually consumes.

# Confirmed upstream context

The native load path is:

`CPanelLoadGame::HandleOkButton()`
→ `CPanelLoadGame::HandleIngameOkCancelPanelExit(int)`
→ `CPanelLoadGame::SendLoadGameRequest()`
→ `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

An alternate caller also reaches the same client boundary:

`CPanelLoadGame::OnConnectServerStatusPanelExit(int)`
→ `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)`

`CClientExoApp::SendLoadGameRequest(...)` itself is only a thin wrapper.

# Function body summary

`CPanelLoadGame::SendLoadGameRequest()` does the following:

1. Reads the selected save index from panel state.
2. Uses the panel's embedded `CSaveGameList` object to look up save metadata.
3. Pulls the selected save's full name and then derives a suffix via string search/sub-string logic.
4. Looks up file-info data for the same index twice.
5. Builds temporary `CExoString` objects on the stack.
6. Calls `CClientExoApp::SendLoadGameRequest(...)`.

It does not appear to modify persistent panel selection state before the client call.
It does allocate and destroy several temporary string objects.

# `this` reads

Static disassembly shows only a small set of durable member reads from `this`:

| offset | meaning | required? | how obtained |
|---|---|---|---|
| `0x960` | selected save index / panel selection state | Yes | Read directly at function entry and used to select the active save entry |
| `0x13d0` | embedded `CSaveGameList` object | Yes | Addressed with `lea 0x13d0(%rdi)` and passed to save-list query methods |
| `0xd50` | save-list index table / slot-to-file-info mapping | Yes | Loaded through `mov 0xd50(%rdi),%rax` and used as an indexed integer array |

No other persistent `this` members are clearly read in this function body.

# Classification of reads

## Selected save index

`0x960`

Classification:

- selected save index
- panel state

Why:

- it is read first
- it determines which save-list entry is queried
- it is later moved into a stack local for the client request argument

## Save list

`0x13d0`

Classification:

- save list
- embedded `CSaveGameList` object

Why:

- the function passes this member directly to `CSaveGameList::GetSaveGameName(int)`
- the same member is also passed to `CSaveGameList::GetSaveGameFileInfo(int)`

## Save-list index table

`0xd50`

Classification:

- save list
- other: indexed lookup table

Why:

- the selected save index is used to index into this table
- the resulting integer is stored as the payload's first integer argument

This is the earliest place where the numeric load-request argument is derived from the selected entry.

# Required vs optional

## Mandatory

Required before calling `SendLoadGameRequest()`:

- valid `CPanelLoadGame` instance
- selected save index in `this+0x960`
- populated embedded `CSaveGameList` at `this+0x13d0`
- populated save-list index table at `this+0xd50`

Without those members, the function has no selected entry to resolve.

## Not mandatory from the function body

Not read as persistent state by this function body:

- save-name string as a preexisting member
- module-name string as a preexisting member
- password string as a preexisting member
- explicit UI widget pointers

The function builds its own temporary strings and does not appear to rely on prebuilt string members.

# Temporary objects and validation

The function does additional work beyond simple state consumption:

- allocates local `CExoString` temporaries on the stack
- constructs a temporary separator string
- performs `Find`
- performs `SubString`
- calls `Steal`
- deletes temporary heap buffers

It also queries `CSaveGameList::GetSaveGameName(int)` and `CSaveGameList::GetSaveGameFileInfo(int)` twice.

This is best described as:

- consuming existing panel state
- deriving request strings on the fly
- performing some validation / normalization of the selected save name

It does **not** appear to persistently modify panel state before the client handoff.

# Offset-to-meaning table

| offset | meaning | required? | how obtained |
|---|---|---|---|
| `0x960` | selected save index | Yes | Read from panel instance, then used to select the active save |
| `0x13d0` | embedded `CSaveGameList` | Yes | Address of the save-list object embedded in the panel |
| `0xd50` | save-list slot/index table | Yes | Used to translate the selected slot into the request's integer argument |

# Realism of direct invocation

## In-process

If the function is called from inside NWN with a live `CPanelLoadGame` instance whose selection and save-list storage are already populated, then direct invocation is realistic.

## From the custom launcher

From the custom NUI launcher as it exists today, direct invocation is **not** realistic by itself.

Reason:

- the function expects a live native panel object
- it expects internal save-list state already built inside the process
- the launcher can reproduce the *data* externally, but not the `CPanelLoadGame` object graph that this function reads from

So the practical integration point is not "call this function from outside"; it is "recreate or bridge the same state inside the native panel path."

# Conclusion

`CPanelLoadGame::SendLoadGameRequest()` primarily consumes panel selection state and the embedded save list. It does not need prebuilt save-name/module-name member fields; it derives those locally from the save list during the call.

The minimum durable state is:

- selected save index
- populated embedded save list
- populated slot/index translation table

That is enough to explain why the function is the right native integration target, but it also shows why a direct external call from the custom launcher is not practical without a native bridge.
