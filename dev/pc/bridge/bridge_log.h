#pragma once

#include <string>

namespace bridge_log {

void log_line(const std::string& line);
void log_format(const char* fmt, ...);
std::string make_timestamp();
std::string resolve_log_path();

} // namespace bridge_log

