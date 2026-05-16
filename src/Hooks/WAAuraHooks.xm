// WAAuraHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Exposes WAAura native ViewControllers (confirmed in WhatsApp binary):
//   _TtC6WAAura22AppIconsViewController    → custom app icon picker
//   _TtC6WAAura23AppThemesViewController   → custom theme/color picker
//   WACallRingtonePickerViewController     → custom ringtone picker
//
// Strategy:
//   1. Set all WAAB aura_* flags to ON via NSUserDefaults (WAABPropsObserver picks them up)
//   2. Set aura_kill_switch to force-OFF
//   3. Hook isAppIconsBenefitActive / isAppThemesBenefitActive on GatedBenefitProvider
//   4. Directly push the native VCs via NSClassFromString + alloc/init
//
// Navigation path confirmed in binary:
//   getSubscriptionsHomeViewControllerWithParams: → subscriptions home
//   SettingsView_SubscriptionsCell → Settings cell (shows when aura_settings_row_enabled=YES)
// ─────────────────────────────────────────────────────────────────────────────

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

extern "C" void WAGRWAABEnsureHooksInstalled(void);

static BOOL gAuraHooksInstalled = NO;

// ── Hook benefit active checks on WAAuraGating.GatedBenefitProvider ────────────
static BOOL (*orig_isAppIconsBenefitActive)(id, SEL) = NULL;
static BOOL (*orig_isAppThemesBenefitActive)(id, SEL) = NULL;
static BOOL (*orig_isRingtonesBenefitActive)(id, SEL) = NULL;
static BOOL (*orig_isEnhancedListsBenefitActive)(id, SEL) = NULL;
static BOOL (*orig_isExtendedPinnedChatBenefitActive)(id, SEL) = NULL;
static BOOL (*orig_isStickersBenefitActive)(id, SEL) = NULL;
static BOOL (*orig_isEligibleForSubscriptions)(id, SEL) = NULL;
static BOOL (*orig_isExpandedFormattingPlusEnabled)(id, SEL) = NULL;

