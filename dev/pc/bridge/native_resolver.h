#pragma once

#include <cstdint>
#include <string>

struct NativeSymbols {
    uintptr_t exe_base = 0;
    uintptr_t g_pAppManager = 0;
    uintptr_t cclient_create_load_panel = 0;
    uintptr_t cclient_destroy_load_panel = 0;
    uintptr_t cclient_internal_create_load_panel = 0;
    uintptr_t cclient_internal_destroy_load_panel = 0;
    uintptr_t cgui_tabset_select_tab = 0;
    uintptr_t cpanel_handle_select_save_game = 0;
    uintptr_t cpanel_send_load_game_request = 0;
};

struct NativePointers {
    void* app_manager = nullptr;
    void* client_app = nullptr;
    void* internal_app = nullptr;
    void* panel = nullptr;
    void* tabset = nullptr;
    uint32_t visible_count = 0;
    uint32_t selected_index = 0;
};

bool ResolveNativeSymbols(NativeSymbols* out, std::string* diagnostic);
bool ResolveNativePointers(const NativeSymbols& symbols, NativePointers* out, std::string* diagnostic);

