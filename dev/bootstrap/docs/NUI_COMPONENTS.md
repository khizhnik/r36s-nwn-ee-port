# NUI Components

## Component: window

### Working JSON

```json
{
  "version": 1,
  "title": "R36S NUI TEST",
  "geometry": { "x": 100, "y": 100, "w": 300, "h": 120 },
  "root": {
    "type": "group",
    "children": []
  }
}
```

### Confirmed

* visible: yes
* title visible: yes
* `version` required
* `root` required
* `geometry` works
* `group` accepted
* `children` accepted

## Component: label

### Working JSON

```json
{ "type": "label", "value": "Hello from NUI" }
```

### Confirmed

* visible: yes
* visible text: yes
* working text field: `value`

### Tested but not working visually

```json
{ "type": "label", "text": "Hello from NUI" }
```

Result: parser accepts it, but text is not visible.

## Component: button

### Working JSON

```json
{ "type": "button", "label": "OK" }
```

### Confirmed

* visible: yes
* visible caption: yes
* working caption field: `label`

### Tested but not working visually

```json
{ "type": "button", "value": "OK" }
```

Result: parser accepts it, button is visible, caption is not visible.

## Component: textedit

### Tested JSON

```json
{ "type": "textedit", "value": "Hello" }
```

### Confirmed

* parser accepted: yes
* token returned: yes
* visible: yes
* text visible: yes
* working text field: `value`

## Component: image

### Working JSON

```json
{ "type": "image", "value": "po_exornova_h" }
```

### Confirmed

* parser accepted: yes
* token returned: yes
* widget visible: yes
* actual image visible: yes
* placeholder/red X visible: no
* working image field: `value`
* works with portrait `TGA` resref from `data/prt`

### Tested but not working visually

```json
{ "type": "image", "resref": "po_exornova_h" }
```

Result: placeholder / red X visible.

```json
{ "type": "image", "image": "po_exornova_h" }
```

Result: placeholder / red X visible.

```json
{ "type": "image", "resref": "gui_button" }
```

Result: placeholder / red X visible.

## Component: spacer

### Tested

```json
{ "type": "spacer" }
```

### Result

* parser accepted: yes
* token returned: yes
* `A` visible: yes
* `B` visible: no
* visible effect: spacing not confirmed
* layout effect between `A` and `B`: unresolved

### Inference

Bare `spacer` may consume/fill remaining layout space, or the current container layout rules are causing `B` to be pushed out/hidden.

```json
{ "type": "spacer", "width": 20 }
```

### Result

* parser accepted: yes
* token returned: yes
* `A` visible: yes
* `B` visible: no
* visible gap: no
* orientation/layout: unclear

### Inference

`spacer.width` does not produce a useful controlled gap in the current plain `group` layout. Spacer behavior is unresolved because the default `group` child layout is not yet understood.

## Component: row / column

## Component: row

```json
{
  "type": "row",
  "children": [
    { "type": "label", "value": "A" },
    { "type": "label", "value": "B" }
  ]
}
```

### Result

* parser accepted: yes
* token returned: yes
* `A` visible: yes
* `B` visible: yes
* layout: horizontal

### Tested but not working

```json
{
  "type": "row",
  "direction": "vertical",
  "children": [
    { "type": "label", "value": "A" },
    { "type": "label", "value": "B" },
    { "type": "label", "value": "C" }
  ]
}
```

Result:

* parser accepted: yes
* token returned: yes
* visual popup error: no
* `A` visible: yes
* `B` visible: yes
* `C` visible: yes
* orientation: horizontal
* vertical layout: no

### Note

`row.direction = "vertical"` is accepted but does not change row orientation.

## Component: column

### Tested

```json
{
  "type": "column",
  "children": [
    { "type": "label", "value": "A" },
    { "type": "label", "value": "B" }
  ]
}
```

### Result

* token returned: yes
* visual popup error: yes
* actual result: invalid widget type
* supported: no

### Error

```text
[json.exception.verify_error.0] unknown widget type: column
```

### Note

For NUI validation, the visual client popup error takes priority over `R36S_NUI_TOKEN`.

## Component: spacer in row

### Tested

```json
{
  "type": "row",
  "children": [
    { "type": "label", "value": "A" },
    { "type": "spacer", "width": 20 },
    { "type": "label", "value": "B" }
  ]
}
```

### Result

* parser accepted: yes
* token returned: yes
* visual popup error: no
* `A` visible: yes
* `B` visible: yes
* horizontal gap: yes
* `spacer.width` works inside `row`: yes

### Inference

`spacer.width` is confirmed only inside `row`.

## Component: list

Status: unresolved / likely bind-backed.

Confirmed:
* `list` is a recognized widget type.
* `children` is not valid for `list`.
* `row_template` is required.
* `row_template` must be an array.
* `row_template` array is accepted.
* literal `data` array fails with constructor error:
  `"[json.exception.type_error.304] cannot use at() with object"`
