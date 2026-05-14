// WASideloadKeychainPatch.xm
// ─────────────────────────────────────────────────────────────────────────────
// Observer/rewriter for sideload Keychain compatibility.
// Toggle: kWAGRKeychain (default OFF).
// SecItemDelete is observed only and is never rewritten.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../../modules/fishhook/fishhook.h"

static NSString *_wagrKCBundleId = nil;
static NSString *_wagrKCAccessGroupId = nil;
static dispatch_once_t _wagrKCOnce = 0;

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef, CFTypeRef *) = NULL;
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *) = NULL;
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef, CFDictionaryRef) = NULL;
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef) = NULL;

static NSString *WAGRKCCallerImage(void) {
    // Avoid __builtin_return_address(1): clang treats nonzero frame access as unsafe
    // with -Wframe-address under Theos/GitHub Actions. Runtime diagnostics still log
    // bundle + keychain metadata without touching secrets.
    return [[NSBundle mainBundle] executablePath].lastPathComponent ?: @"WhatsApp";
}

static void WAGRKCResolveIdentifiers(void) {
    dispatch_once(&_wagrKCOnce, ^{
        _wagrKCBundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"net.whatsapp.WhatsApp";

        Class lsbp = objc_getClass("LSBundleProxy");
        if (!lsbp) return;

        SEL proxySel = sel_registerName("bundleProxyForCurrentProcess");
        if (![(id)lsbp respondsToSelector:proxySel]) return;
        id proxy = ((id (*)(id, SEL))objc_msgSend)((id)lsbp, proxySel);
        if (!proxy) return;

        SEL entSel = sel_registerName("entitlements");
        if (![proxy respondsToSelector:entSel]) return;
        NSDictionary *ents = ((NSDictionary *(*)(id, SEL))objc_msgSend)(proxy, entSel);
        if (![ents isKindOfClass:NSDictionary.class]) return;

        NSArray *keychainGroups = ents[@"keychain-access-groups"];
        if ([keychainGroups isKindOfClass:NSArray.class] && keychainGroups.count) {
            _wagrKCAccessGroupId = keychainGroups.firstObject;
            NSLog(@"[WAGram][Keychain] resolved keychain accessGroup = %@", _wagrKCAccessGroupId);
            return;
        }

        // Fallback for some sideload environments. This is not a true Keychain group,
        // but gives the diagnostic UI something useful instead of crashing.
        NSArray *appGroups = ents[@"com.apple.security.application-groups"];
        if ([appGroups isKindOfClass:NSArray.class] && appGroups.count) {
            _wagrKCAccessGroupId = appGroups.firstObject;
            NSLog(@"[WAGram][Keychain] fallback app group = %@", _wagrKCAccessGroupId);
        }
    });
}

static NSString *WAGRKCMetadata(CFDictionaryRef dict) {
    if (!dict) return @"{}";
    NSDictionary *d = (__bridge NSDictionary *)dict;
    NSMutableString *s = [NSMutableString string];

    id cls = d[(__bridge id)kSecClass];
    id svc = d[(__bridge id)kSecAttrService];
    id acc = d[(__bridge id)kSecAttrAccount];
    id grp = d[(__bridge id)kSecAttrAccessGroup];
    id lbl = d[(__bridge id)kSecAttrLabel];

    if (cls) [s appendFormat:@" class=%@", cls];
    if (svc) [s appendFormat:@" service=%@", svc];
    if (acc) [s appendFormat:@" account=%@", acc];
    if (grp) [s appendFormat:@" accessGroup=%@", grp];
    if (lbl) [s appendFormat:@" label=%@", lbl];
    return s.length ? s : @" (no metadata keys)";
}

static NSMutableDictionary *WAGRKCRewriteCopy(CFDictionaryRef dict) {
    if (!dict || !_wagrKCAccessGroupId.length) return nil;
    NSDictionary *source = (__bridge NSDictionary *)dict;
    id existing = source[(__bridge id)kSecAttrAccessGroup];
    if ([existing isKindOfClass:NSString.class] && [existing isEqualToString:_wagrKCAccessGroupId]) return nil;

    NSMutableDictionary *q = [source mutableCopy];
    q[(__bridge id)kSecAttrAccessGroup] = _wagrKCAccessGroupId;
    return q;
}

static OSStatus wagr_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    WAGRKCResolveIdentifiers();
    if (!WAGRPref(kWAGRKeychain)) return orig_SecItemAdd(attributes, result);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta = WAGRKCMetadata(attributes);
    NSMutableDictionary *rewritten = WAGRKCRewriteCopy(attributes);
    OSStatus status = orig_SecItemAdd(rewritten ? (__bridge CFDictionaryRef)rewritten : attributes, result);
    NSLog(@"[WAGram][Keychain] SecItemAdd caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

static OSStatus wagr_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    WAGRKCResolveIdentifiers();
    if (!WAGRPref(kWAGRKeychain)) return orig_SecItemCopyMatching(query, result);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta = WAGRKCMetadata(query);
    NSMutableDictionary *rewritten = WAGRKCRewriteCopy(query);
    OSStatus status = orig_SecItemCopyMatching(rewritten ? (__bridge CFDictionaryRef)rewritten : query, result);
    NSLog(@"[WAGram][Keychain] SecItemCopy caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

static OSStatus wagr_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attrs) {
    WAGRKCResolveIdentifiers();
    if (!WAGRPref(kWAGRKeychain)) return orig_SecItemUpdate(query, attrs);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta = WAGRKCMetadata(query);
    NSMutableDictionary *rewrittenQ = WAGRKCRewriteCopy(query);
    OSStatus status = orig_SecItemUpdate(rewrittenQ ? (__bridge CFDictionaryRef)rewrittenQ : query, attrs);
    NSLog(@"[WAGram][Keychain] SecItemUpdate caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

static OSStatus wagr_SecItemDelete(CFDictionaryRef query) {
    if (!WAGRPref(kWAGRKeychain)) return orig_SecItemDelete(query);

    NSString *caller = WAGRKCCallerImage();
    NSString *meta = WAGRKCMetadata(query);
    OSStatus status = orig_SecItemDelete(query);
    NSLog(@"[WAGram][Keychain] SecItemDelete caller=%@ meta={%@} status=%d", caller, meta, (int)status);
    return status;
}

extern "C" NSString *WAGRKeychainDiagnosticText(void) {
    WAGRKCResolveIdentifiers();
    return [NSString stringWithFormat:
        @"bundle     = %@\naccessGroup = %@\nhooks       = %@",
        _wagrKCBundleId ?: @"(null)",
        _wagrKCAccessGroupId ?: @"(not resolved)",
        (orig_SecItemAdd ? @"installed" : @"NOT installed")];
}

__attribute__((constructor))
static void WAGRKeychainPatchInit(void) {
    @autoreleasepool {
        struct rebinding bindings[] = {
            {"SecItemAdd", (void *)wagr_SecItemAdd, (void **)&orig_SecItemAdd},
            {"SecItemCopyMatching", (void *)wagr_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching},
            {"SecItemUpdate", (void *)wagr_SecItemUpdate, (void **)&orig_SecItemUpdate},
            {"SecItemDelete", (void *)wagr_SecItemDelete, (void **)&orig_SecItemDelete},
        };
        rebind_symbols(bindings, 4);
        NSLog(@"[WAGram][Keychain] fishhook bindings installed");
    }
}
