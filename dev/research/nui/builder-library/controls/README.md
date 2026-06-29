# Control Helpers

This directory tracks reusable control helpers for the builder API.

## Confirmed

- `NuiLabel`
- `NuiButton`
- `NuiImage`

## Probed

- `NuiTextEdit` exists at the engine-symbol level.
- Compile-only probes against `NuiTextEdit()` and likely overloads currently fail with parameter mismatch.
- The exact builder wrapper signature is still under investigation.
- Internal engine implementation demangles to:
  - `Nui::Layout::Widgets::textedit(DynamicString, unsigned long, bool, DynamicString, int (*)(nk_text_edit const*, unsigned int), bool, char const*)`

## Notes

- Add a control helper here only after visual confirmation.
- Keep wrappers small and reusable.
