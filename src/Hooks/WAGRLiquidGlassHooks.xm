#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static void WAGRLGApplyNative(void){
    NSUserDefaults*ud=NSUserDefaults.standardUserDefaults;
    BOOL on=WAGRPref(kWAGRLiquidGlassMaster);
    NSArray*keys=@[@"liquid_glass_override_enabled",@"WALiquidGlassOverrideEnabled",
        @"ios_liquid_glass_enabled",@"ios_liquid_glass_launched",@"ios_liquid_glass_m1",
        @"ios_liquid_glass_m_1_5",@"ios_liquid_glass_m_1_5_context_menu",@"ios_liquid_glass_media_m0",
        @"ios_liquid_glass_larger_composer",@"ios_liquid_glass_media_editor_enabled",
        @"ios_liquid_glass_calling_improvement_enabled",@"ios_liquid_glass_workaround_attachment_tray",
        @"status_viewer_redesign_enabled"];
    for(NSString*k in keys){if(on)[ud setBool:YES forKey:k];else[ud removeObjectForKey:k];}
    [ud synchronize];
    Class cls=NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults");
    if(!cls)return;
    SEL sh=NSSelectorFromString(@"sharedInstance");
    if(!class_respondsToSelector(object_getClass(cls),sh))return;
    id inst=((id(*)(id,SEL))objc_msgSend)((id)cls,sh);
    if(!inst)return;
    SEL se=NSSelectorFromString(@"setEnabled:");
    if(![inst respondsToSelector:se])return;
    NSMethodSignature*sig=[inst methodSignatureForSelector:se];
    if(!sig)return;
    NSInvocation*inv=[NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:se];[inv setTarget:inst];BOOL y=on;[inv setArgument:&y atIndex:2];[inv invoke];
}

// MSHookMessageEx for WDSLiquidGlass — no Logos
typedef BOOL (*ClassBoolIMP)(id,SEL);
static ClassBoolIMP orig_hasLaunched=NULL,orig_isM0=NULL,orig_isM1=NULL,
    orig_isM1_5=NULL,orig_isM1_5CM=NULL,orig_isLarger=NULL;

static BOOL h_lg(ClassBoolIMP orig,id s,SEL c){if(WAGRPref(kWAGRLiquidGlassMaster))return YES;return orig?orig(s,c):NO;}
static BOOL hLaunched(id s,SEL c){return h_lg(orig_hasLaunched,s,c);}
static BOOL hM0(id s,SEL c){return h_lg(orig_isM0,s,c);}
static BOOL hM1(id s,SEL c){return h_lg(orig_isM1,s,c);}
static BOOL hM1_5(id s,SEL c){return h_lg(orig_isM1_5,s,c);}
static BOOL hM1_5CM(id s,SEL c){return h_lg(orig_isM1_5CM,s,c);}
static BOOL hLarger(id s,SEL c){return h_lg(orig_isLarger,s,c);}

static void WAGRLGHookClass(void){
    Class cls=NSClassFromString(@"WDSLiquidGlass");if(!cls)return;
    Class meta=object_getClass(cls);
    struct{const char*sel;IMP h;IMP*o;}e[]={
        {"hasLiquidGlassLaunched",(IMP)hLaunched,(IMP*)&orig_hasLaunched},
        {"isM0Enabled",(IMP)hM0,(IMP*)&orig_isM0},
        {"isM1Enabled",(IMP)hM1,(IMP*)&orig_isM1},
        {"isM1_5Enabled",(IMP)hM1_5,(IMP*)&orig_isM1_5},
        {"isM1_5ContextMenuEnabled",(IMP)hM1_5CM,(IMP*)&orig_isM1_5CM},
        {"isLargerComposerEnabled",(IMP)hLarger,(IMP*)&orig_isLarger},
    };
    for(size_t i=0;i<sizeof(e)/sizeof(e[0]);i++){
        if(*e[i].o)continue;
        SEL sel=sel_registerName(e[i].sel);
        Method m=class_getClassMethod(cls,sel);if(!m)continue;
        MSHookMessageEx(meta,sel,e[i].h,e[i].o);
    }
}

__attribute__((constructor)) static void WAGRLGCtor(void){@autoreleasepool{
    WAGRLGApplyNative();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{WAGRLGHookClass();});
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{WAGRLGHookClass();});
}}
extern "C" void WAGRLGPrefsDidChange(void){WAGRLGApplyNative();}
extern "C" NSString *WAGRLGDiagnosticText(void){
    return [NSString stringWithFormat:@"master=%@\nWDS=%@\nWAAB=%@",
        WAGRPref(kWAGRLiquidGlassMaster)?@"ON":@"OFF",
        NSClassFromString(@"WDSLiquidGlass")?@"found":@"missing",
        NSClassFromString(@"WAABProperties")?@"found":@"missing"];
}
