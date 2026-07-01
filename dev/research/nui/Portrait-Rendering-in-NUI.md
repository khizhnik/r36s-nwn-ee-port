# Portrait Rendering in NWN:EE NUI

## Purpose

Document how character portraits are rendered inside NUI.

This avoids repeating reverse engineering and internet research in future work.

---

# Result

Portrait rendering in NUI **works**.

The important discovery is that the portrait stored in `player.bic` is **not directly renderable**.

Example:

```
player.bic

PortraitResRef:

po_hu_m_21_
```

Using

```nss
NuiImage(JsonString("po_hu_m_21_"), ...)
```

does **NOT** render.

---

# Correct approach

Append a portrait size suffix.

For example

```
po_hu_m_21_
```

becomes

```
po_hu_m_21_m
```

and

```nss
NuiImage(JsonString("po_hu_m_21_m"), ...)
```

renders correctly.

---

# Verified suffixes

The following portrait variants successfully render:

```
_h
_l
_m
```

Example

```
po_hu_m_21_h
po_hu_m_21_l
po_hu_m_21_m
```

All resolve to valid portrait resources.

---

# Recommended suffix

For R36S use

```
_m
```

Reason:

The display resolution is

```
640×480
```

The medium portrait provides a good balance between quality and screen space.

---

# Current Load Screen implementation

The wrapper extracts

```
PortraitResRef
```

from

```
player.bic
```

Example

```
po_hu_m_21_
```

NWScript derives

```
sPortraitImage = sPortraitResRef + "m";
```

The resulting value is passed directly into

```nss
NuiImage(...)
```

No filesystem access is performed from NWScript.

No TGA decoding is required.

No portrait copy is required.

---

# Important discovery

The portrait image does **NOT** come from

```
portrait.tga
```

inside the save folder.

Instead, the save stores a portrait **resource reference**.

NUI resolves that resource automatically.

---

# Resource pipeline

```
player.bic
        │
        ▼
PortraitResRef

        │
        ▼
wrapper

        │
        ▼
r36s_saveindex.txt

        │
        ▼
ResManGetFileContents()

        │
        ▼
NWScript

        │
        ▼
append "m"

        │
        ▼
NuiImage(resref)
```

---

# Do NOT do

Do not:

* copy portrait.tga
* decode TGA
* convert images
* load portrait through ResManGetFileContents()
* pass filesystem paths into NuiImage()

All of these are unnecessary.

---

# Future work

The screenshot shown in the Load screen is different.

Unlike portraits, save screenshots are stored as

```
screen.tga
```

inside the save directory.

The screenshot rendering mechanism is still under investigation.

It is unknown whether NuiImage can render dynamically copied TGAs using the same resource lookup mechanism.

This should be treated as a separate research task.

---

# Lessons learned

The original Load screen architecture was correct.

Instead of copying image files into NUI, the bridge should transport **resource identifiers**, letting the engine resolve built-in assets whenever possible.

Only assets without a resource reference (for example save screenshots) require additional investigation.
