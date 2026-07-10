# 01. PC / NUI Hypothesis Flow

Purpose: fast iteration on launcher, control layer, and UI hypotheses on the workstation.

This flow is the lab. It can be broken intentionally while a concept is being tested.

## What belongs here

- NUI launcher experiments
- control-layer prototypes
- input mapping ideas
- UI layout experiments for the R36S screen

## What does not belong here

- final PortMaster runtime wiring
- device-specific deployment scripts
- runtime tree reshuffles

## Typical loop

1. Make the change in the PC/NUI area.
2. Validate locally on the workstation.
3. Keep only the ideas that prove useful on real hardware.

This flow should inform the production port, not replace it.
