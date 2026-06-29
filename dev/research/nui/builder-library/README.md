# UI Library

This directory contains the local reusable NUI component library for builder-based UI work.

## Principles

- Build all new UI through `#include "nw_inc_nui"`.
- Do not use hand-written raw JSON for basic layout.
- Keep every helper small, testable, and reusable.
- After a visual confirmation, mark the helper as `confirmed`.
- Prefer builder helpers for layout, controls, and examples.

## Current confirmed baseline

- `NuiCol` for vertical stacking
- `NuiRow` for horizontal stacking
- `NuiSpacer` for horizontal gaps inside `NuiRow`

## Subdirectories

- `layouts/` - layout helpers and patterns
- `controls/` - control helpers under investigation or confirmed
- `examples/` - small reusable examples and PoCs
