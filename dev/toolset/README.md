# Dev Toolset

These scripts support the R36S development loop for the NWN:EE port.

The workflow is intentionally split into three independent flows:

1. PC / NUI hypothesis flow
2. PortMaster runtime flow
3. R36S SSH / OTG deployment flow

## Standard cycle

1. Connect the USB-C cable.
2. Bootstrap the device connection:

   ```bash
   ./dev/toolset/scripts/connect-r36s.sh
   ```

   `connect-r36s.sh` is the single owner of:

   - USB interface detection
   - RNDIS setup
   - host IP configuration
   - SSH connection bootstrap

3. If the connection succeeds, deploy the current runtime:

   ```bash
   ./dev/toolset/scripts/deploy-to-r36s.sh
   ```

4. Run the port on hardware:

   ```bash
   ./dev/toolset/scripts/run-on-r36s.sh
   ```

5. Pull the logs back to the workstation:

   ```bash
   ./dev/toolset/scripts/pull-r36s-logs.sh
   ```

## Scripts

`connect-r36s.sh`
: Existing USB SSH connection helper. Do not replace it.

`deploy-to-r36s.sh`
: Copies `./port/` to the R36S over the existing USB SSH path.

`run-on-r36s.sh`
: Starts the launcher on the device and stores the remote output.

`pull-r36s-logs.sh`
: Collects remote logs into `dev/logs/r36s/YYYYmmdd-HHMMSS/`.

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

## Notes

- The default deployment is non-destructive.
- `--delete` is available on deploy only when you explicitly want rsync cleanup.
- The runtime tree under `port/` is treated as production. Keep changes there minimal.
