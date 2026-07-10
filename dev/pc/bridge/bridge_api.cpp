#include "bridge_api.h"
#include "debug_command_poller.h"
#include "native_dispatch.h"

namespace {

__attribute__((constructor)) void bridge_constructor()
{
    debug_command_poller::start_if_enabled();
}

} // namespace

extern "C" __attribute__((visibility("default"))) BridgeResult nwn_bridge_load_save_index(int index)
{
    return LoadSaveByIndexImpl(index);
}
