# R36S UI Layouts

Confirmed builder layout patterns.

## Confirmed helper pattern

```text
NuiCol
  -> vertical stacking
NuiRow
  -> horizontal stacking
NuiSpacer
  -> horizontal gap inside NuiRow
```

## Confirmed visual result

- row 1: `A / B`
- row 2: `OK / Cancel`
- vertical stacking: yes

## Notes

- This is the preferred layout path for future UI work.
- Do not return to hand-written JSON for basic layout.
