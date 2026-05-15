// WALiquidGlassHooks.xm
// Liquid Glass enablement for WhatsApp.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static BOOL _wagrLGHooksInstalled = NO;

static BOOL WAGRLGEnabled(void) {
    return WAGRPref(kWAGRLiquidGlassMaster);
}

static NSArray<NSString *> *WAGRLGDefaultBoolKeys(void) {
    return @[
        @"liquid_glass_override_enabled",
        @"WALiquidGlassOverrideEnabled",
        @"WALiquidGlassOverrideMethodUserDefaults",
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
        @"ios_liquid_glass_reduce_transparency",
        @"ios_liquid_glass_fixes_for_older_ios",
        @"status_viewer_redesign_enabled"
    ];
}

static void WAGRLGSetOverrideObjectEnabled(BOOL enabled) {
    Class cls = NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults");
    if (!cls) return;

    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if (![cls respondsToSelector:sharedSel]) return;

    id inst = ((id (*)(id, SEL))objc_msgSend)((id)cls, sharedSel);
    if (!inst) return;

    SEL setSel = NSSelectorFromString(@"setEnabled:");
    if ([inst respondsToSelector:setSel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(inst, setSel, enabled);
        NSLog(@"[WAGram][LiquidGlass] called WALiquidGlassOverrideMethodUserDefaults setEnabled:%@", enabled ? @"YES" : @"NO");
    }
}

static void WAGRLGApplyUserDefaultsOverride(void) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    BOOL enabled = WAGRLGEnabled();

    for (NSString *key in WAGRLGDefaultBoolKeys()) {
        if (enabled) [ud setBool:YES forKey:key];
        else [ud removeObjectForKey:key];
    }

    [ud synchronize];
    WAGRLGSetOverrideObjectEnabled(enabled);
    NSLog(@"[WAGram][LiquidGlass] native defaults %@", enabled ? @"enabled" : @"removed");
}

#define WAGR_LG_TRUE_ORIG(origFn) do { if (WAGRLGEnabled()) return YES; return origFn ? origFn(self, _cmd) : NO; } while (0)

static BOOL (*orig_WDSLiquidGlass_hasLiquidGlassLaunched)(id, SEL) = NULL;
static BOOL (*orig_WDSLiquidGlass_isM0Enabled)(id, SEL) = NULL;
static BOOL (*orig_WDSLiquidGlass_isM1Enabled)(id, SEL) = NULL;
static BOOL (*orig_WDSLiquidGlass_isM1_5Enabled)(id, SEL) = NULL;
static BOOL (*orig_WDSLiquidGlass_isM1_5ContextMenuEnabled)(id, SEL) = NULL;
static BOOL (*orig_WDSLiquidGlass_isLargerComposerEnabled)(id, SEL) = NULL;
static BOOL (*orig_WDSLiquidGlass_isNativeSidebarEnabled)(id, SEL) = NULL;
static BOOL (*orig_WDSLiquidGlass_shouldUseNativeSwipeActions)(id, SEL) = NULL;

static BOOL hook_WDSLiquidGlass_hasLiquidGlassLaunched(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_hasLiquidGlassLaunched); }
static BOOL hook_WDSLiquidGlass_isM0Enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_isM0Enabled); }
static BOOL hook_WDSLiquidGlass_isM1Enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_isM1Enabled); }
static BOOL hook_WDSLiquidGlass_isM1_5Enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_isM1_5Enabled); }
static BOOL hook_WDSLiquidGlass_isM1_5ContextMenuEnabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_isM1_5ContextMenuEnabled); }
static BOOL hook_WDSLiquidGlass_isLargerComposerEnabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_isLargerComposerEnabled); }
static BOOL hook_WDSLiquidGlass_isNativeSidebarEnabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_isNativeSidebarEnabled); }
static BOOL hook_WDSLiquidGlass_shouldUseNativeSwipeActions(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WDSLiquidGlass_shouldUseNativeSwipeActions); }

static BOOL (*orig_WAAB_ios_liquid_glass_enabled)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_launched)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_m1)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_m_1_5)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_m_1_5_context_menu)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_media_m0)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_larger_composer)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_media_editor_enabled)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_calling_improvement_enabled)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_workaround_attachment_tray)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_reduce_transparency)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_fixes_for_older_ios)(id, SEL) = NULL;
static BOOL (*orig_WAAB_status_viewer_redesign_enabled)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_chat_top_bar_m2_enabled)(id, SEL) = NULL;
static BOOL (*orig_WAAB_ios_liquid_glass_enable_new_chatbar_ux)(id, SEL) = NULL;

