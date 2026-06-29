# NWN:EE R36S Port

This repository contains the development version of the **Neverwinter Nights: Enhanced Edition** port for the **R36S (RK3326)**.

The runnable port lives in:

```
r36s-nwn-ee-port/port
```

This directory is the **runtime root** of the port.

Do **not** change its layout unless a modification has been experimentally verified on real hardware.

---

## Game files

This repository does **not** contain copyrighted game assets.

Populate the port using a licensed installation of **Neverwinter Nights: Enhanced Edition** (Steam or GOG).

The following resources are required:

* `bin/`
* `data/`
* `lang/`
* any other required game resources from the original installation

Without these files the port will not run.

---

## Runtime layout

The current directory layout is **intentional**.

Multiple alternative layouts were tested on real R36S hardware and caused startup failures or crashes.

The following directories must remain in their current locations:

```
port/
├── bin/
├── data/
├── gl4es.aarch64/
├── lang/
├── libs/
├── ovr/
├── nwmain-linux.gptk
├── nwn-play.sh
└── xorg-nwn.conf
```

Until proven otherwise, treat this layout as canonical.

---

## Known regressions

The following changes have already been tested and are known to break the port:

* moving `gl4es.aarch64`
* replacing `libs` with another directory layout
* moving runtime logging outside the port directory
* restructuring the runtime tree without validating on hardware

Please do **not** repeat these experiments unless you are intentionally re-evaluating them.

---

## Launcher

`nwn-play.sh` is the runtime launcher.

Its current implementation is based on extensive testing on real R36S hardware.

When modifying the launcher:

* preserve the launch sequence
* preserve cleanup and timeout behaviour
* preserve the working runtime layout
* make the smallest possible changes

Large launcher refactors are discouraged unless they solve a verified problem.

---

## Xorg

The current launcher requires an Xorg configuration compatible with DarkOS.

Additional documentation will be added as this work progresses.

---

## Development

Experimental work belongs under `dev/`.

The `port/` directory should always remain a runnable build.

Development artifacts, experiments, temporary scripts and research should never be mixed into the runtime tree.

---

## License

This repository contains only launcher code, tooling and original development work.

Game assets are **not** included and must be obtained from a legally owned copy of Neverwinter Nights: Enhanced Edition.