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
    // Intentionally no-op. registerDefaults pollutes Flex/NSUserDefaults with
    // synthetic 0/1 rows. Absent key means system/default throughout WAGram.
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