static BOOL hook_WAAB_ios_liquid_glass_enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_enabled); }
static BOOL hook_WAAB_ios_liquid_glass_launched(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_launched); }
static BOOL hook_WAAB_ios_liquid_glass_m1(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_m1); }
static BOOL hook_WAAB_ios_liquid_glass_m_1_5(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_m_1_5); }
static BOOL hook_WAAB_ios_liquid_glass_m_1_5_context_menu(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_m_1_5_context_menu); }
static BOOL hook_WAAB_ios_liquid_glass_media_m0(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_media_m0); }
static BOOL hook_WAAB_ios_liquid_glass_larger_composer(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_larger_composer); }
static BOOL hook_WAAB_ios_liquid_glass_media_editor_enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_media_editor_enabled); }
static BOOL hook_WAAB_ios_liquid_glass_calling_improvement_enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_calling_improvement_enabled); }
static BOOL hook_WAAB_ios_liquid_glass_workaround_attachment_tray(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_workaround_attachment_tray); }
static BOOL hook_WAAB_ios_liquid_glass_reduce_transparency(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_reduce_transparency); }
static BOOL hook_WAAB_ios_liquid_glass_fixes_for_older_ios(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_fixes_for_older_ios); }
static BOOL hook_WAAB_status_viewer_redesign_enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_status_viewer_redesign_enabled); }
static BOOL hook_WAAB_ios_liquid_glass_chat_top_bar_m2_enabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_chat_top_bar_m2_enabled); }
static BOOL hook_WAAB_ios_liquid_glass_enable_new_chatbar_ux(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WAAB_ios_liquid_glass_enable_new_chatbar_ux); }

static BOOL (*orig_WALGOverride_isEnabled)(id, SEL) = NULL;
static BOOL hook_WALGOverride_isEnabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_WALGOverride_isEnabled); }

static BOOL (*orig_IGLGExperimentHelper_isEnabled)(id, SEL) = NULL;
static BOOL hook_IGLGExperimentHelper_isEnabled(id self, SEL _cmd) { WAGR_LG_TRUE_ORIG(orig_IGLGExperimentHelper_isEnabled); }