#define BENEFIT_HOOK(name, orig) \
static BOOL hook_##name(id s, SEL c) { \
    if (WAGRIsOn(@#name) || WAGRPref(kWAGRLiquidGlassMaster)) return YES; \
    return orig ? orig(s, c) : NO; \
}

BENEFIT_HOOK(isAppIconsBenefitActive, orig_isAppIconsBenefitActive)
BENEFIT_HOOK(isAppThemesBenefitActive, orig_isAppThemesBenefitActive)
BENEFIT_HOOK(isRingtonesBenefitActive, orig_isRingtonesBenefitActive)
BENEFIT_HOOK(isEnhancedListsBenefitActive, orig_isEnhancedListsBenefitActive)
BENEFIT_HOOK(isExtendedPinnedChatBenefitActive, orig_isExtendedPinnedChatBenefitActive)
BENEFIT_HOOK(isStickersBenefitActive, orig_isStickersBenefitActive)
BENEFIT_HOOK(isEligibleForSubscriptions, orig_isEligibleForSubscriptions)
BENEFIT_HOOK(isExpandedFormattingPlusEnabled, orig_isExpandedFormattingPlusEnabled)

// ── Kill-switch override (aura_kill_switch must return NO) ─────────────────────
static BOOL WAGRWAABGenericBoolHookExternal(id self, SEL _cmd);

// aura_kill_switch → force NO (it's a KILL switch, so NO = Aura enabled)
// This is handled generically by WAABPropsObserver with @"off" storage.
// WAGRSet(@"aura_kill_switch", NO) sets it to @"off" which returns NO.

// ── Hook installer ─────────────────────────────────────────────────────────────
static void WAGRHookBenefitSel(const char *selName, IMP hook, IMP *orig) {
    if (*orig) return;
    SEL sel = sel_registerName(selName);
    unsigned int total = 0;
    Class *all = objc_copyClassList(&total);
    for (unsigned int i = 0; i < total; i++) {
        if (!class_getInstanceMethod(all[i], sel)) continue;
        NSString *cn = NSStringFromClass(all[i]);
        if ([cn containsString:@"AuraGating"] || [cn containsString:@"Aura"] || [cn containsString:@"GatedBenefit"]) {
            MSHookMessageEx(all[i], sel, hook, orig);
            NSLog(@"[WAGram][Aura] hooked -%s on %@", selName, cn);
            break;
        }
    }
    // Fallback: try any class
    if (!*orig) {
        for (unsigned int i = 0; i < total; i++) {
            if (!class_getInstanceMethod(all[i], sel)) continue;
            MSHookMessageEx(all[i], sel, hook, orig);
            NSLog(@"[WAGram][Aura] fallback -%s on %@", selName, NSStringFromClass(all[i]));
            break;
        }
    }
    free(all);
}

extern "C" void WAGRAuraEnsureHooksInstalled(void) {
    if (gAuraHooksInstalled) return;
    gAuraHooksInstalled = YES;

    WAGRHookBenefitSel("isAppIconsBenefitActive",           (IMP)hook_isAppIconsBenefitActive,           (IMP*)&orig_isAppIconsBenefitActive);
    WAGRHookBenefitSel("isAppThemesBenefitActive",          (IMP)hook_isAppThemesBenefitActive,          (IMP*)&orig_isAppThemesBenefitActive);
    WAGRHookBenefitSel("isRingtonesBenefitActive",          (IMP)hook_isRingtonesBenefitActive,          (IMP*)&orig_isRingtonesBenefitActive);
    WAGRHookBenefitSel("isEnhancedListsBenefitActive",      (IMP)hook_isEnhancedListsBenefitActive,      (IMP*)&orig_isEnhancedListsBenefitActive);
    WAGRHookBenefitSel("isExtendedPinnedChatBenefitActive", (IMP)hook_isExtendedPinnedChatBenefitActive, (IMP*)&orig_isExtendedPinnedChatBenefitActive);
    WAGRHookBenefitSel("isStickersBenefitActive",           (IMP)hook_isStickersBenefitActive,           (IMP*)&orig_isStickersBenefitActive);
    WAGRHookBenefitSel("isEligibleForSubscriptions",        (IMP)hook_isEligibleForSubscriptions,        (IMP*)&orig_isEligibleForSubscriptions);
    WAGRHookBenefitSel("isExpandedFormattingPlusEnabled",   (IMP)hook_isExpandedFormattingPlusEnabled,   (IMP*)&orig_isExpandedFormattingPlusEnabled);
}


static void WAGRAuraSetBoolOverride(NSString *flag, NSString *value) {
    if (!flag.length) return;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (value.length) {
        [ud setObject:value forKey:WAGRKey(flag)];
        if ([value isEqualToString:@"on"]) [ud setBool:YES forKey:flag];
        else if ([value isEqualToString:@"off"]) [ud setBool:NO forKey:flag];
    } else {
        [ud removeObjectForKey:WAGRKey(flag)];
        [ud removeObjectForKey:flag];
    }
}

// ── Activate all Aura WAAB flags at once ──────────────────────────────────────
extern "C" void WAGRAuraActivateAllFlags(void) {
    // These go through WAABPropsObserver's generic hook
    NSArray *forceOn = @[
        @"aura_enabled",
        @"aura_settings_row_enabled",
        @"aura_subscription_simulation_enabled",
        @"aura_logging_enabled",
        @"aura_app_icon_enabled",
        @"aura_app_icon_benefit_active",
        @"aura_app_themes_enabled",
        @"aura_app_themes_benefit_active",
        @"aura_app_themes_chat_checkmark_themed_enabled",
        @"aura_app_themes_new_selection_flow_enabled",
        @"aura_pinned_chats_enabled",
        @"aura_pinned_chats_benefit_active",
        @"aura_enhanced_lists_enabled",
        @"aura_enhanced_lists_benefit_active",
        @"aura_ringtones_enabled",
        @"aura_ringtones_benefit_active",
        @"aura_stickers_enabled",
        @"aura_stickers_benefit_active",
        @"ai_subscription_enabled",
    ];
    NSArray *forceOff = @[
        @"aura_kill_switch",            // kill switch → OFF = enabled
        @"aura_premium_stickers_killswitch",
    ];
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in forceOn) WAGRAuraSetBoolOverride(f, @"on");
    for (NSString *f in forceOff) WAGRAuraSetBoolOverride(f, @"off");
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    WAGRAuraEnsureHooksInstalled();
}

