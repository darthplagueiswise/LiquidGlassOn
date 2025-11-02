#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

static void ForceMetaFlag(NSString *key){ if(!key) return; [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key]; }
static void ForceAllMetaKeys(void){
    NSArray *cand = @[ @"_METAGetOverrideLiquidGlassEnabledKey", @"_METAGetLiquidGlassSolariumKey", @"_METAGetLiquidGlassCompatibilityKey" ];
    Class C = objc_getClass(@"SharedModules");
    for (NSString *selName in cand){
        SEL s = NSSelectorFromString(selName);
        if (C && class_respondsToSelector(object_getClass(C), s)) {
            typedef NSString*(*F)(id,SEL); NSString *k = ((F)objc_msgSend)(C,s); ForceMetaFlag(k);
        }
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

%ctor {
    ForceAllMetaKeys();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ ForceAllMetaKeys(); });
}

static BOOL retYES(id self, SEL _cmd){ return YES; }
static BOOL C_retYES(Class self, SEL _cmd){ return YES; }
static void HookBoolIfExists(Class C, SEL sel, BOOL isClass){
    if(!C||!sel) return; Method m = isClass? class_getClassMethod(C, sel): class_getInstanceMethod(C, sel); if(!m) return;
    IMP impl = isClass? (IMP)C_retYES : (IMP)retYES; const char *types = method_getTypeEncoding(m); class_replaceMethod(isClass? object_getClass(C):C, sel, impl, types);
}
static void SweepAndHook(void){
    const char* sels[] = {"_METAIsLiquidGlassEnabled","isMediaLiquidGlassEnabled","isLiquidGlassLayoutInMediaBrowserEnabled","isNewLiquidGlassLayoutEnabled","hasLiquidGlassLaunched"};
    int count = objc_getClassList(NULL,0); if(count<=0) return; Class *classes = (Class*)malloc(sizeof(Class)*count); objc_getClassList(classes,count);
    for(int i=0;i<count;i++){ Class C = classes[i]; for(size_t j=0;j<sizeof(sels)/sizeof(sels[0]);j++){ SEL s = sel_getUid(sels[j]); HookBoolIfExists(C,s,NO); HookBoolIfExists(C,s,YES); } } free(classes);
}
%ctor{ SweepAndHook(); }

%hook WDSLiquidGlass
+ (BOOL)isNewLiquidGlassLayoutEnabled { return YES; }
- (BOOL)hasLiquidGlassLaunched { return YES; }
%end

%hook SharedModules
- (void)_WAApplyLiquidGlassOverride { ForceAllMetaKeys(); %orig; }
%end

%hook WAABExperimentManager
- (BOOL)isBucketEnabled:(id)bucket { return YES; }
%end
