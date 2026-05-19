#import "WAKeychainPatch.h"
#import "WAPrefix.h"
#import "WAUtils.h"
#import <Security/Security.h>
#import <stdatomic.h>
#import "../modules/fishhook/fishhook.h"

static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result) = NULL;
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result) = NULL;
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) = NULL;
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef query) = NULL;

static NSString *gWAAccessGroup = nil;
static atomic_bool gWAKeychainHooksInstalled = false;
static atomic_bool gWAKeychainProbeActive = false;

static BOOL WAKeychainRewriteEnabled(void) {
    return WAEnabled(WA_PREF_KEYCHAIN_REWRITE);
}

static BOOL WAKeychainObserverEnabled(void) {
    return WAEnabled(WA_PREF_KEYCHAIN_OBSERVER);
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

static NSString *WAStringForKey(CFDictionaryRef query, CFStringRef key) {
    if (!query || !key) return @"";
    NSDictionary *dict = (__bridge NSDictionary *)query;
    id value = dict[(__bridge id)key];
    if (!value) return @"";
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSData.class]) return [NSString stringWithFormat:@"<data:%lu>", (unsigned long)[(NSData *)value length]];
    return WAStringFromObject(value);
}

static NSString *WACallerImage(void) {
    return [[NSBundle mainBundle] executablePath].lastPathComponent ?: @"WhatsApp";
}

static void WALogKeychainMetadata(NSString *op, CFDictionaryRef query, OSStatus status) {
    if (!WAKeychainObserverEnabled()) return;
    if (atomic_load(&gWAKeychainProbeActive)) return;
    NSString *secClass = WAStringForKey(query, kSecClass);
    NSString *service = WAStringForKey(query, kSecAttrService);
    NSString *account = WAStringForKey(query, kSecAttrAccount);
    NSString *group = WAStringForKey(query, kSecAttrAccessGroup);
    WALog(@"[KeychainObserver] op=%@ bundle=%@ caller=%@ class=%@ service=%@ account=%@ accessGroup=%@ status=%d",
          op ?: @"?",
          NSBundle.mainBundle.bundleIdentifier ?: @"unknown",
          WACallerImage(),
          secClass.length ? secClass : @"nil",
          service.length ? service : @"nil",
          account.length ? account : @"nil",
          group.length ? group : @"nil",
          (int)status);
}

static NSString *WADetectAccessGroup(void) {
    if (gWAAccessGroup.length) return gWAAccessGroup;
    if (atomic_exchange(&gWAKeychainProbeActive, true)) return nil;

    NSString *service = WAProbeService();
    NSString *account = WAProbeAccount();
    NSData *data = [@"LiquidGlassOn" dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *deleteQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account
    };
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

extern "C" NSString *WAKeychainAccessGroupDiagnostic(void) {
    NSString *group = WADetectAccessGroup();
    return [NSString stringWithFormat:@"rewrite=%@\nobserver=%@\naccessGroup=%@\nbundle=%@",
            WAKeychainRewriteEnabled() ? @"ON" : @"OFF",
            WAKeychainObserverEnabled() ? @"ON" : @"OFF",
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
    return (CFDictionaryRef)CFBridgingRetain(q);
}

static OSStatus replaced_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    CFDictionaryRef q = WACopyQueryWithAccessGroup(attributes);
    CFDictionaryRef used = q ?: attributes;
    OSStatus s = orig_SecItemAdd(used, result);
    WALogKeychainMetadata(@"SecItemAdd", used, s);
    if (q) CFRelease(q);
    return s;
}

static OSStatus replaced_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    CFDictionaryRef q = WACopyQueryWithAccessGroup(query);
    CFDictionaryRef used = q ?: query;
    OSStatus s = orig_SecItemCopyMatching(used, result);
    WALogKeychainMetadata(@"SecItemCopyMatching", used, s);
    if (q) CFRelease(q);
    return s;
}

static OSStatus replaced_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    CFDictionaryRef q = WACopyQueryWithAccessGroup(query);
    CFDictionaryRef used = q ?: query;
    OSStatus s = orig_SecItemUpdate(used, attributesToUpdate);
    WALogKeychainMetadata(@"SecItemUpdate", used, s);
    if (q) CFRelease(q);
    return s;
}

static OSStatus replaced_SecItemDelete(CFDictionaryRef query) {
    OSStatus s = orig_SecItemDelete(query);
    WALogKeychainMetadata(@"SecItemDelete", query, s);
    return s;
}

extern "C" void WAInstallKeychainPatchIfNeeded(void) {
    if (!WAKeychainRewriteEnabled() && !WAKeychainObserverEnabled()) {
        WALog(@"keychain hooks disabled; inert");
        return;
    }
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gWAKeychainHooksInstalled, &expected, true)) return;

    WADetectAccessGroup();
    struct rebinding binds[] = {
        {"SecItemAdd", (void *)replaced_SecItemAdd, (void **)&orig_SecItemAdd},
        {"SecItemCopyMatching", (void *)replaced_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching},
        {"SecItemUpdate", (void *)replaced_SecItemUpdate, (void **)&orig_SecItemUpdate},
        {"SecItemDelete", (void *)replaced_SecItemDelete, (void **)&orig_SecItemDelete}
    };
    rebind_symbols(binds, sizeof(binds) / sizeof(binds[0]));
    WALog(@"installed keychain hooks; rewrite=%@ observer=%@ group=%@",
          WAKeychainRewriteEnabled() ? @"ON" : @"OFF",
          WAKeychainObserverEnabled() ? @"ON" : @"OFF",
          gWAAccessGroup ?: @"nil");
}
