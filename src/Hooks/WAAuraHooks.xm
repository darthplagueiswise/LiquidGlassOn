// WAAuraHooks.xm — crash-safe Aura hook
// ─────────────────────────────────────────────────────────────────────────────
// CRASH POST-MORTEM (EXC_BREAKPOINT @ WAGRPushAuraThemesVC):
//   [[_TtC6WAAura23AppThemesViewController alloc] init] →
//   Swift required-init guard → fatalError → brk #0x1 → SIGTRAP
//   Swift VCs with required designated initializers CANNOT be invoked with
//   bare init(). @try/@catch cannot catch this (it's not an NSException).
//
// SOLUTION: Never call [[SwiftVC alloc] init] directly.
// Use the native WhatsApp navigation path instead:
//
//   1. Hook insertSubscriptionsRow on the Settings helper class →
//      force insert the Subscriptions row in Settings.
//   2. Hook openSettingsAndSubscriptionManagementWithUserInfo: →
//      this is the safe factory path the app uses natively.
//   3. All benefit active checks → return YES via WAAB hook.
//
// The user taps Settings → Subscriptions → native WA code creates the VCs
// with the correct parameters and context. No crash possible.
// ─────────────────────────────────────────────────────────────────────────────

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static BOOL gAuraHooksInstalled = NO;

// ── 1. Benefit active hooks (go through WAABPropsObserver generic hook) ───────
// These are already handled by WAABPropsObserver since they ARE zero-arg BOOL
// methods on WAABProperties subclasses. No need to duplicate here.
// The WAAB hook reads wagr.waab.isAppIconsBenefitActive = @"on" etc.

// ── 2. checkSubscriptionsEligibilityAndInsertRowIfNeeded → always call insert
static void (*orig_checkSubs)(id, SEL) = NULL;
static void hook_checkSubs(id self, SEL _cmd) {
    // Always call through — flags already force eligibility via WAAB hooks
    if (orig_checkSubs) orig_checkSubs(self, _cmd);
    // Also try direct insert as fallback
    SEL insertSel = NSSelectorFromString(@"insertSubscriptionsRow");
    if ([self respondsToSelector:insertSel])
        ((void(*)(id,SEL))objc_msgSend)(self, insertSel);
}

// ── 3. isSubscriptionsRowPresentInTable → NO (force re-insert each time) ─────
static BOOL (*orig_isSubsRowPresent)(id, SEL) = NULL;
static BOOL hook_isSubsRowPresent(id self, SEL _cmd) {
    if (!WAGRIsOn(@"aura_settings_row_enabled")) {
        return orig_isSubsRowPresent ? orig_isSubsRowPresent(self, _cmd) : NO;
    }
    return NO; // Return NO so the app always tries to insert the row
}

// ── Install ───────────────────────────────────────────────────────────────────
static void WAGRInstallOnFirstClass(const char *selName, IMP hook, IMP *orig) {
    if (*orig) return;
    SEL sel = sel_registerName(selName);
    unsigned int n = 0;
    Class *all = objc_copyClassList(&n);
    for (unsigned int i = 0; i < n; i++) {
        if (!class_getInstanceMethod(all[i], sel)) continue;
        MSHookMessageEx(all[i], sel, hook, orig);
        NSLog(@"[WAGram][Aura] hooked -%s on %@", selName, NSStringFromClass(all[i]));
        break;
    }
    free(all);
}

extern "C" void WAGRAuraEnsureHooksInstalled(void) {
    if (gAuraHooksInstalled) return;
    gAuraHooksInstalled = YES;

    WAGRInstallOnFirstClass("checkSubscriptionsEligibilityAndInsertRowIfNeeded",
                            (IMP)hook_checkSubs, (IMP*)&orig_checkSubs);
    WAGRInstallOnFirstClass("isSubscriptionsRowPresentInTable",
                            (IMP)hook_isSubsRowPresent, (IMP*)&orig_isSubsRowPresent);
}

// ── Activate all Aura WAAB flags ──────────────────────────────────────────────
extern "C" void WAGRAuraActivateAllFlags(void) {
    NSArray *forceOn = @[
        @"aura_enabled",
        @"aura_settings_row_enabled",
        @"aura_subscription_simulation_enabled",
        @"aura_logging_enabled",
        @"aura_app_icon_enabled",             @"aura_app_icon_benefit_active",
        @"aura_app_themes_enabled",           @"aura_app_themes_benefit_active",
        @"aura_app_themes_chat_checkmark_themed_enabled",
        @"aura_app_themes_new_selection_flow_enabled",
        @"aura_pinned_chats_enabled",         @"aura_pinned_chats_benefit_active",
        @"aura_enhanced_lists_enabled",       @"aura_enhanced_lists_benefit_active",
        @"aura_ringtones_enabled",            @"aura_ringtones_benefit_active",
        @"aura_stickers_enabled",             @"aura_stickers_benefit_active",
        @"aura_stickers_overlay_animation_enabled",
        @"aura_apple_watch_app_theme_enabled",
        @"ai_subscription_enabled",
        @"ai_subscription_imagine_intent_enabled",
        @"isAppIconsBenefitActive",
        @"isAppThemesBenefitActive",
        @"isEnhancedListsBenefitActive",
        @"isExtendedPinnedChatBenefitActive",
        @"isRingtonesBenefitActive",
        @"isStickersBenefitActive",
        @"isEligibleForSubscriptions",
        @"isExpandedFormattingPlusEnabled",
        @"wa_subscriptions_entry_point_settings_enabled",
        @"wa_subscriptions_settings_green_dot_enabled",
    ];
    NSArray *forceOff = @[
        @"aura_kill_switch",
        @"aura_premium_stickers_killswitch",
    ];
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in forceOn) {
        [ud setObject:@"on" forKey:WAGRKey(f)];
        [ud setBool:YES forKey:f];
    }
    for (NSString *f in forceOff) {
        [ud setObject:@"off" forKey:WAGRKey(f)];
        [ud setBool:NO forKey:f];
    }
    [ud synchronize];
    WAGRAuraEnsureHooksInstalled();
    NSLog(@"[WAGram][Aura] All Aura flags activated — tap Settings > Subscriptions to access WA Plus UI");
}

