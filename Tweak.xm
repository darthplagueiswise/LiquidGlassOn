#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

static void setYES(NSString *k){ if(!k) return; [[NSUserDefaults standardUserDefaults] setBool:YES forKey:k]; [[NSUserDefaults standardUserDefaults] synchronize]; }

%ctor {
    Class Shared = objc_getClass("SharedModules");
    if (Shared && class_respondsToSelector(object_getClass(Shared), @selector(_METAGetOverrideLiquidGlassEnabledKey))) {
        NSString *k = ((NSString*(*)(id,SEL))objc_msgSend)(Shared, @selector(_METAGetOverrideLiquidGlassEnabledKey)); setYES(k);
    }
    if (Shared && class_respondsToSelector(object_getClass(Shared), @selector(_METAGetLiquidGlassSolariumKey))) {
        NSString *k = ((NSString*(*)(id,SEL))objc_msgSend)(Shared, @selector(_METAGetLiquidGlassSolariumKey)); setYES(k);
    }
    if (Shared && class_respondsToSelector(object_getClass(Shared), @selector(_METAGetLiquidGlassCompatibilityKey))) {
        NSString *k = ((NSString*(*)(id,SEL))objc_msgSend)(Shared, @selector(_METAGetLiquidGlassCompatibilityKey)); setYES(k);
    }

    const SEL boolSels[] = {
        @selector(_METAIsLiquidGlassEnabled),
        @selector(isMediaLiquidGlassEnabled),
        @selector(isLiquidGlassLayoutInMediaBrowserEnabled),
        @selector(isNewLiquidGlassLayoutEnabled),
        @selector(hasLiquidGlassLaunched)
    };
    BOOL(^retYES)(id,SEL) = ^BOOL(id self, SEL _cmd){ return YES; };

    int n = objc_getClassList(NULL,0);
    Class *cls = (Class*)malloc(sizeof(Class)*n);
    objc_getClassList(cls,n);
    for (int i=0;i<n;i++){
        Class C = cls[i], M = object_getClass((id)C);
        for (unsigned j=0;j<sizeof(boolSels)/sizeof(boolSels[0]);j++){
            SEL s = boolSels[j];
            if (class_respondsToSelector(C,s))  MSHookMessageEx(C,s,(IMP)imp_implementationWithBlock(retYES),NULL);
            if (class_respondsToSelector(M,s))  MSHookMessageEx(M,s,(IMP)imp_implementationWithBlock(retYES),NULL);
        }
    }
    free(cls);

    Class LG = objc_getClass("LiquidGlass"); if(!LG) LG = objc_getClass("WAUIKit.LiquidGlass");
    if (LG){
        SEL sw[] = { sel_registerName("isM0Enabled"), sel_registerName("isM1Enabled"), sel_registerName("isEnabled") };
        for (int i=0;i<3;i++) if (class_respondsToSelector(object_getClass(LG), sw[i]))
            MSHookMessageEx(object_getClass(LG), sw[i], (IMP)imp_implementationWithBlock(^BOOL(id,SEL){ return YES; }), NULL);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class S = objc_getClass("SharedModules"); if(!S) return;
        SEL sels[] = { @selector(_METAGetOverrideLiquidGlassEnabledKey), @selector(_METAGetLiquidGlassSolariumKey), @selector(_METAGetLiquidGlassCompatibilityKey) };
        for (int i=0;i<3;i++) if (class_respondsToSelector(object_getClass(S), sels[i])) {
            NSString *k = ((NSString*(*)(id,SEL))objc_msgSend)(S, sels[i]); setYES(k);
        }
    });
}

%hook WDSLiquidGlass
+ (BOOL)isNewLiquidGlassLayoutEnabled { return YES; }
- (BOOL)hasLiquidGlassLaunched { return YES; }
%end

%hook SharedModules
- (void)_WAApplyLiquidGlassOverride {
    Class S = objc_getClass("SharedModules");
    if (S && class_respondsToSelector(object_getClass(S), @selector(_METAGetOverrideLiquidGlassEnabledKey))) {
        NSString *k = ((NSString*(*)(id,SEL))objc_msgSend)(S, @selector(_METAGetOverrideLiquidGlassEnabledKey)); setYES(k);
    }
    %orig;
}
%end

%hook WAABExperimentManager
- (BOOL)isBucketEnabled:(id)bucket { return YES; }
%end
