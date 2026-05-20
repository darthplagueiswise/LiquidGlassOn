// WAGRContextHooks.xm — WAContextMain BOOL gates for dev menu + settings rows.
// MSHookMessageEx only. Startup-inert. 4-retry pattern.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

#define kWAGRCtxDebugMenu  @"wagr_native_debug_menu_enabled"
#define kWAGRCtxDebugBuild @"wagr.ctx.isDebugBuild"
#define kWAGRCtxDebugShort @"wagr.ctx.isDebugMenuShortcutEnabled"
#define kWAGRCtxBeta       @"wagr.ctx.isBetaOrMoreVerbose"
#define kWAGRCtxTestFlight @"wagr.ctx.isTestFlightApp"
#define kWAGRCtxLists      @"wagr.ctx.listsFeatureEnabled"
#define kWAGRCtxSmbLists   @"wagr.ctx.smbListsFeatureEnabled"
#define kWAGRCtxAvatar     @"wagr.ctx.avatarFeatureEnabled"
#define kWAGRCtxVerified   @"wagr.ctx.isVerifiedChannelFeatureFlagEnabled"

typedef BOOL (*BoolIMP)(id,SEL);
#define CTX_ORIG(name) static BoolIMP orig_##name = NULL;
CTX_ORIG(debugMenu) CTX_ORIG(debugBuild) CTX_ORIG(debugShort) CTX_ORIG(beta)
CTX_ORIG(testFlight) CTX_ORIG(lists) CTX_ORIG(smbLists) CTX_ORIG(avatar) CTX_ORIG(verified)

#define CTX_HOOK(name,pref,orig) \
static BOOL h_##name(id s,SEL c){if(WAGRPref(pref))return YES;return orig?orig(s,c):NO;}
CTX_HOOK(debugMenu,  kWAGRCtxDebugMenu,  orig_debugMenu)
CTX_HOOK(debugBuild, kWAGRCtxDebugBuild, orig_debugBuild)
CTX_HOOK(debugShort, kWAGRCtxDebugShort, orig_debugShort)
CTX_HOOK(beta,       kWAGRCtxBeta,       orig_beta)
CTX_HOOK(testFlight, kWAGRCtxTestFlight, orig_testFlight)
CTX_HOOK(lists,      kWAGRCtxLists,      orig_lists)
CTX_HOOK(smbLists,   kWAGRCtxSmbLists,   orig_smbLists)
CTX_HOOK(avatar,     kWAGRCtxAvatar,     orig_avatar)
CTX_HOOK(verified,   kWAGRCtxVerified,   orig_verified)

static BOOL gCtxDone=NO; static NSUInteger gCtxN=0;
static void hookSel(Class cls, const char*sel, IMP h, BoolIMP*o){
    if(!cls||!sel||!h||!o||*o)return;
    SEL s=sel_registerName(sel);
    for(int m=0;m<2;m++){
        Method mt=m?class_getClassMethod(cls,s):class_getInstanceMethod(cls,s);if(!mt)continue;
        char r[8]={0};method_getReturnType(mt,r,8);if(r[0]!='B'&&r[0]!='c')continue;
        MSHookMessageEx(m?object_getClass(cls):cls,s,h,(IMP*)o);if(*o){gCtxN++;return;}
    }
}
static void install(void){
    if(gCtxDone)return;
    struct{const char*cls;const char*sel;IMP h;BoolIMP*o;}e[]={
        {"WAContextMain","isDebugMenuAllowed",         (IMP)h_debugMenu,  &orig_debugMenu},
        {"WAContextMain","isDebugBuild",               (IMP)h_debugBuild, &orig_debugBuild},
        {"WAContextMain","isDebugMenuShortcutEnabled", (IMP)h_debugShort, &orig_debugShort},
        {"WAContextMain","isBetaOrMoreVerbose",        (IMP)h_beta,       &orig_beta},
        {"WAContextMain","isTestFlightApp",            (IMP)h_testFlight, &orig_testFlight},
        {"WAContextMain","listsFeatureEnabled",        (IMP)h_lists,      &orig_lists},
        {"WAContextMain","smbListsFeatureEnabled",     (IMP)h_smbLists,   &orig_smbLists},
        {"WAContextMain","avatarFeatureEnabled",       (IMP)h_avatar,     &orig_avatar},
        {"WAContextMain","isVerifiedChannelFeatureFlagEnabled",(IMP)h_verified,&orig_verified},
        {"WASettingsViewController","isDebugMenuAllowed",(IMP)h_debugMenu,&orig_debugMenu},
        {"WAFeatureControlGateKeeper","isVerifiedChannelFeatureFlagEnabled",(IMP)h_verified,&orig_verified},
    };
    for(size_t i=0;i<sizeof(e)/sizeof(e[0]);i++) hookSel(NSClassFromString(@(e[i].cls)),e[i].sel,e[i].h,e[i].o);
    // Broad scan fallback for isDebugMenuAllowed
    if(!orig_debugMenu){
        unsigned int t=0;Class*all=objc_copyClassList(&t);
        if(all){for(unsigned int i=0;i<t&&!orig_debugMenu;i++) hookSel(all[i],"isDebugMenuAllowed",(IMP)h_debugMenu,&orig_debugMenu);}
        if(all)free(all);
    }
    gCtxDone=(gCtxN>0);
    NSLog(@"[WAGram][Ctx] done=%@ n=%lu",gCtxDone?@"YES":@"NO",(unsigned long)gCtxN);
}
static BOOL anyEnabled(void){
    NSArray*k=@[kWAGRCtxDebugMenu,kWAGRCtxDebugBuild,kWAGRCtxDebugShort,kWAGRCtxBeta,
                kWAGRCtxTestFlight,kWAGRCtxLists,kWAGRCtxSmbLists,kWAGRCtxAvatar,kWAGRCtxVerified];
    for(NSString*s in k)if(WAGRPref(s))return YES;return NO;
}
__attribute__((constructor)) static void ctxCtor(void){@autoreleasepool{
    if(!anyEnabled()){NSLog(@"[WAGram][Ctx] inert");return;}
    double d[]={0.2,1.0,3.0,6.0};
    for(int i=0;i<4;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(d[i]*NSEC_PER_SEC)),dispatch_get_main_queue(),^{install();});
}}
extern "C" void WAGRContextHooksEnsureInstalled(void){install();}
extern "C" NSString *WAGRContextHooksDiagnostic(void){
    return [NSString stringWithFormat:@"done=%@ n=%lu debugMenu=%@ debugBuild=%@ lists=%@",
        gCtxDone?@"YES":@"NO",(unsigned long)gCtxN,
        orig_debugMenu?@"OK":@"MISS",orig_debugBuild?@"OK":@"MISS",orig_lists?@"OK":@"MISS"];}