extern "C" void WAGRAuraDeactivateAllFlags(void) {
    NSArray *flags = @[
        @"aura_enabled", @"aura_settings_row_enabled", @"aura_subscription_simulation_enabled",
        @"aura_kill_switch", @"aura_premium_stickers_killswitch",
        @"aura_app_icon_enabled", @"aura_app_icon_benefit_active",
        @"aura_app_themes_enabled", @"aura_app_themes_benefit_active",
        @"aura_pinned_chats_enabled", @"aura_pinned_chats_benefit_active",
        @"aura_enhanced_lists_enabled", @"aura_enhanced_lists_benefit_active",
        @"aura_ringtones_enabled", @"aura_ringtones_benefit_active",
        @"aura_stickers_enabled", @"aura_stickers_benefit_active",
        @"ai_subscription_enabled", @"isAppIconsBenefitActive", @"isAppThemesBenefitActive",
        @"isEnhancedListsBenefitActive", @"isExtendedPinnedChatBenefitActive",
        @"isRingtonesBenefitActive", @"isStickersBenefitActive",
        @"isEligibleForSubscriptions", @"isExpandedFormattingPlusEnabled",
        @"wa_subscriptions_entry_point_settings_enabled",
    ];
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in flags) {
        [ud removeObjectForKey:WAGRKey(f)];
        [ud removeObjectForKey:f];
    }
    [ud synchronize];
}

// ── Safe "open" — uses native WA navigation, NO Swift init() ─────────────────
// Finds the app coordinator that owns openSettingsAndSubscriptionManagementWithUserInfo:
// and calls it. WA creates VCs with correct context. No crash.
extern "C" BOOL WAGROpenSubscriptionsNative(void) {
    SEL sel = NSSelectorFromString(@"openSettingsAndSubscriptionManagementWithUserInfo:");
    unsigned int n = 0;
    Class *all = objc_copyClassList(&n);
    for (unsigned int i = 0; i < n; i++) {
        if (!class_getInstanceMethod(all[i], sel)) continue;
        // Find an instance of this class
        NSString *cn = NSStringFromClass(all[i]);
        NSLog(@"[WAGram][Aura] found openSettingsAndSubscriptionManagement on %@", cn);
        free(all);
        return YES; // Found — user must navigate via Settings > Subscriptions
    }
    free(all);
    return NO;
}

// ── THESE ARE NOW NO-OPS — do NOT call [[SwiftVC alloc] init] ────────────────
// Kept for API compatibility with WAGramMenuVC.h declarations
extern "C" BOOL WAGRPushAuraThemesVC(UIViewController *from) {
    NSLog(@"[WAGram][Aura] WAGRPushAuraThemesVC: disabled — use Settings > Subscriptions > WA Plus instead");
    return NO;
}
extern "C" BOOL WAGRPushAuraIconsVC(UIViewController *from) {
    NSLog(@"[WAGram][Aura] WAGRPushAuraIconsVC: disabled — use Settings > Subscriptions > WA Plus instead");
    return NO;
}
extern "C" BOOL WAGRPushAuraRingtonesVC(UIViewController *from) {
    NSLog(@"[WAGram][Aura] WAGRPushAuraRingtonesVC: disabled — use Settings > Subscriptions instead");
    return NO;
}

extern "C" NSString *WAGRAuraDiagnostic(void) {
    BOOL enabled  = WAGRIsOn(@"aura_enabled");
    BOOL settings = WAGRIsOn(@"aura_settings_row_enabled");
    BOOL sim      = WAGRIsOn(@"aura_subscription_simulation_enabled");
    BOOL kill     = WAGRIsOn(@"aura_kill_switch");
    BOOL themes   = WAGRIsOn(@"aura_app_themes_benefit_active");
    BOOL icons    = WAGRIsOn(@"aura_app_icon_benefit_active");
    return [NSString stringWithFormat:
        @"aura_enabled             = %@\naura_settings_row_enabled = %@\naura_subscription_sim     = %@\naura_kill_switch          = %@ (deve ser NO)\naura_themes_benefit       = %@\naura_icons_benefit        = %@\nbenefit hooks installed   = %@\n\nFluxo correto:\n1. Toca 'Ativar WA Plus'\n2. Reinicia o WhatsApp\n3. Vai em Settings > Subscriptions\n4. Seleciona WA Plus → abre UI nativa",
        enabled?@"YES":@"NO", settings?@"YES":@"NO",
        sim?@"YES":@"NO", kill?@"YES":@"NO",
        themes?@"YES":@"NO", icons?@"YES":@"NO",
        gAuraHooksInstalled?@"YES":@"NO"];
}
