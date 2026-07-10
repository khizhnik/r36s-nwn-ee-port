# 02. PortMaster Runtime Flow

Purpose: maintain the runnable port in `./port/` as the production runtime.

This tree is the canonical runtime layout for the R36S build.

## Rules

- Keep changes minimal.
- Do not reorganize files without a verified hardware reason.
- Do not mix development experiments into the runtime tree.
- Preserve launcher behavior unless a tested fix requires a change.

## Runtime root

The runtime lives under:

```text
./port
```

The existing runtime launcher is `nwn-play.sh`.

If a future `start.sh` is introduced, it must be deliberate and tested on hardware before becoming part of the standard flow.

## What to expect

- production game assets
- launcher code
- runtime-specific configuration
- files required for a real PortMaster deployment

## What to avoid

- experimental scripts
- throwaway diagnostics
- layout refactors that have not been validated on the R36S
