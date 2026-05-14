// modules/SideloadPatch/WASideloadPatch.xm
// ─────────────────────────────────────────────────────────────────────────────
// Sideload compatibility patch for WhatsApp.
// Built only when SIDESTORE is defined (see Makefile).
//
// Fixes keychain, app groups access when running as a sideloaded IPA.
// Adapted from RyukGram-Fork/dev2/modules/SideloadPatch/SideloadPatch.xm
// with WA-specific bundle IDs and access group resolution.
//
// What it does:
//   - Resolves the real app-group access group from LSBundleProxy entitlements
//   - Rewrites kSecAttrAccessGroup on SecItemAdd / SecItemCopyMatching /
//     SecItemUpdate calls so items land in the correct group
//   - Does NOT rewrite SecItemDelete
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../modules/fishhook/fishhook.h"

static NSString *waSLBundleId      = nil;
static NSString *waSLAccessGroupId = nil;

static OSStatus (*orig_WASecItemAdd)(CFDictionaryRef, CFTypeRef *)          = NULL;
static OSStatus (*orig_WASecItemCopyMatching)(CFDictionaryRef, CFTypeRef *) = NULL;
static OSStatus (*orig_WASecItemUpdate)(CFDictionaryRef, CFDictionaryRef)   = NULL;
static OSStatus (*orig_WASecItemDelete)(CFDictionaryRef)                    = NULL;

static NSString *wasl_AppGroupPath  = nil;
static dispatch_once_t wasl_Once    = 0;

static NSString *waslGetAppGroupPath(void) {
    dispatch_once(&wasl_Once, ^{
        waSLBundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"net.whatsapp.WhatsApp";

        Class lsbp = objc_getClass("LSBundleProxy");
        if (!lsbp) return;
        id proxy = ((id (*)(id, SEL))objc_msgSend)(
            (id)lsbp, sel_registerName("bundleProxyForCurrentProcess"));
        if (!proxy) return;
        NSDictionary *ents = ((NSDictionary *(*)(id, SEL))objc_msgSend)(
            proxy, sel_registerName("entitlements"));
        if (![ents isKindOfClass:[NSDictionary class]]) return;
        NSArray *groups = ents[@"com.apple.security.application-groups"];
        if (!groups.count) return;
        NSDictionary *urls = ((NSDictionary *(*)(id, SEL))objc_msgSend)(
            proxy, sel_registerName("groupContainerURLs"));
        if (![urls isKindOfClass:[NSDictionary class]]) return;
        NSURL *url = urls[groups.firstObject];
        if (url) {
            wasl_AppGroupPath  = [url path];
            waSLAccessGroupId  = groups.firstObject;
        }
    });
    return wasl_AppGroupPath;
}

static OSStatus wasl_SecItemAdd(CFDictionaryRef attrs, CFTypeRef *result) {
    (void)waslGetAppGroupPath();
    if (attrs && waSLAccessGroupId) {
        NSMutableDictionary *q = [(__bridge NSDictionary *)attrs mutableCopy];
        q[(__bridge id)kSecAttrAccessGroup] = waSLAccessGroupId;
        return orig_WASecItemAdd((__bridge CFDictionaryRef)q, result);
    }
    return orig_WASecItemAdd(attrs, result);
}

static OSStatus wasl_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    (void)waslGetAppGroupPath();
    if (query && waSLAccessGroupId) {
        NSMutableDictionary *q = [(__bridge NSDictionary *)query mutableCopy];
        q[(__bridge id)kSecAttrAccessGroup] = waSLAccessGroupId;
        return orig_WASecItemCopyMatching((__bridge CFDictionaryRef)q, result);
    }
    return orig_WASecItemCopyMatching(query, result);
}

static OSStatus wasl_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attrs) {
    (void)waslGetAppGroupPath();
    if (query && waSLAccessGroupId) {
        NSMutableDictionary *q = [(__bridge NSDictionary *)query mutableCopy];
        q[(__bridge id)kSecAttrAccessGroup] = waSLAccessGroupId;
        return orig_WASecItemUpdate((__bridge CFDictionaryRef)q, attrs);
    }
    return orig_WASecItemUpdate(query, attrs);
}

// SecItemDelete intentionally NOT rewritten
static OSStatus wasl_SecItemDelete(CFDictionaryRef query) {
    return orig_WASecItemDelete(query);
}

__attribute__((constructor))
static void WASideloadPatchInit(void) {
    @autoreleasepool {
        (void)waslGetAppGroupPath();
        struct rebinding b[] = {
            {"SecItemAdd",          (void *)wasl_SecItemAdd,          (void **)&orig_WASecItemAdd},
            {"SecItemCopyMatching", (void *)wasl_SecItemCopyMatching, (void **)&orig_WASecItemCopyMatching},
            {"SecItemUpdate",       (void *)wasl_SecItemUpdate,       (void **)&orig_WASecItemUpdate},
            {"SecItemDelete",       (void *)wasl_SecItemDelete,       (void **)&orig_WASecItemDelete},
        };
        rebind_symbols(b, 4);
        NSLog(@"[WAGram][SideloadPatch] installed — bundle=%@ accessGroup=%@",
              waSLBundleId ?: @"?", waSLAccessGroupId ?: @"(none)");
    }
}
