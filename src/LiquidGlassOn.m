// src/LiquidGlassOn.m
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL LG_isEnabled(id self, SEL _cmd) {
    return YES;
}

static void (*LG_origSetWindowLevel)(UIWindow *self, SEL _cmd, CGFloat level);
static void LG_setWindowLevel(UIWindow *self, SEL _cmd, CGFloat level) {
    if (level > 0.0) level = 0.0;                    // evita overlays acima do normal
    if (LG_origSetWindowLevel) LG_origSetWindowLevel(self, _cmd, level);
}

__attribute__((constructor))
static void LG_boot(void) {
    // 1) Força método "UserDefaults" e liga os booleans
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:@"UserDefaults" forKey:@"WALiquidGlassOverrideMethod"];
    [d setBool:YES forKey:@"WAOverrideLiquidGlassEnabled"];
    [d setBool:YES forKey:@"LiquidGlassEnabled"];
    [d synchronize];

    // 2) +[WDSLiquidGlass isEnabled] -> sempre YES
    Class LGClass = objc_getClass("WDSLiquidGlass");
    if (LGClass) {
        SEL sel = sel_registerName("isEnabled");
        Method m = class_getClassMethod(LGClass, sel);
        if (m) method_setImplementation(m, (IMP)LG_isEnabled);
    }

    // 3) -[UIWindow setWindowLevel:] -> clamp de overlays
    Class UIW = objc_getClass("UIWindow");
    if (UIW) {
        SEL sel = sel_registerName("setWindowLevel:");
        Method m = class_getInstanceMethod(UIW, sel);
        if (m) {
            IMP oldImp = method_getImplementation(m);
            LG_origSetWindowLevel = (void(*)(UIWindow*,SEL,CGFloat))oldImp;
            method_setImplementation(m, (IMP)LG_setWindowLevel);
        }
    }
}
