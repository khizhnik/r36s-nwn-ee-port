# Goal
Identify a minimal, high-signal probe set for the native load-request lifecycle that happens after pressing the real Load button. The selection/preview lifecycle is already confirmed; the remaining question is how the game transitions from button press to the actual save-load request and server-side load.

# What selection trace already confirmed
- `CPanelLoadSave::HandleSelectSaveGame(int)` fires when a save is selected.
- `CExoResMan::AddResourceDirectory(...)` follows selection and refreshes resource visibility.
- `CNWPortrait::ReplacePortraitTexture(...)` follows selection and refreshes portrait state.
- The observed order for selection is:
  - `HandleSelectSaveGame`
  - `AddResourceDirectory`
  - `ReplacePortraitTexture`

That trace explains UI selection, preview refresh, and resource setup. It does not show the actual Load button path or the request to load the selected save.

# Why selection trace is insufficient
The selection trace never enters the native Load button lifecycle:
- no `CPanelLoadGame::HandleOkButton()`
- no `CPanelLoadGame::SendLoadGameRequest()`
- no client-side `SendLoadGameRequest(...)`
- no `CNWCMessage::SendPlayerToServerModule_LoadGame(...)`
- no `CServerExoApp::LoadGame(...)`

So it cannot answer how a selected save becomes an actual load request.

# Candidate load-request symbols

## Core request path
| Symbol | Address (nm) | Why it matters | perf probe --definition status |
|---|---:|---|---|
| `CPanelLoadGame::HandleOkButton()` | `0x6f99a0` | Native Load button entry point. Confirms the user action reaches the panel callback. | `perf probe --definition` was not practical on these C++ names in this build; `nm` and `perf probe --funcs` confirm the symbol. |
| `CPanelLoadGame::SendLoadGameRequest()` | `0x6fa1d0` | Panel-level request dispatcher. This is the first strong candidate for actual load-request assembly. | Same perf parser limitation as above. |
| `CClientExoApp::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` | `0x637960` | Client facade for the request; shows whether the panel hands off into the app layer. | Same perf parser limitation as above. |
| `CNWCMessage::SendPlayerToServerModule_LoadGame(unsigned int, CExoString&, CExoString&, int)` | `0x8027b0` | Network message that carries the load request toward the server side. | Same perf parser limitation as above. |
| `CServerExoApp::LoadGame(unsigned int, CExoString&, CExoString&, CNWSPlayer*)` | `0x9fe780` | Server-side load entry point. Confirms the request reached actual load execution. | Same perf parser limitation as above. |

## Supporting candidates
| Symbol | Address (nm) | Why it may help |
|---|---:|---|
| `CClientExoAppInternal::SendLoadGameRequest(unsigned int, CExoString&, CExoString&, int)` | `0x63c610` | Useful if the public client facade is just a thin wrapper and we need the exact client-side handoff. |
| `CPanelLoadGame::GetSaveGameName()` | `0x6f9ef0` | Reveals how the selected save slot is translated into the save name/path used by the request. |
| `CPanelLoadGame::GetPlayerPassword()` | `0x6f9820` | Reveals whether password input participates in the request assembly. |
| `CClientExoApp::StartLoadBar(int, char const*, int)` | `0x638a70` | Useful for correlating visible load UI with the request lifecycle. |
| `CClientExoApp::EndLoadBar()` | `0x636980` | Useful for confirming request completion or failure cleanup. |
| `CNWSMessage::SendServerToPlayerSaveLoad_Status(CNWSPlayer*, unsigned char, unsigned int)` | `0xbbb730` | Useful for observing progress/status messaging around load. |
| `CClientExoAppInternal::ShutDownLoadGameLoadBar()` | `0x643760` | Useful if the panel tears down the load bar as part of the request flow. |

# Recommended next probe set
Use a focused 5-probe set first:

1. `nwn_load_ok = CPanelLoadGame::HandleOkButton`
2. `nwn_load_req = CPanelLoadGame::SendLoadGameRequest`
3. `nwn_client_send_load = CClientExoApp::SendLoadGameRequest`
4. `nwn_net_load_game = CNWCMessage::SendPlayerToServerModule_LoadGame`
5. `nwn_server_load_game = CServerExoApp::LoadGame`

Why this set:
- It starts at the actual Load button callback.
- It follows the request through the client app layer.
- It reaches the network message boundary.
- It ends at the server-side load entry point.

If one of those layers is missing in the trace, the supporting candidates above are the next most useful additions:
- `CClientExoAppInternal::SendLoadGameRequest`
- `CPanelLoadGame::GetSaveGameName`
- `CPanelLoadGame::GetPlayerPassword`
- `CNWSMessage::SendServerToPlayerSaveLoad_Status`

# Expected interpretation
- If `HandleOkButton` fires but `SendLoadGameRequest` does not, the button path is not actually reaching the load request dispatcher.
- If `SendLoadGameRequest` fires but client/server load probes do not, the request is likely being blocked, short-circuited, or redirected before the network message.
- If `CNWCMessage::SendPlayerToServerModule_LoadGame` fires but `CServerExoApp::LoadGame` does not, the client-side request is reaching the message layer but not the server load implementation.
- If all five fire in sequence, we will have a complete native load-request lifecycle trace and can then compare it directly to the custom NUI launcher’s selected-save state.
