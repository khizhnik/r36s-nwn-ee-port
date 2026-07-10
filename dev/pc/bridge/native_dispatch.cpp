#include "native_dispatch.h"

#include "bridge_log.h"

#include <cinttypes>
#include <cstdint>
#include <cstring>
#include <string>

namespace {

using CreateLoadGamePanelFn = void* (*)(void*, int);
using SelectTabFn = void (*)(void*, int);
using HandleSelectSaveGameFn = void (*)(void*, int);
using SendLoadGameRequestFn = void (*)(void*);

constexpr uintptr_t kOffPanelTabset = 0x948;
constexpr uintptr_t kOffPanelSelectedIndex = 0x960;

std::string ptr_string(void* p)
{
    char buf[32];
    std::snprintf(buf, sizeof(buf), "%p", p);
    return std::string(buf);
}

BridgeResult fail(BridgeStatus status, const char* diagnostic,
                  void* client_internal = nullptr, void* panel = nullptr, void* tabset = nullptr)
{
    return BridgeResult{status, diagnostic, client_internal, panel, tabset};
}

} // namespace

BridgeResult LoadSaveByIndexImpl(int index)
{
    bridge_log::log_format("request index=%d", index);

    if (index < 0) {
        bridge_log::log_line("reject: negative index");
        return fail(BridgeStatus::InvalidIndex, "negative index");
    }

    NativeSymbols symbols {};
    std::string sym_diag;
    if (!ResolveNativeSymbols(&symbols, &sym_diag)) {
        bridge_log::log_format("reject: native symbols missing: %s", sym_diag.c_str());
        return fail(BridgeStatus::UnsupportedBinary, "unsupported binary");
    }

    bridge_log::log_format(
        "resolved symbols base=%#" PRIxPTR " create=%#" PRIxPTR " select=%#" PRIxPTR " handle=%#" PRIxPTR " send=%#" PRIxPTR,
        symbols.exe_base,
        symbols.cclient_create_load_panel,
        symbols.cgui_tabset_select_tab,
        symbols.cpanel_handle_select_save_game,
        symbols.cpanel_send_load_game_request);

    NativePointers ptrs {};
    std::string ptr_diag;
    if (!ResolveNativePointers(symbols, &ptrs, &ptr_diag)) {
        bridge_log::log_format("reject: pointer resolution failed: %s", ptr_diag.c_str());
        if (ptr_diag.find("g_pAppManager") != std::string::npos) {
            return fail(BridgeStatus::AppPointerMissing, "g_pAppManager missing");
        }
        return fail(BridgeStatus::PanelMissing, "panel missing");
    }

    bridge_log::log_format(
        "resolved ptrs app_manager=%s client_app=%s internal=%s panel=%s tabset=%s visible_count=%u current=%u",
        ptr_string(ptrs.app_manager).c_str(),
        ptr_string(ptrs.client_app).c_str(),
        ptr_string(ptrs.internal_app).c_str(),
        ptr_string(ptrs.panel).c_str(),
        ptr_string(ptrs.tabset).c_str(),
        ptrs.visible_count,
        ptrs.selected_index);

    if (ptrs.panel == nullptr) {
        bridge_log::log_line("reject: panel missing; open native Load panel first");
        return fail(BridgeStatus::PanelMissing, "panel missing");
    }
    if (ptrs.tabset == nullptr) {
        bridge_log::log_line("reject: tabset missing");
        return fail(BridgeStatus::PanelMissing, "tabset missing");
    }
    if (ptrs.visible_count == 0) {
        bridge_log::log_line("reject: visible save count is zero");
        return fail(BridgeStatus::InvalidIndex, "no visible saves");
    }
    if (static_cast<uint32_t>(index) >= ptrs.visible_count) {
        bridge_log::log_format("reject: index %d out of range (count=%u)", index, ptrs.visible_count);
        return fail(BridgeStatus::InvalidIndex, "index out of range");
    }

    auto select_tab = reinterpret_cast<SelectTabFn>(symbols.cgui_tabset_select_tab);
    auto handle_select = reinterpret_cast<HandleSelectSaveGameFn>(symbols.cpanel_handle_select_save_game);
    auto send_load = reinterpret_cast<SendLoadGameRequestFn>(symbols.cpanel_send_load_game_request);

    bridge_log::log_format("call SelectTab this=%s idx=%d current_before=%u",
                           ptr_string(ptrs.tabset).c_str(), index, ptrs.selected_index);
    select_tab(ptrs.tabset, index);

    const uint32_t after_select = *reinterpret_cast<uint32_t*>(reinterpret_cast<uint8_t*>(ptrs.panel) + kOffPanelSelectedIndex);
    bridge_log::log_format("after SelectTab current=%u", after_select);
    if (after_select != static_cast<uint32_t>(index)) {
        bridge_log::log_format("reject: selection verification failed (expected=%d got=%u)", index, after_select);
        return fail(BridgeStatus::SelectionFailed, "selection verification failed", ptrs.internal_app, ptrs.panel, ptrs.tabset);
    }

    bridge_log::log_format("call HandleSelectSaveGame this=%s idx=%d",
                           ptr_string(ptrs.panel).c_str(), index);
    handle_select(ptrs.panel, index);

    const uint32_t after_handle = *reinterpret_cast<uint32_t*>(reinterpret_cast<uint8_t*>(ptrs.panel) + kOffPanelSelectedIndex);
    bridge_log::log_format("after HandleSelectSaveGame current=%u", after_handle);
    if (after_handle != static_cast<uint32_t>(index)) {
        bridge_log::log_format("reject: selected index changed after HandleSelectSaveGame (expected=%d got=%u)", index, after_handle);
        return fail(BridgeStatus::SelectionFailed, "selection changed after callback", ptrs.internal_app, ptrs.panel, ptrs.tabset);
    }

    bridge_log::log_format("call SendLoadGameRequest this=%s current=%u",
                           ptr_string(ptrs.panel).c_str(), after_handle);
    send_load(ptrs.panel);

    bridge_log::log_line("status: ok");
    return BridgeResult{BridgeStatus::Ok, "ok", ptrs.internal_app, ptrs.panel, ptrs.tabset};
}

