#import "WAUtils.h"
#import "WAPrefix.h"
#import <objc/runtime.h>

BOOL WAEnabled(NSString *key) {
    if (!key.length) return NO;
    return [NSUserDefaults.standardUserDefaults boolForKey:key];
}

void WASetEnabled(NSString *key, BOOL enabled) {
    if (!key.length) return;
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

void WARegisterDefaults(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        WA_PREF_KEYCHAIN_REWRITE: @NO,
        WA_PREF_KEYCHAIN_OBSERVER: @NO,
        WA_PREF_EMPLOYEE_MASTER: @NO,
        WA_PREF_AB_OBSERVER: @NO,
        WA_PREF_LIQUID_GLASS: @NO,
        WA_PREF_LIQUID_GLASS_USERDEFAULTS: @YES,
        WA_PREF_LIQUID_GLASS_METHOD_HOOKS: @YES,
        @"wa_lg_ios_liquid_glass_enabled": @NO,
        @"wa_lg_ios_liquid_glass_launched": @NO,
        @"wa_lg_ios_liquid_glass_m1": @NO,
        @"wa_lg_ios_liquid_glass_m_1_5": @NO,
        @"wa_lg_ios_liquid_glass_m_1_5_context_menu": @NO,
        @"wa_lg_ios_liquid_glass_chat_top_bar_m2_enabled": @NO,
        @"wa_lg_ios_liquid_glass_enable_new_chatbar_ux": @NO,
        @"wa_lg_ios_liquid_glass_larger_composer": @NO,
        @"wa_lg_ios_liquid_glass_reduce_transparency": @NO,
        @"wa_lg_ios_liquid_glass_workaround_attachment_tray": @NO,
        @"wa_lg_ios_liquid_glass_workaround_hides_bottombar": @NO,
        @"wa_lg_ios_liquid_glass_workaround_topbar_appearance": @NO
    }];
}

NSString *WAStringFromObject(id value) {
    if (!value) return @"nil";
    if ([value isKindOfClass:NSString.class]) return (NSString *)value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue] ?: @"";
    return [value description] ?: @"";
}

void WAPresentAlert(UIViewController *presenter, NSString *title, NSString *message) {
    if (!presenter) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title ?: @"LiquidGlassOn" message:message ?: @"" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

Class WAFindClassByNameFragment(NSString *fragment) {
    if (!fragment.length) return Nil;
    NSString *needle = fragment.lowercaseString;
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return Nil;
    Class *classes = (Class *)calloc((NSUInteger)count, sizeof(Class));
    if (!classes) return Nil;
    objc_getClassList(classes, count);
    Class found = Nil;
    for (int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (!name) continue;
        NSString *s = @(name).lowercaseString;
        if ([s containsString:needle]) { found = classes[i]; break; }
    }
    free(classes);
    return found;
}

NSArray<Class> *WAClassesMatchingFragments(NSArray<NSString *> *fragments, NSUInteger limit) {
    if (!fragments.count) return @[];
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return @[];
    Class *classes = (Class *)calloc((NSUInteger)count, sizeof(Class));
    if (!classes) return @[];
    objc_getClassList(classes, count);
    NSMutableArray<Class> *out = [NSMutableArray array];
    NSMutableArray<NSString *> *needles = [NSMutableArray array];
    for (NSString *f in fragments) if (f.length) [needles addObject:f.lowercaseString];
    for (int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (!name) continue;
        NSString *s = @(name).lowercaseString;
        for (NSString *needle in needles) {
            if ([s containsString:needle]) {
                [out addObject:classes[i]];
                break;
            }
        }
        if (limit > 0 && out.count >= limit) break;
    }
    free(classes);
    return out;
}

BOOL WAInstanceRespondsTo(Class cls, SEL sel) {
    return cls && sel && class_getInstanceMethod(cls, sel) != NULL;
}

BOOL WAClassRespondsTo(Class cls, SEL sel) {
    return cls && sel && class_getClassMethod(cls, sel) != NULL;
}
