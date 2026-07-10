#include "native_resolver.h"

#include "bridge_log.h"

#include <cinttypes>
#include <cerrno>
#include <dlfcn.h>
#include <filesystem>
#include <link.h>
#include <string_view>
#include <unistd.h>
#include <string>

namespace {

constexpr uintptr_t kOffGAppManager = 0x18b9698;
constexpr uintptr_t kOffCreateLoadGamePanel = 0x636990;
constexpr uintptr_t kOffDestroyLoadGamePanel = 0x6369a0;
constexpr uintptr_t kOffInternalCreateLoadGamePanel = 0x63c020;
constexpr uintptr_t kOffInternalDestroyLoadGamePanel = 0x63bfd0;
constexpr uintptr_t kOffSelectTab = 0x596db0;
constexpr uintptr_t kOffHandleSelectSaveGame = 0x6fd500;
constexpr uintptr_t kOffSendLoadGameRequest = 0x6fa1d0;

struct BaseQuery {
    uintptr_t base = 0;
    std::string path;
    std::string self_exe;
    bool accept_empty_main = false;
};

bool read_self_exe(std::string* path)
{
    if (path == nullptr) {
        return false;
    }

    char buf[4096];
    const ssize_t len = ::readlink("/proc/self/exe", buf, sizeof(buf) - 1);
    if (len < 0) {
        return false;
    }
    buf[len] = '\0';
    *path = buf;
    return true;
}

bool is_nwmain_exe(const std::string& path)
{
    return std::filesystem::path(path).filename() == "nwmain-linux";
}

int phdr_callback(dl_phdr_info* info, size_t, void* data)
{
    auto* out = static_cast<BaseQuery*>(data);
    if (info->dlpi_name == nullptr || info->dlpi_name[0] == '\0') {
        if (!out->accept_empty_main) {
            return 0;
        }
        out->base = static_cast<uintptr_t>(info->dlpi_addr);
        out->path = out->self_exe;
        return 1;
    }
    if (std::string_view(info->dlpi_name).find("nwmain-linux") != std::string::npos) {
        out->base = static_cast<uintptr_t>(info->dlpi_addr);
        out->path = info->dlpi_name;
        return 1;
    }
    return 0;
}

} // namespace

bool ResolveNativeSymbols(NativeSymbols* out, std::string* diagnostic)
{
    if (out == nullptr) {
        if (diagnostic) {
            *diagnostic = "output pointer is null";
        }
        return false;
    }

    BaseQuery q {};
    if (!read_self_exe(&q.self_exe)) {
        if (diagnostic) {
            *diagnostic = "unsupported binary: unable to read /proc/self/exe";
        }
        return false;
    }

    if (!is_nwmain_exe(q.self_exe)) {
        if (diagnostic) {
            *diagnostic = "unsupported binary: not nwmain-linux";
        }
        return false;
    }

    q.accept_empty_main = true;
    dl_iterate_phdr(phdr_callback, &q);
    if (q.base == 0) {
        if (diagnostic) {
            *diagnostic = "unsupported binary: nwmain-linux base not found";
        }
        bridge_log::log_format("resolve symbols failed exe=%s reason=%s", q.self_exe.c_str(),
                               diagnostic != nullptr ? diagnostic->c_str() : "nwmain-linux base not found");
        return false;
    }

    out->exe_base = q.base;
    out->g_pAppManager = q.base + kOffGAppManager;
    out->cclient_create_load_panel = q.base + kOffCreateLoadGamePanel;
    out->cclient_destroy_load_panel = q.base + kOffDestroyLoadGamePanel;
    out->cclient_internal_create_load_panel = q.base + kOffInternalCreateLoadGamePanel;
    out->cclient_internal_destroy_load_panel = q.base + kOffInternalDestroyLoadGamePanel;
    out->cgui_tabset_select_tab = q.base + kOffSelectTab;
    out->cpanel_handle_select_save_game = q.base + kOffHandleSelectSaveGame;
    out->cpanel_send_load_game_request = q.base + kOffSendLoadGameRequest;
    bridge_log::log_format(
        "resolve symbols ok exe=%s base=%#" PRIxPTR " g_pAppManager=%#" PRIxPTR " create=%#" PRIxPTR " select=%#" PRIxPTR " handle=%#" PRIxPTR " send=%#" PRIxPTR,
        q.self_exe.c_str(),
        out->exe_base,
        out->g_pAppManager,
        out->cclient_create_load_panel,
        out->cgui_tabset_select_tab,
        out->cpanel_handle_select_save_game,
        out->cpanel_send_load_game_request);
    return true;
}

bool ResolveNativePointers(const NativeSymbols& symbols, NativePointers* out, std::string* diagnostic)
{
    if (out == nullptr) {
        if (diagnostic) {
            *diagnostic = "output pointer is null";
        }
        return false;
    }

    if (symbols.exe_base == 0) {
        if (diagnostic) {
            *diagnostic = "native symbols were not resolved";
        }
        return false;
    }

    auto* app_manager_slot = reinterpret_cast<void**>(symbols.g_pAppManager);
    void* app_manager = *app_manager_slot;
    if (app_manager == nullptr) {
        if (diagnostic) {
            *diagnostic = "g_pAppManager is null";
        }
        return false;
    }

    void* client_app = *reinterpret_cast<void**>(app_manager);
    if (client_app == nullptr) {
        if (diagnostic) {
            *diagnostic = "client app pointer is null";
        }
        return false;
    }

    void* internal_app = reinterpret_cast<void**>(client_app)[1];
    if (internal_app == nullptr) {
        if (diagnostic) {
            *diagnostic = "client internal pointer is null";
        }
        return false;
    }

    void* panel = reinterpret_cast<void**>(internal_app)[0xA0 / sizeof(void*)];
    void* tabset = nullptr;
    uint32_t visible_count = 0;
    uint32_t selected_index = 0;
    if (panel != nullptr) {
        tabset = reinterpret_cast<void*>(reinterpret_cast<uint8_t*>(panel) + 0x948);
        visible_count = *reinterpret_cast<uint32_t*>(reinterpret_cast<uint8_t*>(panel) + 0x970);
        selected_index = *reinterpret_cast<uint32_t*>(reinterpret_cast<uint8_t*>(panel) + 0x960);
    }

    out->app_manager = app_manager;
    out->client_app = client_app;
    out->internal_app = internal_app;
    out->panel = panel;
    out->tabset = tabset;
    out->visible_count = visible_count;
    out->selected_index = selected_index;

    bridge_log::log_format(
        "resolve pointers ok exe_base=%#" PRIxPTR " app_manager=%p client_app=%p internal=%p panel=%p tabset=%p visible_count=%u current=%u",
        symbols.exe_base,
        app_manager,
        client_app,
        internal_app,
        panel,
        tabset,
        visible_count,
        selected_index);
    return true;
}
