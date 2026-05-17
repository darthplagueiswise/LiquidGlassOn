// WAAuraHooks.xm — Aura / Subscription simulation helpers
// Scope: local feature-gate simulation and native VC discovery/launch.
// Does not write keychain payloads and does not read kSecValueData.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "../WAGramPrefix.h"

extern "C" void WAGRWAABEnsureHooksInstalled(void);
extern "C" BOOL WAGRWAABOriginalBoolForFlag(NSString *flag, BOOL *knownOut);

static NSString * const kWAGRAuraSimulationMaster = @"wagr_aura_simulation_enabled";

static NSArray<NSString *> *WAGRAuraPositiveFlags(void) {
    return @[
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
        @"aura_app_themes_share_extension_themed_enabled",
        @"aura_app_themes_status_ring_enabled",
        @"aura_app_themes_illustration_lottie_enabled",
        @"aura_apple_watch_app_theme_enabled",
        @"aura_apple_watch_app_themes_enabled",
        @"aura_pinned_chats_enabled",
        @"aura_pinned_chats_benefit_active",
        @"aura_pinned_chats_targeted_nux_force",
        @"aura_enhanced_lists_enabled",
        @"aura_enhanced_lists_benefit_active",
        @"aura_ringtones_enabled",
        @"aura_ringtones_benefit_active",
        @"aura_ringtones_per_chat_enabled",
        @"aura_stickers_enabled",
        @"aura_stickers_benefit_active",
        @"aura_stickers_overlay_animation_enabled",
        @"aura_painted_door_stickers_enabled",
        @"ai_subscription_enabled",
        @"ai_subscription_imagine_intent_enabled",
        @"isExpandedFormattingPlusEnabled",
        @"isEligibleForSubscriptions",
        @"isAppIconsBenefitActive",
        @"isAppThemesBenefitActive",
        @"isEnhancedListsBenefitActive",
        @"isExtendedPinnedChatBenefitActive",
        @"isRingtonesBenefitActive",
        @"isStickersBenefitActive",
        @"isSubscribedToAiBenefit",
        @"isAISubscriptionEnabled"
    ];
}

static NSArray<NSString *> *WAGRAuraNegativeFlags(void) {
    return @[
        @"aura_kill_switch",
        @"aura_premium_stickers_killswitch",
        @"aura_stickers_old_client_block_enabled"
    ];
}

static BOOL WAGRAuraSimulationEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWAGRAuraSimulationMaster];
}

static BOOL WAGRAuraSystemDefaultForFlag(NSString *flag, BOOL *knownOut) {
    BOOL known = NO;
    BOOL value = WAGRWAABOriginalBoolForFlag(flag, &known);
    if (knownOut) *knownOut = known;
    return known ? value : NO;
}

static void WAGRSetWAABOverride(NSString *flag, NSString *value) {
    if (!flag.length) return;
    if (value.length) [[NSUserDefaults standardUserDefaults] setObject:value forKey:WAGRKey(flag)];
    else [[NSUserDefaults standardUserDefaults] removeObjectForKey:WAGRKey(flag)];
}

static void WAGRSetWAABEffective(NSString *flag, BOOL desired) {
    if (!flag.length) return;
    BOOL known = NO;
    BOOL sys = WAGRAuraSystemDefaultForFlag(flag, &known);
    if (desired) {
        if (known && sys) WAGRSetWAABOverride(flag, nil);
        else WAGRSetWAABOverride(flag, @"on");
    } else {
        if (known && sys) WAGRSetWAABOverride(flag, @"off");
        else WAGRSetWAABOverride(flag, nil);
    }
}

extern "C" void WAGRAuraEnsureHooksInstalled(void) {
    [[NSUserDefaults standardUserDefaults] synchronize];
}

extern "C" void WAGRAuraActivateAllFlags(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:YES forKey:kWAGRAuraSimulationMaster];
    for (NSString *flag in WAGRAuraPositiveFlags()) WAGRSetWAABEffective(flag, YES);
    for (NSString *flag in WAGRAuraNegativeFlags()) WAGRSetWAABEffective(flag, NO);
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
}

extern "C" void WAGRAuraDeactivateAllFlags(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud removeObjectForKey:kWAGRAuraSimulationMaster];
    for (NSString *flag in WAGRAuraPositiveFlags()) WAGRSetWAABOverride(flag, nil);
    for (NSString *flag in WAGRAuraNegativeFlags()) WAGRSetWAABOverride(flag, nil);
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
}

static UINavigationController *WAGRAuraNavigationControllerFor(UIViewController *from) {
    if ([from isKindOfClass:UINavigationController.class]) return (UINavigationController *)from;
    if (from.navigationController) return from.navigationController;
    return nil;
}

static BOOL WAGRPushClassName(NSString *className, UIViewController *from) {
    Class cls = NSClassFromString(className);
    if (!cls) return NO;
    id vc = nil;
    @try { vc = [[cls alloc] init]; } @catch (__unused id ex) { vc = nil; }
    if (![vc isKindOfClass:UIViewController.class]) return NO;
    UINavigationController *nav = WAGRAuraNavigationControllerFor(from);
    if (nav) { [nav pushViewController:(UIViewController *)vc animated:YES]; return YES; }
    [from presentViewController:(UIViewController *)vc animated:YES completion:nil];
    return YES;
}

extern "C" BOOL WAGRPushAuraThemesVC(UIViewController *from) {
    if (!from) return NO;
    return WAGRPushClassName(@"_TtC6WAAura23AppThemesViewController", from);
}

extern "C" BOOL WAGRPushAuraIconsVC(UIViewController *from) {
    if (!from) return NO;
    return WAGRPushClassName(@"_TtC6WAAura22AppIconsViewController", from);
}

extern "C" BOOL WAGRPushAuraRingtonesVC(UIViewController *from) {
    if (!from) return NO;
    if (WAGRPushClassName(@"WACallRingtonePickerViewController", from)) return YES;
    return WAGRPushClassName(@"_TtC6WAAura30WACallRingtonePickerViewController", from);
}

extern "C" NSString *WAGRAuraDiagnostic(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSUInteger positiveOn = 0;
    NSUInteger negativeOff = 0;
    for (NSString *flag in WAGRAuraPositiveFlags()) if ([[ud stringForKey:WAGRKey(flag)] isEqualToString:@"on"]) positiveOn++;
    for (NSString *flag in WAGRAuraNegativeFlags()) if ([[ud stringForKey:WAGRKey(flag)] isEqualToString:@"off"]) negativeOff++;
    return [NSString stringWithFormat:
            @"simulation=%@\npositive overrides=%lu/%lu\nnegative gates OFF=%lu/%lu\nAppThemesVC=%@\nAppIconsVC=%@\nRingtoneVC=%@\nSubscriptionsCell=%@\nkeychain=not used for Aura simulation",
            WAGRAuraSimulationEnabled() ? @"ON" : @"OFF",
            (unsigned long)positiveOn, (unsigned long)WAGRAuraPositiveFlags().count,
            (unsigned long)negativeOff, (unsigned long)WAGRAuraNegativeFlags().count,
            NSClassFromString(@"_TtC6WAAura23AppThemesViewController") ? @"found" : @"missing",
            NSClassFromString(@"_TtC6WAAura22AppIconsViewController") ? @"found" : @"missing",
            NSClassFromString(@"WACallRingtonePickerViewController") ? @"found" : @"missing",
            NSClassFromString(@"SettingsView_SubscriptionsCell") ? @"found" : @"check by strings only"];
}
