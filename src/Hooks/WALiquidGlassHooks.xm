// WALiquidGlassHooks.xm
// Mirrors WALiquidGlass(working).dylib logic, with one master pref gate.

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../WAGramPrefix.h"

static BOOL WAGRLGEnabled(void) {
    return WAGRPref(kWAGRLiquidGlassMaster);
}

static BOOL WAGRLGShouldForce(void) {
    return WAGRLGEnabled();
}

static NSArray<NSString *> *WAGRLGDefaultBoolKeys(void) {
    return @[
        @"liquid_glass_override_enabled",
        @"WALiquidGlassOverrideEnabled",
        @"ios_liquid_glass_enabled",
        @"ios_liquid_glass_launched",
        @"ios_liquid_glass_m1",
        @"ios_liquid_glass_m_1_5",
        @"ios_liquid_glass_m_1_5_context_menu",
        @"ios_liquid_glass_media_m0",
        @"ios_liquid_glass_larger_composer",
        @"ios_liquid_glass_media_editor_enabled",
        @"ios_liquid_glass_calling_improvement_enabled",
        @"ios_liquid_glass_workaround_attachment_tray",
        @"status_viewer_redesign_enabled"
    ];
}

static void WAGRLGCallOverrideSetEnabled(BOOL enabled) {
    Class cls = NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults");
    if (!cls) return;

    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if (!class_respondsToSelector(object_getClass(cls), sharedSel)) return;

    id inst = ((id (*)(id, SEL))objc_msgSend)((id)cls, sharedSel);
    if (!inst) return;

    SEL setSel = NSSelectorFromString(@"setEnabled:");
    if (![inst respondsToSelector:setSel]) return;

    NSMethodSignature *sig = [inst methodSignatureForSelector:setSel];
    if (!sig) return;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:setSel];
    [inv setTarget:inst];
    BOOL yes = enabled;
    [inv setArgument:&yes atIndex:2];
    [inv invoke];
}

static void WAGRLGApplyNativeDefaults(void) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    BOOL enabled = WAGRLGEnabled();
    for (NSString *key in WAGRLGDefaultBoolKeys()) {
        if (enabled) [ud setBool:YES forKey:key];
        else [ud removeObjectForKey:key];
    }
    [ud synchronize];
    WAGRLGCallOverrideSetEnabled(enabled);
}

%hook WDSLiquidGlass
+ (BOOL)hasLiquidGlassLaunched { if (WAGRLGShouldForce()) return YES; return %orig; }
+ (BOOL)isM0Enabled { if (WAGRLGShouldForce()) return YES; return %orig; }
+ (BOOL)isM1Enabled { if (WAGRLGShouldForce()) return YES; return %orig; }
+ (BOOL)isM1_5Enabled { if (WAGRLGShouldForce()) return YES; return %orig; }
+ (BOOL)isM1_5ContextMenuEnabled { if (WAGRLGShouldForce()) return YES; return %orig; }
+ (BOOL)isLargerComposerEnabled { if (WAGRLGShouldForce()) return YES; return %orig; }
+ (BOOL)isNativeSidebarEnabled { if (WAGRLGShouldForce()) return YES; return %orig; }
+ (BOOL)shouldUseNativeSwipeActions { if (WAGRLGShouldForce()) return YES; return %orig; }
%end

%hook WAABProperties
- (BOOL)ios_liquid_glass_enabled { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_launched { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_m1 { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_m_1_5 { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_m_1_5_context_menu { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_media_m0 { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_larger_composer { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_media_editor_enabled { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_calling_improvement_enabled { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_workaround_attachment_tray { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_reduce_transparency { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)ios_liquid_glass_fixes_for_older_ios { if (WAGRLGShouldForce()) return YES; return %orig; }
- (BOOL)status_viewer_redesign_enabled { if (WAGRLGShouldForce()) return YES; return %orig; }
%end

%hook WALiquidGlassOverrideMethodUserDefaults
- (BOOL)isEnabled { if (WAGRLGShouldForce()) return YES; return %orig; }
%end

%hook IGLiquidGlassExperimentHelper
+ (BOOL)isEnabled { if (WAGRLGShouldForce()) return YES; return %orig; }
%end

%ctor {
    @autoreleasepool {
        WAGRLGApplyNativeDefaults();
        %init(WDSLiquidGlass=objc_getClass("WDSLiquidGlass"),
              WAABProperties=objc_getClass("WAABProperties"),
              WALiquidGlassOverrideMethodUserDefaults=objc_getClass("WALiquidGlassOverrideMethodUserDefaults"),
              IGLiquidGlassExperimentHelper=objc_getClass("IGLiquidGlassExperimentHelper"));
    }
}

extern "C" void WAGRLGPrefsDidChange(void) {
    WAGRLGApplyNativeDefaults();
}

extern "C" NSString *WAGRLGDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"master=%@\nWDSLiquidGlass=%@\nWAABProperties=%@\nOverrideClass=%@\nIGHelper=%@\nimplementation=Logos mirror",
        WAGRLGEnabled() ? @"ON" : @"OFF",
        NSClassFromString(@"WDSLiquidGlass") ? @"found" : @"missing",
        NSClassFromString(@"WAABProperties") ? @"found" : @"missing",
        NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults") ? @"found" : @"missing",
        NSClassFromString(@"IGLiquidGlassExperimentHelper") ? @"found" : @"missing"];
}
