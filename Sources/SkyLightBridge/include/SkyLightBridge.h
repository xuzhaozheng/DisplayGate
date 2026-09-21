#pragma once
#include <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

// Runtime-resolved wrappers around undocumented SkyLight symbols.
bool sl_get_display_list(uint32_t maxDisplays, CGDirectDisplayID *displays, uint32_t *displayCount);
CGError sl_configure_display_enabled(CGDisplayConfigRef config, CGDirectDisplayID displayID, bool enabled);
bool sl_is_available(void);
bool sl_copy_display_name(CGDirectDisplayID displayID, char *buffer, size_t bufferSize);
