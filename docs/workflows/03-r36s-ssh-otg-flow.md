# 03. R36S SSH / OTG Deployment Flow

Purpose: move tested work from the workstation to the real device and bring logs back.

This is the bridge between PC development and hardware testing.

## Assumptions

- USB-C RNDIS over OTG is working.
- The existing `connect-r36s.sh` helper is the canonical SSH path.
- The device is reachable at the helper's current defaults unless overridden by environment variables.

## Storage layout

### Current two-SD layout

- `/roms2` is the active ROM/PortMaster storage.
- Default `R36S_PORT_DIR` is `/roms2/ports/nwn-ee`.

### Alternative single-SD layout

- `/roms` is the active ROM/PortMaster storage.
- Override per command with:

  ```bash
  R36S_PORT_DIR=/roms/ports/nwn-ee ./dev/toolset/scripts/deploy-to-r36s.sh
  R36S_PORT_DIR=/roms/ports/nwn-ee ./dev/toolset/scripts/run-on-r36s.sh
  R36S_PORT_DIR=/roms/ports/nwn-ee ./dev/toolset/scripts/pull-r36s-logs.sh
  ```

## Standard cycle

1. Connect the USB-C cable.
2. Bootstrap the device connection:

   ```bash
   ./dev/toolset/scripts/connect-r36s.sh
   ```

3. Deploy the current runtime:

   ```bash
   ./dev/toolset/scripts/deploy-to-r36s.sh
   ```

4. Start the port on the device:

   ```bash
   ./dev/toolset/scripts/run-on-r36s.sh
   ```

5. Pull the logs back locally:

   ```bash
   ./dev/toolset/scripts/pull-r36s-logs.sh
   ```

## Safeguards

- Deployment is non-destructive by default.
- Saves and user data are not the target of a cleanup sync.
- No second SSH workflow should be introduced.

## Troubleshooting

- If the host cannot see the USB network device, revisit the OTG/RNDIS link and the existing helper.
- If the device is reachable but the launcher fails, inspect the collected logs first.