static void WAGRLGHookInstanceMethod(Class cls, SEL sel, IMP hook, IMP *orig) {
    if (!cls || !sel || !hook || !orig || *orig) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    MSHookMessageEx(cls, sel, hook, orig);
    NSLog(@"[WAGram][LiquidGlass] hooked -[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(sel));
}

static void WAGRLGHookClassMethod(Class cls, SEL sel, IMP hook, IMP *orig) {
    if (!cls || !sel || !hook || !orig || *orig) return;
    Method m = class_getClassMethod(cls, sel);
    if (!m) return;
    Class meta = object_getClass(cls);
    if (!meta) return;
    MSHookMessageEx(meta, sel, hook, orig);
    NSLog(@"[WAGram][LiquidGlass] hooked +[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(sel));
}

static void WAGRLGInstallAllHooks(void) {
    if (_wagrLGHooksInstalled) return;

    Class wdslg = NSClassFromString(@"WDSLiquidGlass");
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"hasLiquidGlassLaunched"), (IMP)hook_WDSLiquidGlass_hasLiquidGlassLaunched, (IMP *)&orig_WDSLiquidGlass_hasLiquidGlassLaunched);
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"isM0Enabled"), (IMP)hook_WDSLiquidGlass_isM0Enabled, (IMP *)&orig_WDSLiquidGlass_isM0Enabled);
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"isM1Enabled"), (IMP)hook_WDSLiquidGlass_isM1Enabled, (IMP *)&orig_WDSLiquidGlass_isM1Enabled);
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"isM1_5Enabled"), (IMP)hook_WDSLiquidGlass_isM1_5Enabled, (IMP *)&orig_WDSLiquidGlass_isM1_5Enabled);
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"isM1_5ContextMenuEnabled"), (IMP)hook_WDSLiquidGlass_isM1_5ContextMenuEnabled, (IMP *)&orig_WDSLiquidGlass_isM1_5ContextMenuEnabled);
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"isLargerComposerEnabled"), (IMP)hook_WDSLiquidGlass_isLargerComposerEnabled, (IMP *)&orig_WDSLiquidGlass_isLargerComposerEnabled);
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"isNativeSidebarEnabled"), (IMP)hook_WDSLiquidGlass_isNativeSidebarEnabled, (IMP *)&orig_WDSLiquidGlass_isNativeSidebarEnabled);
    WAGRLGHookClassMethod(wdslg, NSSelectorFromString(@"shouldUseNativeSwipeActions"), (IMP)hook_WDSLiquidGlass_shouldUseNativeSwipeActions, (IMP *)&orig_WDSLiquidGlass_shouldUseNativeSwipeActions);

    Class waab = NSClassFromString(@"WAABProperties");
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_enabled"), (IMP)hook_WAAB_ios_liquid_glass_enabled, (IMP *)&orig_WAAB_ios_liquid_glass_enabled);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_launched"), (IMP)hook_WAAB_ios_liquid_glass_launched, (IMP *)&orig_WAAB_ios_liquid_glass_launched);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_m1"), (IMP)hook_WAAB_ios_liquid_glass_m1, (IMP *)&orig_WAAB_ios_liquid_glass_m1);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_m_1_5"), (IMP)hook_WAAB_ios_liquid_glass_m_1_5, (IMP *)&orig_WAAB_ios_liquid_glass_m_1_5);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_m_1_5_context_menu"), (IMP)hook_WAAB_ios_liquid_glass_m_1_5_context_menu, (IMP *)&orig_WAAB_ios_liquid_glass_m_1_5_context_menu);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_media_m0"), (IMP)hook_WAAB_ios_liquid_glass_media_m0, (IMP *)&orig_WAAB_ios_liquid_glass_media_m0);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_larger_composer"), (IMP)hook_WAAB_ios_liquid_glass_larger_composer, (IMP *)&orig_WAAB_ios_liquid_glass_larger_composer);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_media_editor_enabled"), (IMP)hook_WAAB_ios_liquid_glass_media_editor_enabled, (IMP *)&orig_WAAB_ios_liquid_glass_media_editor_enabled);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_calling_improvement_enabled"), (IMP)hook_WAAB_ios_liquid_glass_calling_improvement_enabled, (IMP *)&orig_WAAB_ios_liquid_glass_calling_improvement_enabled);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_workaround_attachment_tray"), (IMP)hook_WAAB_ios_liquid_glass_workaround_attachment_tray, (IMP *)&orig_WAAB_ios_liquid_glass_workaround_attachment_tray);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_reduce_transparency"), (IMP)hook_WAAB_ios_liquid_glass_reduce_transparency, (IMP *)&orig_WAAB_ios_liquid_glass_reduce_transparency);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_fixes_for_older_ios"), (IMP)hook_WAAB_ios_liquid_glass_fixes_for_older_ios, (IMP *)&orig_WAAB_ios_liquid_glass_fixes_for_older_ios);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"status_viewer_redesign_enabled"), (IMP)hook_WAAB_status_viewer_redesign_enabled, (IMP *)&orig_WAAB_status_viewer_redesign_enabled);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_chat_top_bar_m2_enabled"), (IMP)hook_WAAB_ios_liquid_glass_chat_top_bar_m2_enabled, (IMP *)&orig_WAAB_ios_liquid_glass_chat_top_bar_m2_enabled);
    WAGRLGHookInstanceMethod(waab, NSSelectorFromString(@"ios_liquid_glass_enable_new_chatbar_ux"), (IMP)hook_WAAB_ios_liquid_glass_enable_new_chatbar_ux, (IMP *)&orig_WAAB_ios_liquid_glass_enable_new_chatbar_ux);

    Class overrideClass = NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults");
    WAGRLGHookInstanceMethod(overrideClass, NSSelectorFromString(@"isEnabled"), (IMP)hook_WALGOverride_isEnabled, (IMP *)&orig_WALGOverride_isEnabled);

    Class igHelper = NSClassFromString(@"IGLiquidGlassExperimentHelper");
    WAGRLGHookClassMethod(igHelper, NSSelectorFromString(@"isEnabled"), (IMP)hook_IGLGExperimentHelper_isEnabled, (IMP *)&orig_IGLGExperimentHelper_isEnabled);

    _wagrLGHooksInstalled = YES;
}

__attribute__((constructor))
static void WAGRLiquidGlassInit(void) {
    @autoreleasepool {
        WAGRLGApplyUserDefaultsOverride();
        WAGRLGInstallAllHooks();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRLGInstallAllHooks(); });
    }
}

extern "C" void WAGRLGPrefsDidChange(void) {
    WAGRLGApplyUserDefaultsOverride();
    WAGRLGInstallAllHooks();
}

extern "C" NSString *WAGRLGDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"master=%@\nhooksInstalled=%@\nWDSLiquidGlass=%@\nWAABProperties=%@\nOverrideClass=%@",
        WAGRLGEnabled() ? @"ON" : @"OFF",
        _wagrLGHooksInstalled ? @"YES" : @"NO",
        NSClassFromString(@"WDSLiquidGlass") ? @"found" : @"missing",
        NSClassFromString(@"WAABProperties") ? @"found" : @"missing",
        NSClassFromString(@"WALiquidGlassOverrideMethodUserDefaults") ? @"found" : @"missing"];
}
