# Layout Helpers

Confirmed layout helpers are documented here.

## Confirmed

- `NuiCol` - vertical stacking
- `NuiRow` - horizontal stacking
- `NuiSpacer` - horizontal gap inside a `NuiRow`

## Notes

- Raw JSON `column` is invalid in the tested runtime.
- `row.direction="vertical"` and `row.orientation="vertical"` were accepted but ineffective.
- Vertical layout should be built with `NuiCol`.
