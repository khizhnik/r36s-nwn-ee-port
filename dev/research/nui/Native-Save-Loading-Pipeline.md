# Goal

Determine the closest native NWN:EE path for loading a saved game so the wrapper can later react to:

`R36S_BOOTSTRAP_LOAD_SAVE_REQUESTED|<index>|<folder>`

and make the game load the selected save the same way the built-in Load UI does.

# Environment

- Repo: `~/Games/PortMaster/r36s-nwn-ee-port`
- Steam install: `~/.steam/debian-installation/steamapps/common/Neverwinter Nights`
- Userdir: `~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/userdir`
- NWScript header: `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/ovr/nwscript.nss`
- Native binary inspected: `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/bin/linux-x86/nwmain-linux`
- Local docs inspected:
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/Neverwinter Nights Enhanced Edition (v79).txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/Neverwinter Nights Enhanced Edition (v76).txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/NWNv169.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/NWN_readme.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/HotUreadme.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/legacy/SoUreadme.txt`
  - `~/.steam/debian-installation/steamapps/common/Neverwinter Nights/lang/en/docs/SQLite_README.txt`
- Local userdir config inspected:
  - `~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/userdir/nwn.ini`
  - `~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/userdir/currentgame` (not present)

# Experiments performed

## 1. Searched the NWScript header for load/save APIs

Command used:

```bash
rg -n "\\bSaveGame\\b|\\bLoadGame\\b|\\bLoadSavedGame\\b|\\bDeleteSave\\b|\\bDoSinglePlayerAutoSave\\b" \
  ~/.steam/debian-installation/steamapps/common/Neverwinter\\ Nights/ovr/nwscript.nss
```

Result:

- Only `DoSinglePlayerAutoSave()` matched.
- No exposed NWScript function named `LoadGame`, `LoadSavedGame`, or `DeleteSave` was found in the shipped header.

## 2. Searched the native client/server binary for save-load symbols

Command used:

```bash
strings ~/.steam/debian-installation/steamapps/common/Neverwinter\\ Nights/bin/linux-x86/nwmain-linux \
  | rg -n '^\\+|LoadNewModule|TestNewModule|LoadGame|LoadSavedGame|currentgame|tempclient|savenfo|module_uuid|quicksave|autosave'
```

Relevant symbols found:

- `CPanelLoadGame::SendLoadGameRequest`
- `CClientExoAppInternal::SendLoadGameRequest`
- `CNWCMessage::SendPlayerToServerModule_LoadGame`
- `CServerExoApp::LoadGame`
- `CPanelLoadSave::HandleSelectSaveGame`
- `CSaveGameList::GetSaveGameFileInfo`
- `CSaveGameList::DeleteSaveGame`
- `LoadNewModule`
- `TestNewModule`
- `currentgame`
- `tempclient`
- `savenfo`
- `module_uuid.txt`

This shows the native engine/client has an internal load-save flow, but the symbols visible here are C++ internals, not NWScript APIs.

## 3. Inspected the shipped docs for currentgame and load/save behavior

Command used:

```bash
rg -n "Load/Save dialogue|currentgame|LoadGame|SendLoadGameRequest|module_uuid.txt|savenfo.txt|currentgame" \
  ~/.steam/debian-installation/steamapps/common/Neverwinter\\ Nights/lang/en/docs/...
```

Relevant doc lines found:

- `Neverwinter Nights Enhanced Edition (v79).txt` says:
  - `The Load/Save dialogue now properly removes savegames from the resource manager when exiting the UI.`
- Legacy readmes repeatedly mention:
  - a corrupted `currentgame` folder/file can break loading
  - deleting/renaming `currentgame` can fix that issue
- `NWNv169.txt` documents:
  - `+LoadNewModule`
  - `+TestNewModule`
  - but nothing about directly loading a saved game from the command line

## 4. Inspected userdir configuration

Command used:

```bash
sed -n '1,40p' dev/pc/userdir/nwn.ini
find dev/pc/userdir/currentgame -maxdepth 2 -type f
```

Findings:

- `nwn.ini` maps:
  - `CURRENTGAME=~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/userdir/currentgame`
  - `TEMPCLIENT=~/Games/PortMaster/r36s-nwn-ee-port/dev/pc/userdir/tempclient`
- `dev/pc/userdir/currentgame` does not currently exist in this dev userdir.

## 5. Attempted external web search

I attempted source-backed web searches for Beamdog/forum/community references, but they did not return usable results in this environment. This note therefore relies on shipped docs and binary inspection only.

# Screenshots

None.

This is research-only. No save-loading implementation or visual test was performed.

# Results

## Confirmed facts

- No NWScript API named `LoadGame`, `LoadSavedGame`, or `DeleteSave` was found in the shipped `nwscript.nss`.
- The shipped header does include `DoSinglePlayerAutoSave()`, which is save-related, but it is not a save-load API.
- The native client/binary does have an internal load-save pipeline:
  - `CPanelLoadGame::SendLoadGameRequest`
  - `CClientExoAppInternal::SendLoadGameRequest`
  - `CNWCMessage::SendPlayerToServerModule_LoadGame`
  - `CServerExoApp::LoadGame`
- The client binary also contains native load/save list helpers:
  - `CSaveGameList::GetSaveGameFileInfo`
  - `CSaveGameList::DeleteSaveGame`
  - `CPanelLoadSave::HandleSelectSaveGame`
- `nwn.ini` maps `CURRENTGAME` and `TEMPCLIENT` to userdir paths.
- The shipped docs confirm the Load/Save UI removes savegames from the resource manager on exit.
- The shipped docs and legacy readmes confirm `currentgame` is a meaningful engine directory/file in load/save workflows.

## Failed / unsupported approaches

- No direct NWScript load-save function was found.
- No direct NWScript delete-save function was found.
- No command-line save-load option was found in the string scan.
- I did not find evidence that `+LoadNewModule` or `+TestNewModule` can load a save game.
- I did not find evidence that `currentgame` can be safely staged by wrapper alone to perform a save load without further engine interaction.

## Likely options

- The native Load UI likely uses an internal client/server request path keyed by the selected save folder.
- The selected folder string from the UI is probably the important identifier passed into the native load flow.
- If the wrapper wants to drive native loading later, it will likely need one of:
  - UI-level automation of the native Load dialog
  - an internal engine/client message bridge
  - a restart-based strategy that stages files in a way the engine already understands

## Unknowns

- Whether the wrapper can invoke the native load flow directly without UI automation.
- Whether staging `currentgame` before startup is enough to make NWN resume a selected save.
- Whether `currentgame` is populated from the save folder before or after the load request completes.
- Which exact filesystem operations the engine performs when loading a save on Linux/EE.
- Whether there is a stable startup argument for loading a save directly.

## Recommended next experiment

Capture a native save load end-to-end in a visible session and watch the filesystem:

1. Start NWN normally.
2. Load one save using the native UI.
3. Observe `currentgame`, `tempclient`, and `modules` for file creation/renaming/copying.
4. Compare the filesystem before and after the load.
5. If possible, note any load-related log messages at the same time.

That would answer whether wrapper-side save loading should be:

- an in-process bridge to the native client path, or
- a restart/staging strategy built around `currentgame` and the selected save folder.