// ── Deactivate all Aura flags ──────────────────────────────────────────────────
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
        @"ai_subscription_enabled",
    ];
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in flags) WAGRAuraSetBoolOverride(f, nil);
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
}

// ── Present native Aura VC directly ───────────────────────────────────────────
extern "C" BOOL WAGRPushAuraThemesVC(UIViewController *from) {
    Class cls = NSClassFromString(@"_TtC6WAAura23AppThemesViewController");
    if (!cls) cls = NSClassFromString(@"AppThemesViewController");
    if (!cls) { NSLog(@"[WAGram][Aura] AppThemesViewController not found"); return NO; }
    UIViewController *vc = [[cls alloc] init];
    if (!vc) return NO;
    if (from.navigationController)
        [from.navigationController pushViewController:vc animated:YES];
    else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [from presentViewController:nav animated:YES completion:nil];
    }
    return YES;
}

extern "C" BOOL WAGRPushAuraIconsVC(UIViewController *from) {
    Class cls = NSClassFromString(@"_TtC6WAAura22AppIconsViewController");
    if (!cls) cls = NSClassFromString(@"AppIconsViewController");
    if (!cls) { NSLog(@"[WAGram][Aura] AppIconsViewController not found"); return NO; }
    UIViewController *vc = [[cls alloc] init];
    if (!vc) return NO;
    if (from.navigationController)
        [from.navigationController pushViewController:vc animated:YES];
    else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [from presentViewController:nav animated:YES completion:nil];
    }
    return YES;
}

extern "C" BOOL WAGRPushAuraRingtonesVC(UIViewController *from) {
    Class cls = NSClassFromString(@"WACallRingtonePickerViewController");
    if (!cls) return NO;
    UIViewController *vc = [[cls alloc] init];
    if (!vc) return NO;
    if (from.navigationController)
        [from.navigationController pushViewController:vc animated:YES];
    else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [from presentViewController:nav animated:YES completion:nil];
    }
    return YES;
}

extern "C" NSString *WAGRAuraDiagnostic(void) {
    BOOL enabled     = WAGRIsOn(@"aura_enabled");
    BOOL settingsRow = WAGRIsOn(@"aura_settings_row_enabled");
    BOOL simulation  = WAGRIsOn(@"aura_subscription_simulation_enabled");
    BOOL killSwitch  = WAGRIsOn(@"aura_kill_switch"); // should be OFF/absent
    BOOL themes      = WAGRIsOn(@"aura_app_themes_benefit_active");
    BOOL icons       = WAGRIsOn(@"aura_app_icon_benefit_active");
    Class themesVC   = NSClassFromString(@"_TtC6WAAura23AppThemesViewController");
    Class iconsVC    = NSClassFromString(@"_TtC6WAAura22AppIconsViewController");
    return [NSString stringWithFormat:
        @"aura_enabled              = %@\naura_settings_row_enabled  = %@\naura_subscription_sim      = %@\naura_kill_switch           = %@ (should be NO)\naura_themes_benefit        = %@\naura_icons_benefit         = %@\nAppThemesVC found          = %@\nAppIconsVC found           = %@\nbenefit hooks installed    = %@",
        enabled?@"YES":@"NO", settingsRow?@"YES":@"NO",
        simulation?@"YES":@"NO", killSwitch?@"YES":@"NO",
        themes?@"YES":@"NO", icons?@"YES":@"NO",
        themesVC?@"YES":@"NO", iconsVC?@"YES":@"NO",
        gAuraHooksInstalled?@"YES":@"NO"];
}
