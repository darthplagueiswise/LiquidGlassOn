// WASideloadKeychainPatch.xm
// ─────────────────────────────────────────────────────────────────────────────
// Two responsibilities, controlled by a single toggle:
//
//   1. OBSERVER (always active when toggle ON):
//      Logs metadata for every SecItemAdd / SecItemCopyMatching /
//      SecItemUpdate / SecItemDelete call. NEVER touches kSecValueData.
//      Emits: bundle, caller image, kSecClass, kSecAttrService,
//             kSecAttrAccount, kSecAttrAccessGroup, OSStatus result.
//
//   2. REWRITER (active when a sideload accessGroup mismatch is detected):
//      Rewrites kSecAttrAccessGroup on Add / CopyMatching / Update so the
//      item lives in the bundle's actual entitlement group.
//      SecItemDelete is intentionally NOT rewritten — matches RyukGram policy.
//
// Toggle: kWAGRKeychain  (default OFF)
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import "../../modules/fishhook/fishhook.h"

// ── State ─────────────────────────────────────────────────────────────────────
static NSString *_wagrKCBundleId       = nil;
static NSString *_wagrKCAccessGroupId  = nil;
static dispatch_once_t _wagrKCOnce     = 0;

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef, CFTypeRef *)            = NULL;
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *)   = NULL;
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef, CFDictionaryRef)     = NULL;
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef)                      = NULL;

// ── Helpers ───────────────────────────────────────────────────────────────────
static NSString *WAGRKCCallerImage(void) {
    void *ret = __builtin_return_address(1); // 0 = this fn, 1 = caller
    Dl_info info;
    if (ret && dladdr(ret, &info) && info.dli_fname)
        return [[NSString stringWithUTF8String:info.dli_fname] lastPathComponent];
    return @"?";
}

/// Resolve the first app-group access group from LSBundleProxy entitlements.
static void WAGRKCResolveIdentifiers(void) {
    dispatch_once(&_wagrKCOnce, ^{
        _wagrKCBundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"net.whatsapp.WhatsApp";

        Class lsbp = objc_getClass("LSBundleProxy");
        if (!lsbp) return;
        id proxy = ((id (*)(id, SEL))objc_msgSend)(
            (id)lsbp, sel_registerName("bundleProxyForCurrentProcess"));
        if (!proxy) return;

        NSDictionary *ents = ((NSDictionary *(*)(id, SEL))objc_msgSend)(
            proxy, sel_registerName("entitlements"));
        if (![ents isKindOfClass:[NSDictionary class]]) return;

        NSArray *groups = ents[@"com.apple.security.application-groups"];
        if (groups.count) {
            NSDictionary *urls = ((NSDictionary *(*)(id, SEL))objc_msgSend)(
                proxy, sel_registerName("groupContainerURLs"));
            if ([urls isKindOfClass:[NSDictionary class]]) {
                _wagrKCAccessGroupId = groups.firstObject;
                NSLog(@"[WAGram][Keychain] resolved accessGroup = %@", _wagrKCAccessGroupId);
            }
        }
    });
}

/// Extract safe metadata from a SecItem query dict (never touches kSecValueData).
static NSString *WAGRKCMetadata(CFDictionaryRef dict) {
    if (!dict) return @"{}";
    NSDictionary *d = (__bridge NSDictionary *)dict;
    NSMutableString *s = [NSMutableString string];

    id cls  = d[(__bridge id)kSecClass];
    id svc  = d[(__bridge id)kSecAttrService];
    id acc  = d[(__bridge id)kSecAttrAccount];
    id grp  = d[(__bridge id)kSecAttrAccessGroup];
    id lbl  = d[(__bridge id)kSecAttrLabel];

    if (cls)  [s appendFormat:@" class=%@",   cls];
    if (svc)  [s appendFormat:@" service=%@", svc];
    if (acc)  [s appendFormat:@" account=%@", acc];
    if (grp)  [s appendFormat:@" accessGroup=%@", grp];
    if (lbl)  [s appendFormat:@" label=%@",   lbl];
    return s.length ? s : @" (no metadata keys)";
}

