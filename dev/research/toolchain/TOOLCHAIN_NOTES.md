# AuroraBorealius / NWN Toolchain Notes

## Summary

This repository is useful as a future CLI-capable module editing foundation, but not yet as the immediate primary path for the first bootstrap module.

Short-term:
Use NWToolset via Wine for the first manual `r36s_launcher.mod`.

Medium-term:
Use `nwn-gamemodel` + `nwn-gff` + `nwn-erf` as a possible automated bootstrap module generator.

## Tool inventory

| tool | language | purpose | can list | can extract | can pack | can edit GFF | status |
|---|---|---|---:|---:|---:|---:|---|
| `nevererf` | Rust | ERF archive CLI | yes | yes | no, `create` is not implemented | no | source confirmed, incomplete for packing |
| `nwn-erf` | Rust library | ERF archive read/write library | yes | yes | yes, via library API | no | confirmed, library-level packing exists |
| `nwn-gff` | Rust library | GFF parse/edit/write library | n/a | n/a | n/a | yes | confirmed, directly useful for `module.ifo`, `.are`, `.git` |
| `nwn-script` | Rust library | NWScript lexer/parser/preprocessor/codegen | n/a | n/a | n/a | no | confirmed, script-source processing layer |
| `nevercommand` | Rust | NWN resource CLI | yes | yes | no | read-only pretty-print only | confirmed, inspection-oriented |
| `aurora-borealis` | Rust + GUI | Toolset/editor application | yes, via UI | yes, via UI | likely yes, via app workflow | yes | confirmed as the main GUI editor/toolset clone |
| `nwnsc.exe` | Windows PE binary | NWScript compiler binary | unknown from local source | unknown | unknown | no | confirmed binary only, Windows-only artifact |

## Best candidate tools

- `aurora-borealis`: GUI editor/toolset clone
- `nwn-gamemodel`: programmatic module editor, strongest automation candidate
- `nwn-gff`: `module.ifo` / `.are` / `.git` editing
- `nwn-erf`: ERF/MOD archive read/write library
- `nwn-script`: script-source processing
- `nevererf` / `nevercommand`: inspection-oriented, not primary packers

## Build feasibility

- `cargo` / `rustc` absent locally in current environment
- source-level feasibility strong
- local build not confirmed

## Decision

Immediate path:
NWToolset via Wine.

Parallel path:
AuroraBorealius CLI/library research for reproducible automation.
