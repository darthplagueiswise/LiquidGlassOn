// src/LiquidGlassOn.m
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Helpers

static Class LGClass(void) {
    return objc_getClass("WDSLiquidGlass");
}

static void LG_trySetBool(NSUserDefaults *d, NSString *k, BOOL v) {
    @try { [d setBool:v forKey:k]; } @catch (__unused id e) {}
}

static void LG_forcePrefs(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    // Força caminho UserDefaults + chaves “clássicas”
    @try { [d setObject:@"UserDefaults" forKey:@"WALiquidGlassOverrideMethod"]; } @catch (__unused id e) {}
    LG_trySetBool(d, @"WAOverrideLiquidGlassEnabled", YES);
    LG_trySetBool(d, @"LiquidGlassEnabled", YES);
    // Liga também flags vistas no SharedModules (defensivo)
    LG_trySetBool(d, @"ios_liquid_glass_enabled", YES);
    LG_trySetBool(d, @"ios_liquid_glass_m1", YES);
    LG_trySetBool(d, @"ios_liquid_glass_m_1_5", YES);
    [d synchronize];
}

#pragma mark - Swizzles

static BOOL LG_isEnabled(id self, SEL _cmd) { return YES; }
static BOOL LG_isFeatureEnabled(id self, SEL _cmd) { return YES; }
static BOOL LG_hasLiquidGlassLaunched(id self, SEL _cmd) { return YES; }

static void LG_swizzleFeatureChecks(void) {
    Class C = LGClass();
    if (!C) return;

    SEL sel;
    Method m;

    sel = sel_registerName("isEnabled");
    if ((m = class_getClassMethod(C, sel))) {
        method_setImplementation(m, (IMP)LG_isEnabled);
    }

    sel = sel_registerName("isFeatureEnabled");
    if ((m = class_getClassMethod(C, sel))) {
        method_setImplementation(m, (IMP)LG_isFeatureEnabled);
    }

    sel = sel_registerName("hasLiquidGlassLaunched");
    if ((m = class_getClassMethod(C, sel))) {
        method_setImplementation(m, (IMP)LG_hasLiquidGlassLaunched);
    }
}

// Clamp overlays abusados
static void (*LG_origSetWindowLevel)(UIWindow *self, SEL _cmd, CGFloat level);
static void LG_setWindowLevel(UIWindow *self, SEL _cmd, CGFloat level) {
    if (level > 0.0) level = 0.0;
    if (LG_origSetWindowLevel) LG_origSetWindowLevel(self, _cmd, level);
}

static void LG_swizzleWindowLevel(void) {
    Class UIW = objc_getClass("UIWindow");
    if (!UIW) return;
    SEL sel = sel_registerName("setWindowLevel:");
    Method m = class_getInstanceMethod(UIW, sel);
    if (!m) return;
    IMP oldImp = method_getImplementation(m);
    LG_origSetWindowLevel = (void(*)(UIWindow*,SEL,CGFloat))oldImp;
    method_setImplementation(m, (IMP)LG_setWindowLevel);
}

#pragma mark - Boot

__attribute__((constructor))
static void LG_boot(void) {
    // 1) Pré-condições (preferências)
    LG_forcePrefs();

    // 2) Swizzles imediatos
    LG_swizzleFeatureChecks();
    LG_swizzleWindowLevel();

    // 3) Re-aplicar depois do app subir (evita que outros tweaks “passem por cima”)
    dispatch_async(dispatch_get_main_queue(), ^{
        LG_swizzleFeatureChecks();
        LG_swizzleWindowLevel();
        // Reforça após 1s também (HUDs tardios)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            LG_swizzleFeatureChecks();
            LG_swizzleWindowLevel();
        });
    });

    // 4) Re-aplicar ao voltar ao foreground
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(__unused NSNotification *n){
        LG_forcePrefs();
        LG_swizzleFeatureChecks();
        LG_swizzleWindowLevel();
    }];
}
