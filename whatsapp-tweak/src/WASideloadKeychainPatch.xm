#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

static BOOL wa_sideload_keychain_rewrite_enabled = NO;
static NSString * const kWAKeychainRewriteKey = @"wa_sideload_keychain_rewrite_enabled";

// Diagnostic function - call this from menu or notification
void WAShowKeychainDiagnostic() {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Keychain Diagnostic"
                                                                   message:@"AccessGroup detectado: (ver logs)\n\nHooks ativos: SecItemAdd, SecItemCopyMatching, SecItemUpdate\n\nNÃO reescreve SecItemDelete"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

%ctor {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
    wa_sideload_keychain_rewrite_enabled = [prefs[kWAKeychainRewriteKey] boolValue] ?: NO;
    
    // Listen for preference changes
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)^(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
        NSDictionary *newPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
        wa_sideload_keychain_rewrite_enabled = [newPrefs[kWAKeychainRewriteKey] boolValue] ?: NO;
    }, CFSTR("com.darthplagueiswise.waliquidglassryuk/prefsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

%hookf(OSStatus, SecItemAdd, CFDictionaryRef attributes, CFTypeRef *result) {
    if (!wa_sideload_keychain_rewrite_enabled) {
        return %orig;
    }
    
    // Log metadata only (no sensitive data)
    NSString *accessGroup = (__bridge NSString *)CFDictionaryGetValue(attributes, kSecAttrAccessGroup);
    NSString *service = (__bridge NSString *)CFDictionaryGetValue(attributes, kSecAttrService);
    NSString *account = (__bridge NSString *)CFDictionaryGetValue(attributes, kSecAttrAccount);
    NSString *klass = (__bridge NSString *)CFDictionaryGetValue(attributes, kSecClass);
    
    NSLog(@"[WASideloadKeychain] SecItemAdd called | bundle=%@ | accessGroup=%@ | service=%@ | account=%@ | class=%@ | status=HOOKED",
          [[NSBundle mainBundle] bundleIdentifier], accessGroup ?: @"nil", service ?: @"nil", account ?: @"nil", klass ?: @"nil");
    
    // Rewrite accessGroup to app's own if needed (sideload safe)
    if (accessGroup && ![accessGroup hasPrefix:@"com.whatsapp."]) {
        NSMutableDictionary *newAttrs = [(__bridge NSDictionary *)attributes mutableCopy];
        [newAttrs setObject:@"com.whatsapp.WhatsApp" forKey:(__bridge id)kSecAttrAccessGroup];
        return %orig((__bridge CFDictionaryRef)newAttrs, result);
    }
    
    return %orig;
}

%hookf(OSStatus, SecItemCopyMatching, CFDictionaryRef query, CFTypeRef *result) {
    if (!wa_sideload_keychain_rewrite_enabled) {
        return %orig;
    }
    
    NSString *accessGroup = (__bridge NSString *)CFDictionaryGetValue(query, kSecAttrAccessGroup);
    NSLog(@"[WASideloadKeychain] SecItemCopyMatching | accessGroup=%@ | caller=%@", accessGroup ?: @"nil", [[NSBundle mainBundle] bundleIdentifier]);
    
    return %orig;
}

%hookf(OSStatus, SecItemUpdate, CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    if (!wa_sideload_keychain_rewrite_enabled) {
        return %orig;
    }
    
    NSString *accessGroup = (__bridge NSString *)CFDictionaryGetValue(query, kSecAttrAccessGroup);
    NSLog(@"[WASideloadKeychain] SecItemUpdate | accessGroup=%@ | NO SecItemDelete rewrite", accessGroup ?: @"nil");
    
    return %orig;
}

// Note: SecItemDelete is intentionally NOT hooked as per request