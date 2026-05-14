#import "WAKeychainPatch.h"
#import "WAPrefix.h"
#import "WAUtils.h"
#import <Security/Security.h>
#import <dlfcn.h>
#import <stdatomic.h>
#import "../modules/fishhook/fishhook.h"

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result) = NULL;
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result) = NULL;
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) = NULL;

static NSString *gWAAccessGroup = nil;
static atomic_bool gWAKeychainPatchInstalled = false;
static atomic_bool gWAKeychainProbeActive = false;

static BOOL WAKeychainRewriteEnabled(void) {
    return WAEnabled(WA_PREF_KEYCHAIN_REWRITE);
}

static NSString *WAProbeService(void) {
    return @"LiquidGlassOn.WAKeychainProbe";
}

static NSString *WAProbeAccount(void) {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"WhatsApp";
    return [@"probe." stringByAppendingString:bundle];
}

static NSString *WAExtractAccessGroupFromAttributes(NSDictionary *attrs) {
    id group = attrs[(__bridge id)kSecAttrAccessGroup];
    return [group isKindOfClass:NSString.class] ? group : nil;
}

static NSString *WADetectAccessGroup(void) {
    if (gWAAccessGroup.length) return gWAAccessGroup;
    if (atomic_exchange(&gWAKeychainProbeActive, true)) return nil;

    NSString *service = WAProbeService();
    NSString *account = WAProbeAccount();
    NSData *data = [@"LiquidGlassOn" dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableDictionary *deleteQuery = [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account
    } mutableCopy];
    SecItemDelete((__bridge CFDictionaryRef)deleteQuery);

    NSDictionary *add = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    SecItemAdd((__bridge CFDictionaryRef)add, NULL);

    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    NSString *group = nil;
    if (status == errSecSuccess && result) {
        NSDictionary *attrs = CFBridgingRelease(result);
        group = WAExtractAccessGroupFromAttributes(attrs);
    } else if (result) {
        CFRelease(result);
    }

    if (group.length) {
        gWAAccessGroup = group;
        [NSUserDefaults.standardUserDefaults setObject:group forKey:@"wa_keychain_access_group_detected"];
        [NSUserDefaults.standardUserDefaults synchronize];
    }

    atomic_store(&gWAKeychainProbeActive, false);
    return group;
}

NSString *WAKeychainAccessGroupDiagnostic(void) {
    NSString *group = WADetectAccessGroup();
    return [NSString stringWithFormat:@"rewrite=%@\naccessGroup=%@\nbundle=%@",
            WAKeychainRewriteEnabled() ? @"ON" : @"OFF",
            group.length ? group : @"unavailable",
            NSBundle.mainBundle.bundleIdentifier ?: @"unknown"];
}

static CFDictionaryRef WACopyQueryWithAccessGroup(CFDictionaryRef input) {
    if (!input || !WAKeychainRewriteEnabled()) return NULL;
    if (atomic_load(&gWAKeychainProbeActive)) return NULL;

    NSDictionary *dict = (__bridge NSDictionary *)input;
    if (![dict isKindOfClass:NSDictionary.class]) return NULL;
    if (dict[(__bridge id)kSecAttrAccessGroup]) return NULL;

    NSString *group = WADetectAccessGroup();
    if (!group.length) return NULL;

    NSMutableDictionary *q = [dict mutableCopy];
    q[(__bridge id)kSecAttrAccessGroup] = group;
    return CFBridgingRetain(q);
}

static OSStatus replaced_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    CFDictionaryRef q = WACopyQueryWithAccessGroup(attributes);
    if (q) {
        OSStatus s = orig_SecItemAdd(q, result);
        CFRelease(q);
        return s;
    }
    return orig_SecItemAdd(attributes, result);
}

static OSStatus replaced_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    CFDictionaryRef q = WACopyQueryWithAccessGroup(query);
    if (q) {
        OSStatus s = orig_SecItemCopyMatching(q, result);
        CFRelease(q);
        return s;
    }
    return orig_SecItemCopyMatching(query, result);
}

static OSStatus replaced_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    CFDictionaryRef q = WACopyQueryWithAccessGroup(query);
    if (q) {
        OSStatus s = orig_SecItemUpdate(q, attributesToUpdate);
        CFRelease(q);
        return s;
    }
    return orig_SecItemUpdate(query, attributesToUpdate);
}

void WAInstallKeychainPatchIfNeeded(void) {
    if (!WAKeychainRewriteEnabled()) {
        WALog(@"keychain rewrite disabled; inert");
        return;
    }
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gWAKeychainPatchInstalled, &expected, true)) return;

    WADetectAccessGroup();
    struct rebinding binds[] = {
        {"SecItemAdd", (void *)replaced_SecItemAdd, (void **)&orig_SecItemAdd},
        {"SecItemCopyMatching", (void *)replaced_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching},
        {"SecItemUpdate", (void *)replaced_SecItemUpdate, (void **)&orig_SecItemUpdate}
    };
    rebind_symbols(binds, sizeof(binds) / sizeof(binds[0]));
    WALog(@"installed keychain rewrite; group=%@", gWAAccessGroup ?: @"nil");
}
