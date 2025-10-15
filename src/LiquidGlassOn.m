#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

// Replacement implementation for -[WDSLiquidGlass isEnabled]
static BOOL LG_isEnabled(id self, SEL _cmd) {
    // Always report that Liquid Glass is enabled
    return YES;
}

// Replacement implementation for -[UIWindow setWindowLevel:]
static void LG_setWindowLevel(UIWindow *self, SEL _cmd, CGFloat level) {
    // Clamp any window level above normal back to normal so overlays can't hide Liquid Glass
    if (level > 0.0) {
        level = 0.0;
    }
    // Call original implementation
    void (*orig)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))objc_getAssociatedObject(self, _cmd);
    if (orig) {
        orig(self, _cmd, level);
    }
}

// Constructor runs when the dylib is loaded
__attribute__((constructor))
static void LG_initialize(void) {
    // Persistently set the preferences to enable Liquid Glass
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"UserDefaults" forKey:@"WALiquidGlassOverrideMethod"];
    [defaults setBool:YES forKey:@"WAOverrideLiquidGlassEnabled"];
    [defaults setBool:YES forKey:@"LiquidGlassEnabled"];
    [defaults synchronize];

    // Swizzle +[WDSLiquidGlass isEnabled] to always return YES
    Class lgClass = NSClassFromString(@"WDSLiquidGlass");
    SEL enabledSel = @selector(isEnabled);
    Method enabledMethod = class_getClassMethod(lgClass, enabledSel);
    if (enabledMethod) {
        IMP originalIMP = method_getImplementation(enabledMethod);
        // Associate original IMP to retrieve in replacement if needed
        objc_setAssociatedObject(lgClass, enabledSel, (id)originalIMP, OBJC_ASSOCIATION_ASSIGN);
        method_setImplementation(enabledMethod, (IMP)LG_isEnabled);
    }

    // Swizzle -[UIWindow setWindowLevel:] to clamp overlay levels
    Class windowClass = [UIWindow class];
    SEL setLevelSel = @selector(setWindowLevel:);
    Method setLevelMethod = class_getInstanceMethod(windowClass, setLevelSel);
    if (setLevelMethod) {
        IMP originalSetLevel = method_getImplementation(setLevelMethod);
        // Store original implementation so our replacement can call through
        objc_setAssociatedObject(windowClass, setLevelSel, (id)originalSetLevel, OBJC_ASSOCIATION_ASSIGN);
        method_setImplementation(setLevelMethod, (IMP)LG_setWindowLevel);
    }
}