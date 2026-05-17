// WALiquidGlassHooks.xm
// LiquidGlass override layer with default-aware UI semantics.
// Effective ON can come from the app/system itself; hooks only force when the user explicitly overrides ON.

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../WAGramPrefix.h"

extern "C" BOOL WAGRWAABOriginalBoolForFlag(NSString *flag, BOOL *knownOut);

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

static NSArray<NSString *> *WAGRLGWAABFlagKeys(void) {
    return @[
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

static BOOL WAGRLGMasterOverride(BOOL *valueOut) {
    return WAGRBoolOverrideForKey(kWAGRLiquidGlassMaster, valueOut);
}

static BOOL WAGRLGExplicitForceEnabled(void) {
    BOOL value = NO;
    return WAGRLGMasterOverride(&value) && value;
}

static BOOL WAGRLGCallClassBool(Class cls, NSString *selName, BOOL *knownOut) {
    if (knownOut) *knownOut = NO;
    if (!cls || !selName.length) return NO;
    SEL sel = NSSelectorFromString(selName);
    if (!class_respondsToSelector(object_getClass(cls), sel)) return NO;
    @try {
        BOOL value = ((BOOL (*)(id, SEL))objc_msgSend)((id)cls, sel);
        if (knownOut) *knownOut = YES;
        return value;
    } @catch (__unused id ex) {
        return NO;
    }
}

extern "C" BOOL WAGRLGSystemDefaultEnabled(void) {
    BOOL knownAny = NO;
    for (NSString *flag in WAGRLGWAABFlagKeys()) {
        BOOL known = NO;
        BOOL value = WAGRWAABOriginalBoolForFlag(flag, &known);
        if (known) {
            knownAny = YES;
            if (value) return YES;
        }
    }

    Class wdslg = NSClassFromString(@"WDSLiquidGlass");
    NSArray<NSString *> *wdslgSelectors = @[
        @"hasLiquidGlassLaunched", @"isM0Enabled", @"isM1Enabled", @"isM1_5Enabled",
        @"isM1_5ContextMenuEnabled", @"isLargerComposerEnabled", @"isNativeSidebarEnabled",
        @"shouldUseNativeSwipeActions"
    ];
    for (NSString *sel in wdslgSelectors) {
        BOOL known = NO;
        BOOL value = WAGRLGCallClassBool(wdslg, sel, &known);
        if (known) {
            knownAny = YES;
            if (value) return YES;
        }
    }

    Class ig = NSClassFromString(@"IGLiquidGlassExperimentHelper");
    BOOL known = NO;
    BOOL value = WAGRLGCallClassBool(ig, @"isEnabled", &known);
    if (known) {
        knownAny = YES;
        if (value) return YES;
    }

    return knownAny ? NO : NO;
}

extern "C" BOOL WAGRLGEffectiveEnabled(void) {
    BOOL value = NO;
    if (WAGRLGMasterOverride(&value)) return value;
    return WAGRLGSystemDefaultEnabled();
}

static BOOL WAGRLGShouldForce(void) {
    return WAGRLGExplicitForceEnabled();
}

static void WAGRLGCallOverrideSetEnabled(BOOL enabled) {
    Class cls = NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults");
    if (!cls) return;

    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if (!class_respondsToSelector(object_getClass(cls), sharedSel)) return;

    id inst = nil;
    @try { inst = ((id (*)(id, SEL))objc_msgSend)((id)cls, sharedSel); } @catch (__unused id ex) { inst = nil; }
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
    @try { [inv invoke]; } @catch (__unused id ex) {}
}

static void WAGRLGApplyNativeDefaults(void) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    BOOL explicitValue = NO;
    BOOL hasExplicit = WAGRLGMasterOverride(&explicitValue);

    if (hasExplicit && explicitValue) {
        for (NSString *key in WAGRLGDefaultBoolKeys()) [ud setBool:YES forKey:key];
        [ud synchronize];
        WAGRLGCallOverrideSetEnabled(YES);
        return;
    }

    // No forced override, or explicit OFF: remove legacy direct keys written by older builds.
    for (NSString *key in WAGRLGDefaultBoolKeys()) [ud removeObjectForKey:key];
    [ud synchronize];
    if (hasExplicit) WAGRLGCallOverrideSetEnabled(NO);
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
        BOOL explicitValue = NO;
        if (WAGRLGMasterOverride(&explicitValue)) WAGRLGApplyNativeDefaults();
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
    BOOL explicitValue = NO;
    BOOL hasExplicit = WAGRLGMasterOverride(&explicitValue);
    BOOL systemValue = WAGRLGSystemDefaultEnabled();
    BOOL effectiveValue = WAGRLGEffectiveEnabled();
    return [NSString stringWithFormat:
        @"effective=%@\nsystem default=%@\nexplicit override=%@%@\nforce hooks=%@\nWDSLiquidGlass=%@\nWAABProperties=%@\nOverrideClass=%@\nIGHelper=%@\nimplementation=default-aware Logos mirror",
        effectiveValue ? @"ON" : @"OFF",
        systemValue ? @"ON" : @"OFF",
        hasExplicit ? @"YES " : @"NO",
        hasExplicit ? (explicitValue ? @"(ON)" : @"(OFF)") : @"",
        WAGRLGShouldForce() ? @"ON" : @"OFF",
        NSClassFromString(@"WDSLiquidGlass") ? @"found" : @"missing",
        NSClassFromString(@"WAABProperties") ? @"found" : @"missing",
        NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults") ? @"found" : @"missing",
        NSClassFromString(@"IGLiquidGlassExperimentHelper") ? @"found" : @"missing"];
}
