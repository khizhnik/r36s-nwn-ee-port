#include "bridge_log.h"

#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <dlfcn.h>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>

namespace bridge_log {

namespace {

std::mutex& log_mutex()
{
    static std::mutex m;
    return m;
}

std::string& cached_path()
{
    static std::string path;
    return path;
}

std::string strip_bridge_suffix(std::string path)
{
    const std::string marker = "/dev/pc/bridge/build/";
    const auto pos = path.rfind(marker);
    if (pos != std::string::npos) {
        return path.substr(0, pos);
    }
    const auto pos2 = path.rfind("/dev/pc/bridge/");
    if (pos2 != std::string::npos) {
        return path.substr(0, pos2);
    }
    return {};
}

void ensure_parent_dirs(const std::string& file_path)
{
    std::filesystem::path p(file_path);
    std::error_code ec;
    std::filesystem::create_directories(p.parent_path(), ec);
}

} // namespace

std::string make_timestamp()
{
    using clock = std::chrono::system_clock;
    const auto now = clock::now();
    const auto tt = clock::to_time_t(now);
    const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;

    std::tm tm {};
    localtime_r(&tt, &tm);

    char buf[64];
    std::snprintf(buf, sizeof(buf), "%04d-%02d-%02d %02d:%02d:%02d.%03lld",
                  tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                  tm.tm_hour, tm.tm_min, tm.tm_sec,
                  static_cast<long long>(ms.count()));
    return std::string(buf);
}

std::string resolve_log_path()
{
    auto& path = cached_path();
    if (!path.empty()) {
        return path;
    }

    Dl_info info {};
    if (dladdr(reinterpret_cast<void*>(&resolve_log_path), &info) != 0 && info.dli_fname != nullptr) {
        const std::string root = strip_bridge_suffix(info.dli_fname);
        if (!root.empty()) {
            path = root + "/dev/pc/logs/native-load-bridge.log";
            return path;
        }
    }

    path = "dev/pc/logs/native-load-bridge.log";
    return path;
}

void log_line(const std::string& line)
{
    std::lock_guard<std::mutex> lock(log_mutex());
    const std::string path = resolve_log_path();
    ensure_parent_dirs(path);

    std::ofstream out(path, std::ios::app);
    out << make_timestamp() << " " << line << "\n";
    out.flush();
}

void log_format(const char* fmt, ...)
{
    char buf[2048];
    va_list ap;
    va_start(ap, fmt);
    std::vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    log_line(buf);
}

} // namespace bridge_log