* literal `row_count` scalar fails with same constructor error:
  `"[json.exception.type_error.304] cannot use at() with object"`
* local docs confirm `NuiGetBind`, `NuiSetBind`, `NuiSetBindWatch`, `NuiGetNthBind`
* exact constructor JSON syntax for bind reference is not yet confirmed

### Inference

`list` is likely bind-backed and should not be revisited in the current component pass.

## Combined PoC: confirmed components

### Status

Partially successful.

### Planned JSON

```json
{
  "version": 1,
  "title": "R36S UI KIT",
  "geometry": { "x": 80, "y": 80, "w": 420, "h": 220 },
  "root": {
    "type": "group",
    "children": [
      {
        "type": "row",
        "children": [
          { "type": "image", "value": "po_exornova_h" },
          { "type": "spacer", "width": 20 },
          { "type": "label", "value": "NUI components OK" }
        ]
      },
      {
        "type": "row",
        "children": [
          { "type": "label", "value": "Name:" },
          { "type": "spacer", "width": 10 },
          { "type": "textedit", "value": "Hello" }
        ]
      },
      {
        "type": "row",
        "children": [
          { "type": "button", "label": "OK" },
          { "type": "spacer", "width": 10 },
          { "type": "button", "label": "Cancel" }
        ]
      }
    ]
  }
}
```

### Confirmed components used

* `window`
* `group`
* `row`
* `image.value`
* `label.value`
* `textedit.value`
* `button.label`
* `spacer.width` inside `row`

### Result

* one row works
* multiple row children inside `group` do not stack vertically
* `group` is not confirmed as a vertical container
* next required discovery: vertical layout/container

### Excluded

* `list`
* `scroll`
* `column`
* bind
* events
* keyboard
* local docs confirm `NuiGetBind`, `NuiSetBind`, `NuiSetBindWatch`, `NuiGetNthBind`.
* exact constructor JSON syntax for bind reference is not yet confirmed.

Not confirmed:
* how list data is bound.
* whether `row_count` must be a bind.
* whether row data comes from a bind object.
* whether `row_template` values use bind variables.

Hold list here until official/example bind constructor syntax is found.

## Builder-based PoC

### Status

Compiled successfully with `#include "nw_inc_nui"` and the standalone `nwn_script_comp`.
Include visibility is confirmed on the desktop install.

### Current harness

`ML_Version.nss` now builds the window with builder helpers only:

* `NuiCol`
* `NuiRow`
* `NuiLabel`
* `NuiButton`
* `NuiSpacer`
* `NuiWindow`

### Planned visual check

* vertical stacking via `NuiCol`: pending
* two-row layout: pending
* `NuiTextEdit` wrapper: not required for this PoC

## Builder-based PoC - confirmed

### Visual confirmation

* window title: `R36S BUILDER TEST`
* row 1 visible: yes
* row 1 content: `A / B`
* row 2 visible: yes
* row 2 content: `OK / Cancel`
* vertical stacking: yes
* `NuiCol` confirmed as vertical layout builder
* `NuiRow` confirmed as horizontal layout builder
* `NuiSpacer` confirmed inside `NuiRow`
* `NuiButton` confirmed through builder API
* `NuiLabel` confirmed through builder API

### Conclusions

* raw JSON `column` is invalid, but builder `NuiCol` works
* `row.direction="vertical"` and `row.orientation="vertical"` were accepted but ineffective
* vertical layout must be built through `NuiCol`, not through raw `row` flags
* builder-based path is now preferred over raw JSON experiments
* previous crash was avoided under software GL and is not attributed to the NUI builder by the crash report

### Do not regress

* Do not return to hand-written JSON for basic layout.
* Use `#include "nw_inc_nui"` and builder helpers for future UI work.
* Keep software GL flag in wrapper for desktop testing if Mesa/Iris crashes.

## Component: scroll

### Current test

```json
{
  "type": "scroll",
  "children": [
    { "type": "label", "value": "One" },
    { "type": "label", "value": "Two" },
    { "type": "label", "value": "Three" }
  ]
}
```

### Result

* parser accepted: yes
* token returned: yes
* error popup: pending visual confirmation
* visible children: pending visual confirmation
* scroll frame / scrollbar: pending visual confirmation
* orientation / layout: pending visual confirmation

## Later / Deferred: button click events

### Working JSON

```json
{ "type": "button", "label": "OK", "id": "ok" }
```

### Confirmed

* element id field: `id`
* open event type: `open`
* open event element: `_window_`
* open event payload: `null`
* click event type: `click`
* click event element: `ok`
* click event payload: `null`
* mousedown event type: `mousedown`
* mousedown event element: `ok`
* mousedown event payload example: `{"mouse_btn":0,"mouse_pos":{"x":111.0,"y":26.0}}`
* mouseup event type: `mouseup`
* mouseup event element: `ok`
* mouseup event payload example: `{"mouse_btn":0,"mouse_pos":{"x":111.0,"y":26.0}}`
