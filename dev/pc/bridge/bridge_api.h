#pragma once

#include <cstdint>

enum class BridgeStatus {
    Ok,
    InvalidIndex,
    NativeSymbolsMissing,
    AppPointerMissing,
    PanelMissing,
    SelectionFailed,
    LoadRequestFailed,
    UnsupportedBinary,
};

struct BridgeResult {
    BridgeStatus status;
    const char* diagnostic;
    void* client_internal;
    void* panel;
    void* tabset;
};

extern "C" BridgeResult nwn_bridge_load_save_index(int index);

