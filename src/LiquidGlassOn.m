// src/LiquidGlassOn.m
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL lg_isEnabled(id self, SEL _cmd) { return YES; }

static void (*orig_setWindowLevel)(UIWindow *self, SEL _cmd, CGFloat level);
static void lg_setWindowLevel(UIWindow *self, SEL _cmd, CGFloat level) {
    if (level > 0.0) level = 0.0;            // rebaixa overlays abusados
    if (orig_setWindowLevel) orig_setWindowLevel(self, _cmd, level);
}

__attribute__((constructor))
static void lg_boot(void) {
    // 1) Força caminho "UserDefaults" + booleans ON
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:@"UserDefaults" forKey:@"WALiquidGlassOverrideMethod"];
    [d setBool:YES forKey:@"WAOverrideLiquidGlassEnabled"];
    [d setBool:YES forKey:@"LiquidGlassEnabled"];
    [d synchronize];

    // 2) +[WDSLiquidGlass isEnabled] -> sempre YES
    Class LG = objc_getClass("WDSLiquidGlass");
    if (LG) {
        SEL sel = sel_registerName("isEnabled");
        Method m = class_getClassMethod(LG, sel);
        if (m) method_setImplementation(m, (IMP)lg_isEnabled);
    }

    // 3) -[UIWindow setWindowLevel:] -> clamp
    Class UIW = objc_getClass("UIWindow"); 
    if (UIW) {
        SEL sel = sel_registerName("setWindowLevel:");
        Method m = class_getInstanceMethod(UIW, sel);
        if (m) {
            IMP oldImp = method_getImplementation(m);
            orig_setWindowLevel = (void(*)(UIWindow*,SEL,CGFloat))oldImp;
            method_setImplementation(m, (IMP)lg_setWindowLevel);
        }
    }
}
