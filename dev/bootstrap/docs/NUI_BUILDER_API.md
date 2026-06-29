# Reconstructed NUI Builder API

Source basis:
- `NuiTest.mod` from Neverwinter Vault sample `nui-sample-list-widget-and-npc-picker`
- shipped `nwscript.nss`
- Beamdog changelog / patch notes
- `nwmain-linux` binary symbols and strings
- compiler-visible `#include "nw_inc_nui"` on the desktop install

## Status Legend

- CONFIRMED: directly shown in sample source, shipped docs, or engine symbols
- LIKELY: strongly supported by source structure, but not directly exposed as a local source file
- UNKNOWN: not recovered from available local sources

## Builder Graph

```text
NuiCreate / NuiCreateFromResRef
  -> NuiWindow(root, title, rect, flags...)
     -> NuiCol(children)
     -> NuiRow(children)
     -> NuiGroup(child, bordered, scrollbars)
     -> NuiList(template, bind, rowHeight)
         -> NuiListTemplateCell(widget, cellHeight, stretch)
     -> leaf widgets and decorators
        -> NuiImage(...)
        -> NuiLabel(...)
        -> NuiButton(...)
        -> NuiSpacer()
        -> NuiDrawList(...)
           -> NuiDrawListText(...)
        -> NuiId(...)
        -> NuiMargin(...)
        -> NuiWidth(...)
        -> NuiHeight(...)
        -> NuiStyleForegroundColor(...)
        -> NuiRect(...)
        -> NuiColor(...)
        -> NuiBind(...)
        -> NuiSetBind(...)
```

## Confirmed Builders

### Window / Containers

- `NuiWindow`
- `NuiCol`
- `NuiRow`
- `NuiGroup`
- `NuiList`
- `NuiListTemplateCell`

### Leaf widgets

- `NuiImage`
- `NuiLabel`
- `NuiButton`
- `NuiSpacer`

### Decorators / helpers

- `NuiDrawList`
- `NuiDrawListText`
- `NuiId`
- `NuiMargin`
- `NuiWidth`
- `NuiHeight`
- `NuiStyleForegroundColor`
- `NuiRect`
- `NuiColor`
- `NuiBind`
- `NuiSetBind`
- `NuiSetUserData`
- `NuiGetUserData`
- `NuiFindWindow`
- `NuiDestroy`
- `NuiGetEventType`
- `NuiGetEventElement`
- `NuiGetEventArrayIndex`
- `NuiGetEventPlayer`
- `NuiGetEventWindow`
- `NuiGetWindowId`

## List Widget Reconstruction

### CONFIRMED

- `list` is a real widget type.
- `row_template` is a real schema key.
- `row_count` and `row_height` are real schema keys in the engine binary.
- `countbinds` appears in the engine binary.
- `unknown-bind` is a real NUI event in Beamdog changelog.
- The sample module uses bind-backed arrays, not literal list arrays.

### Likely source-side shape

```c
json jListTemplate = JsonArray();
json jImage = NuiImage(NuiBind("portraits"), JsonInt(NUI_ASPECT_EXACTSCALED), JsonInt(NUI_HALIGN_CENTER), JsonInt(NUI_VALIGN_TOP));
jImage = NuiId(jImage, "portrait");
jImage = NuiMargin(jImage, 0.0f);
jImage = NuiGroup(jImage, FALSE, NUI_SCROLLBARS_NONE);
jListTemplate = JsonArrayInsert(jListTemplate, NuiListTemplateCell(jImage, 32.0f, FALSE));

json jLabel = NuiLabel(NuiBind("names"), JsonInt(NUI_HALIGN_LEFT), JsonInt(NUI_VALIGN_TOP));
jLabel = NuiId(jLabel, "info_label");
jLabel = NuiStyleForegroundColor(jLabel, NuiBind("colors"));
json jDrawList = JsonArray();
jDrawList = JsonArrayInsert(jDrawList, NuiDrawListText(JsonBool(TRUE), NuiBind("colors"), NuiRect(0.0f, 25.0f, 300.0f, 25.0f), NuiBind("races")));
jDrawList = JsonArrayInsert(jDrawList, NuiDrawListText(JsonBool(TRUE), NuiBind("colors"), NuiRect(0.0f, 50.0f, 300.0f, 25.0f), NuiBind("classes")));
jLabel = NuiDrawList(jLabel, JsonBool(TRUE), jDrawList);
jListTemplate = JsonArrayInsert(jListTemplate, NuiListTemplateCell(jLabel, 0.0f, TRUE));

json jList = NuiList(jListTemplate, NuiBind("portraits"), 50.0f);
```

### Bind setup

```c
NuiSetBind(oPC, iToken, "portraits", jPortraits);
NuiSetBind(oPC, iToken, "names", jNames);
NuiSetBind(oPC, iToken, "colors", jColors);
NuiSetBind(oPC, iToken, "classes", jClasses);
NuiSetBind(oPC, iToken, "races", jRaces);
```

### Inference

- `NuiBind("...")` is a builder-level bind reference, not a literal JSON string.
- The exact raw JSON serialization of bind references is still unknown.
- `list` is likely bind-backed and not a simple literal `children` container.

## Layout System

### CONFIRMED

- `NuiRow` is the horizontal container builder.
- `NuiCol` is the vertical container builder used in the sample.
- `NuiGroup` is a container/decorator.
- `NuiSetGroupLayout` can replace group layout at runtime.

### Inference

- `column` is not the public JSON widget name in the tested runtime.
- The builder API prefers `NuiCol` over a raw `column` JSON node.
- `direction="vertical"` and `orientation="vertical"` on `row` were accepted by the runtime parser in black-box tests but did not change orientation.

## Hidden / Additional Widgets

### Confirmed from engine symbols

- `check`
- `combo`
- `tree`
- `chart`
- `progress`
- `slider`
- `textedit`
- `movieplayer`
- `options`
- `tabbar`

### Likely public wrappers

- The public wrapper names are not fully recovered locally.
- The internal engine symbols are confirmed, but script-visible helper names remain partly unknown.

## What is still unknown

- Exact source file contents of `nw_inc_nui.nss`
- Exact source file contents of `nw_nui_demo.nss`
- Exact source file contents of `nw_nui_insp.nss`
- Exact raw JSON serialization of `NuiBind(...)`
- Exact constructor JSON schema for bind-backed `list`
- `NuiTextEdit` script wrapper signature is not yet fully recovered; engine symbol confirms the internal textedit implementation, but compile-probes still need the correct wrapper arity

## Builder-based PoC

### Status

Compiled successfully with `nwn_script_comp` using `#include "nw_inc_nui"`.

### Current harness

- `ML_Version.nss` now uses builder helpers only
- raw JSON / `JsonParse` are no longer used
- the current window is a two-row `NuiCol` / `NuiRow` PoC:
  - row 1: `NuiLabel("A")`, `NuiSpacer()`, `NuiLabel("B")`
  - row 2: `NuiButton("OK")`, `NuiSpacer()`, `NuiButton("Cancel")`

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