/// Optionally rewrite kSecAttrAccessGroup if we know our real group.
static NSMutableDictionary *WAGRKCRewriteCopy(CFDictionaryRef dict) {
    if (!dict || !_wagrKCAccessGroupId.length) return nil;
    NSDictionary *source = (__bridge NSDictionary *)dict;
    id existing = source[(__bridge id)kSecAttrAccessGroup];
    if ([existing isKindOfClass:NSString.class] && [existing isEqualToString:_wagrKCAccessGroupId]) return nil;
    NSMutableDictionary *q = [source mutableCopy];
    q[(__bridge id)kSecAttrAccessGroup] = _wagrKCAccessGroupId;
    return q;
}

// ── Replacements ──────────────────────────────────────────────────────────────
static OSStatus wagr_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    WAGRKCResolveIdentifiers();
    if (!WAGRPref(kWAGRKeychain))
        return orig_SecItemAdd(attributes, result);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta   = WAGRKCMetadata(attributes);
    NSMutableDictionary *rewritten = WAGRKCRewriteCopy(attributes);
    OSStatus status = orig_SecItemAdd(rewritten ? (__bridge CFDictionaryRef)rewritten : attributes, result);
    NSLog(@"[WAGram][Keychain] SecItemAdd  caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

static OSStatus wagr_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    WAGRKCResolveIdentifiers();
    if (!WAGRPref(kWAGRKeychain))
        return orig_SecItemCopyMatching(query, result);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta   = WAGRKCMetadata(query);
    NSMutableDictionary *rewritten = WAGRKCRewriteCopy(query);
    OSStatus status = orig_SecItemCopyMatching(rewritten ? (__bridge CFDictionaryRef)rewritten : query, result);
    NSLog(@"[WAGram][Keychain] SecItemCopy caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

static OSStatus wagr_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attrs) {
    WAGRKCResolveIdentifiers();
    if (!WAGRPref(kWAGRKeychain))
        return orig_SecItemUpdate(query, attrs);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta   = WAGRKCMetadata(query);
    NSMutableDictionary *rewrittenQ = WAGRKCRewriteCopy(query);
    OSStatus status = orig_SecItemUpdate(rewrittenQ ? (__bridge CFDictionaryRef)rewrittenQ : query, attrs);
    NSLog(@"[WAGram][Keychain] SecItemUpdate caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

static OSStatus wagr_SecItemDelete(CFDictionaryRef query) {
    // Delete is NOT rewritten — observer only
    if (!WAGRPref(kWAGRKeychain))
        return orig_SecItemDelete(query);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta   = WAGRKCMetadata(query);
    OSStatus status = orig_SecItemDelete(query);
    NSLog(@"[WAGram][Keychain] SecItemDelete caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

// ── Diagnostic UI helper (called from menu) ───────────────────────────────────
NSString *WAGRKeychainDiagnosticText(void) {
    WAGRKCResolveIdentifiers();
    return [NSString stringWithFormat:
        @"bundle     = %@\naccessGroup = %@\nhooks       = %@",
        _wagrKCBundleId ?: @"(null)",
        _wagrKCAccessGroupId ?: @"(not resolved — needs app-group entitlement)",
        (orig_SecItemAdd ? @"installed" : @"NOT installed")];
}

// ── Constructor ───────────────────────────────────────────────────────────────
__attribute__((constructor))
static void WAGRKeychainPatchInit(void) {
    @autoreleasepool {
        // Install fishhook-based replacements regardless of toggle so we can
        // observe from the very first call once the user enables the pref.
        struct rebinding bindings[] = {
            {"SecItemAdd",          (void *)wagr_SecItemAdd,          (void **)&orig_SecItemAdd},
            {"SecItemCopyMatching", (void *)wagr_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching},
            {"SecItemUpdate",       (void *)wagr_SecItemUpdate,       (void **)&orig_SecItemUpdate},
            {"SecItemDelete",       (void *)wagr_SecItemDelete,       (void **)&orig_SecItemDelete},
        };
        rebind_symbols(bindings, 4);
        NSLog(@"[WAGram][Keychain] fishhook bindings installed");
    }
}
