#include "debug_command_poller.h"

#include "bridge_api.h"
#include "bridge_log.h"

#include <atomic>
#include <chrono>
#include <cerrno>
#include <cctype>
#include <climits>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <mutex>
#include <string>
#include <string_view>
#include <thread>
#include <unistd.h>

namespace debug_command_poller {
namespace {

constexpr const char* kCommandPath = "/tmp/nwn_load_bridge_command";
constexpr auto kPollInterval = std::chrono::milliseconds(300);

std::once_flag g_start_once;
std::atomic<bool> g_running{false};

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

bool is_nwmain_process(std::string* exe_path)
{
    std::string path;
    if (!read_self_exe(&path)) {
        return false;
    }

    if (exe_path != nullptr) {
        *exe_path = path;
    }

    const std::filesystem::path p(path);
    return p.filename() == "nwmain-linux";
}

std::string trim(std::string s)
{
    auto is_space = [](unsigned char ch) { return std::isspace(ch) != 0; };
    while (!s.empty() && is_space(static_cast<unsigned char>(s.front()))) {
        s.erase(s.begin());
    }
    while (!s.empty() && is_space(static_cast<unsigned char>(s.back()))) {
        s.pop_back();
    }
    return s;
}

bool parse_command(const std::string& text, int* index, std::string* diagnostic)
{
    if (index == nullptr) {
        if (diagnostic) {
            *diagnostic = "index output pointer is null";
        }
        return false;
    }

    const std::string cleaned = trim(text);
    constexpr std::string_view prefix = "LOAD_SAVE_INDEX";
    if (cleaned.rfind(prefix.data(), 0) != 0) {
        if (diagnostic) {
            *diagnostic = "unsupported command";
        }
        return false;
    }

    std::string rest = trim(cleaned.substr(prefix.size()));
    if (rest.empty()) {
        if (diagnostic) {
            *diagnostic = "missing index";
        }
        return false;
    }

    char* end = nullptr;
    errno = 0;
    long value = std::strtol(rest.c_str(), &end, 10);
    if (errno != 0 || end == rest.c_str() || !trim(std::string(end)).empty()) {
        if (diagnostic) {
            *diagnostic = "invalid index";
        }
        return false;
    }

    if (value < 0 || value > static_cast<long>(INT_MAX)) {
        if (diagnostic) {
            *diagnostic = "index out of range";
        }
        return false;
    }

    *index = static_cast<int>(value);
    return true;
}

void consume_command_file(const std::string& path)
{
    std::ifstream in(path);
    if (!in.is_open()) {
        bridge_log::log_format("debug poller: unable to open command file: %s", path.c_str());
        return;
    }

    std::string content((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    in.close();

    std::error_code ec;
    std::filesystem::remove(path, ec);

    bridge_log::log_format("debug poller: command content='%s'", trim(content).c_str());

    int index = -1;
    std::string diag;
    if (!parse_command(content, &index, &diag)) {
        bridge_log::log_format("debug poller: parse failed: %s", diag.c_str());
        return;
    }

    bridge_log::log_format("debug poller: dispatch LoadSaveByIndex(%d)", index);
    BridgeResult result = nwn_bridge_load_save_index(index);
    bridge_log::log_format("debug poller: result status=%d diagnostic=%s panel=%p tabset=%p internal=%p",
                           static_cast<int>(result.status),
                           result.diagnostic != nullptr ? result.diagnostic : "(null)",
                           result.panel,
                           result.tabset,
                           result.client_internal);
}

void run()
{
    bridge_log::log_format("debug poller: thread started path=%s interval_ms=%lld",
                           kCommandPath,
                           static_cast<long long>(kPollInterval.count()));
    while (g_running.load(std::memory_order_relaxed)) {
        std::error_code ec;
        if (std::filesystem::exists(kCommandPath, ec) && !ec) {
            consume_command_file(kCommandPath);
        }
        std::this_thread::sleep_for(kPollInterval);
    }
    bridge_log::log_line("debug poller: thread exiting");
}

void start_impl()
{
    const char* enabled = std::getenv("NWN_LOAD_BRIDGE_DEBUG_POLL");
    if (enabled == nullptr || enabled[0] == '\0' || enabled[0] == '0') {
        std::string exe_path;
        if (is_nwmain_process(&exe_path)) {
            bridge_log::log_format("debug poller: disabled exe=%s", exe_path.c_str());
        }
        return;
    }

    std::string exe_path;
    if (!is_nwmain_process(&exe_path)) {
        return;
    }

    g_running.store(true, std::memory_order_relaxed);
    std::thread(run).detach();
    bridge_log::log_format("debug poller: enabled exe=%s", exe_path.c_str());
}

} // namespace

void start_if_enabled()
{
    std::call_once(g_start_once, start_impl);
}

} // namespace debug_command_poller
