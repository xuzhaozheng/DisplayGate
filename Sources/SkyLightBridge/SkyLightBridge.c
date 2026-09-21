#include "SkyLightBridge.h"
#include <dlfcn.h>
#include <IOKit/graphics/IOGraphicsLib.h>

static void *skyLightHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

typedef CGError (*ConfigureFn)(CGDisplayConfigRef, CGDirectDisplayID, bool);
typedef CGError (*GetListFn)(uint32_t, CGDirectDisplayID *, uint32_t *);

bool sl_is_available(void) {
    void *h = skyLightHandle();
    return h && dlsym(h, "SLSConfigureDisplayEnabled") && dlsym(h, "SLSGetDisplayList");
}

bool sl_get_display_list(uint32_t maxDisplays, CGDirectDisplayID *displays, uint32_t *displayCount) {
    void *h = skyLightHandle();
    GetListFn fn = h ? (GetListFn)dlsym(h, "SLSGetDisplayList") : NULL;
    if (!fn) return false;
    return fn(maxDisplays, displays, displayCount) == kCGErrorSuccess;
}

CGError sl_configure_display_enabled(CGDisplayConfigRef config, CGDirectDisplayID displayID, bool enabled) {
    void *h = skyLightHandle();
    ConfigureFn fn = h ? (ConfigureFn)dlsym(h, "SLSConfigureDisplayEnabled") : NULL;
    if (!fn) return kCGErrorNotImplemented;
    return fn(config, displayID, enabled);
}

bool sl_copy_display_name(CGDirectDisplayID displayID, char *buffer, size_t bufferSize) {
    if (!buffer || bufferSize == 0) return false;
    io_service_t service = CGDisplayIOServicePort(displayID);
    if (!service) return false;
    CFDictionaryRef info = IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
    if (!info) return false;
    CFDictionaryRef names = CFDictionaryGetValue(info, CFSTR(kDisplayProductName));
    CFStringRef name = NULL;
    if (names && CFGetTypeID(names) == CFDictionaryGetTypeID()) {
        CFIndex count = CFDictionaryGetCount(names);
        const void *keys[count]; const void *values[count];
        CFDictionaryGetKeysAndValues(names, keys, values);
        if (count > 0 && CFGetTypeID(values[0]) == CFStringGetTypeID()) name = (CFStringRef)values[0];
    }
    bool ok = name && CFStringGetCString(name, buffer, bufferSize, kCFStringEncodingUTF8);
    CFRelease(info);
    return ok;
}
