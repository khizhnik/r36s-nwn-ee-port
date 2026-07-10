# Goal
Trace the native Load button request path after a save has already been selected, and determine the earliest native entry point that turns the selected save into an actual load request.

# Why selection trace is insufficient
The confirmed selection lifecycle only proves UI/preview/resource refresh behavior:

- `CPanelLoadSave::HandleSelectSaveGame`
- `CExoResMan::AddResourceDirectory`
- `CNWPortrait::ReplacePortraitTexture`

That chain explains save-row selection and visual refresh. It does not show the native Load button request path, which is the piece needed for custom launcher integration.

# Probe set
Use these five probes first:

| Event | Symbol | Why it matters |
|---|---|---|
| `nwn_load_ok` | `CPanelLoadGame::HandleOkButton` | Native Load button callback entry point. |
| `nwn_load_req` | `CPanelLoadGame::SendLoadGameRequest` | Panel-level load request dispatcher. |
| `nwn_client_send_load` | `CClientExoApp::SendLoadGameRequest` | Client app handoff from panel layer. |
| `nwn_net_load_game` | `CNWCMessage::SendPlayerToServerModule_LoadGame` | Message-layer transition toward the server load path. |
| `nwn_server_load_game` | `CServerExoApp::LoadGame` | Server-side load execution confirmation. |

Stable offsets for the current x86 build:

- `CPanelLoadGame::HandleOkButton` -> `0x6f99a0`
- `CPanelLoadGame::SendLoadGameRequest` -> `0x6fa1d0`
- `CClientExoApp::SendLoadGameRequest` -> `0x637960`
- `CNWCMessage::SendPlayerToServerModule_LoadGame` -> `0x8027b0`
- `CServerExoApp::LoadGame` -> `0x9fe780`

# Expected order
The most likely native sequence is:

1. `CPanelLoadGame::HandleOkButton`
2. `CPanelLoadGame::SendLoadGameRequest`
3. `CClientExoApp::SendLoadGameRequest`
4. `CNWCMessage::SendPlayerToServerModule_LoadGame`
5. `CServerExoApp::LoadGame`

If the chain stops earlier, that identifies the earliest safe integration point for the custom launcher.

# Manual interaction
Use the load-request helper in its default helper-launched mode or attach mode, then:

1. Open the native Load screen.
2. Select one save.
3. Press the native Load button.
4. Stop tracing with `Ctrl+C`.

# How to interpret results
- If `nwn_load_ok` fires but `nwn_load_req` does not:
  - the button callback ran, but request assembly was blocked before panel dispatch.
- If `nwn_load_req` fires:
  - this is probably the earliest important native entry point for custom launcher integration.
- If `nwn_client_send_load` fires:
  - the request reached the client app layer.
- If `nwn_net_load_game` fires:
  - the request reached the NWN message layer.
- If `nwn_server_load_game` fires:
  - the request reached actual server-side load execution.

# Final goal of this trace
Determine whether the custom launcher should aim to emulate:

- the panel callback path only
- the panel request dispatcher
- the client app handoff
- the network message layer
- or simply the native server-side load execution boundary
