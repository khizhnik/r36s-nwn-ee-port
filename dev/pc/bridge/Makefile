CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Wpedantic -fPIC
LDFLAGS ?= -shared -ldl -pthread

SRC := \
	bridge_api.cpp \
	bridge_log.cpp \
	debug_command_poller.cpp \
	native_dispatch.cpp \
	native_resolver.cpp

BUILD_DIR := build
TARGET := $(BUILD_DIR)/libnwn_load_bridge.so
OBJ := $(SRC:%.cpp=$(BUILD_DIR)/%.o)

.PHONY: all clean

all: $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: %.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -I. -c $< -o $@

$(TARGET): $(OBJ)
	$(CXX) $(OBJ) $(LDFLAGS) -o $@

clean:
	rm -rf $(BUILD_DIR)
