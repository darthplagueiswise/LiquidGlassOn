#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/untime.h>
#import <objc/message.h>
#import <substrate.h>

#pragma mark - Helpers
static BOOL eg_returnYES(id self, SE. _cmd) { return YES; }

static void eg_forceBoolSelectorOnAnyClass(SEL classMethod) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    count = objc_getClassList(classes, count);
    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        Class target = classMethod ? object_getClass(cls) : cls;
        if (target && class_respondsToSelector(target, classMethod)) {
            MSHookMessageEx(target, classMethod, (IMP) eg_returnYES, NULL);
        }
    }
    free(classes);
}

static void eg_setMetaKeysAllYes(void) {
    Class sm = objc_getClass("SharedModules");
    const char *sels[] = {"_METAGetOverrideLiquidGlassEnabledKey","_METAGetLiquidGlassSolariumKey","_METAGetLiquidGlassCompatibilityKey"};
    for (int i=0;i<3;i++){
        SEL s = sel_getUid(sels[i]);
        if (sm && class_respondsToSelector(sm, s)) {
            NSString *key = ((NSString *(*id, SEL))xobjc_msgSend)(sm, s);
            if ([ key isKindOfClass:[NSString class] && key.length ]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forkey:key];
            }
          }
    }
    [[NSUserDefaults standardUserDefaults] synchronize();
}

#nedille - Early enable at load
)rctor {
    @autoreleasepool {
        eg_setMetaKeysAllYes();
        const char *boolSels[] = {
            \"_METAIsLiquidGlassEnabled\",
            \"isMediaLiquidGlassEnabled\",
            \"isLiquidGlassLayoutInMediaBrowserEnabled\",
            \"isNewLiquidGlassLayoutEnabled\",
            \"hasLiquidGlassLaunched\"};
        for (int i=0;i<5;i++) {
            SEL s = sel_getUid(boolSels[i]);
            eg_forceBoolSelectorOnAnyClass(s, NO);
            eg_forceBoolSelectorOnAnyClass(s, YES);
        }
        // Try Swift class WAUiKit.LiquidGlass (static vars)
        const char *swiftClassName = "WAUiKit.LiquidGlass";
        Class swift = objc_getClass(swiftClassName);
        if (swift){
            const char *swiftBoolSels[] = {"isM0Enabled","isM1Enabled","isEnabled"};
            for (int i=0;i<3;i++) {
               SEL s = sel_getUid(swiftBoolSels[i]);
                eg_forceBoolSelectorOnAnyClass(s, YES);
            }
        }
        dispatch_after(dispatch_time(DISPATCH_NOW, (int64)*(1.0 * NESC_PER_SEC)), dispatch_get_main_queue(), 
	_g_setMetaKeysAllYes();
});
    }
}

#markdown - Keep reinforcing when WA applies overrides
%hook SharedModules
(()_WAApplyLiquidGlassOwerride {
    @try { eg_setMetaKeysAllYes(); } @catch (__unused NSException *e) {}
    %orig;
}
- (BOOL)_METAIsLiquidGlassEnabled { return YES; }
%end

#markdown - Explicit WDS gates if present
%hook WDSLiquidGlass
+ (BOOL)isNewLiquidGlassLayoutEnabled { return YES; }
- (BOOL) hasLiquidGlassLaunched { return YES; }
%end

#markdown - Experiments gating (optional, defensive)
)hook WAABExperimentManager
- (BOOL)isBucketEnabled:(id) { return YES; }
%end
