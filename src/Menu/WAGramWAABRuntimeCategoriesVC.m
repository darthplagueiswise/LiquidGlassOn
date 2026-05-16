// WAGramWAABRuntimeCategoriesVC.m
// Runtime WAAB category browser for the newer WhatsApp framework.
// It does not depend on stale hardcoded v5/v6 menus: it reads WAABProperties method list at runtime.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "WAGramMenuVC.h"
#import "../WAUtils.h"
#import "../WAGramPrefix.h"

static UIColor *WAGRWAABBG(void) { return UIColor.systemBackgroundColor; }
static UIColor *WAGRWAABCellBG(void) { return UIColor.secondarySystemBackgroundColor; }
static UIColor *WAGRWAABAccent(void) { return UIColor.systemBlueColor; }
static UIColor *WAGRWAABGreen(void) { return UIColor.systemGreenColor; }
static UIColor *WAGRWAABSecondary(void) { return UIColor.secondaryLabelColor; }

static NSString *WAGRWAABState(NSString *flag) {
    if (!flag.length) return nil;
    return [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(flag)];
}

static void WAGRWAABSetState(NSString *flag, NSString *state) {
    if (!flag.length) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([state isEqualToString:@"on"] || [state isEqualToString:@"off"]) [ud setObject:state forKey:WAGRKey(flag)];
    else [ud removeObjectForKey:WAGRKey(flag)];
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    if ([flag containsString:@"liquid_glass"]) WAGRLGPrefsDidChange();
    if ([flag hasPrefix:@"aura_"] || [flag containsString:@"subscription"] || [flag containsString:@"benefit"]) WAGRAuraEnsureHooksInstalled();
    if ([flag containsString:@"dogfood"] || [flag containsString:@"internal"] || [flag containsString:@"employee"]) WAGRDogfoodEnsureHooksInstalled();
}

static BOOL WAGRContainsAnyToken(NSString *s, NSArray<NSString *> *tokens) {
    NSString *l = s.lowercaseString;
    for (NSString *t in tokens) if ([l containsString:t.lowercaseString]) return YES;
    return NO;
}

static NSArray<NSString *> *WAGRUniqueSorted(NSArray<NSString *> *arr) {
    return [[NSSet setWithArray:arr].allObjects sortedArrayUsingSelector:@selector(compare:)];
}

static BOOL WAGRFlagIsNegativeGate(NSString *flag) {
    NSString *f = flag.lowercaseString;
    return [f containsString:@"killswitch"] ||
           [f containsString:@"kill_switch"] ||
           [f containsString:@"disabled"] ||
           [f containsString:@"disable_"] ||
           [f hasPrefix:@"disable_"] ||
           [f containsString:@"block"] ||
           [f containsString:@"deny"] ||
           [f containsString:@"hide_"] ||
           [f hasPrefix:@"hide_"];
}

@interface WAGRWAABCategorySpec : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) NSArray<NSString *> *tokens;
@property (nonatomic, strong) NSArray<NSString *> *exact;
@property (nonatomic, assign) BOOL negativeMode;
+ (instancetype)title:(NSString *)title subtitle:(NSString *)subtitle tokens:(NSArray<NSString *> *)tokens exact:(NSArray<NSString *> *)exact negative:(BOOL)negative;
@end
@implementation WAGRWAABCategorySpec
+ (instancetype)title:(NSString *)title subtitle:(NSString *)subtitle tokens:(NSArray<NSString *> *)tokens exact:(NSArray<NSString *> *)exact negative:(BOOL)negative {
    WAGRWAABCategorySpec *s=[WAGRWAABCategorySpec new];
    s.title=title; s.subtitle=subtitle; s.tokens=tokens?:@[]; s.exact=exact?:@[]; s.negativeMode=negative;
    return s;
}
@end

@interface WAGRWAABTriStateBrowserVC : UITableViewController <UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags negativeMode:(BOOL)negativeMode;
@property (nonatomic, strong) NSArray<NSString *> *allFlags;
@property (nonatomic, strong) NSArray<NSString *> *filtered;
@property (nonatomic, assign) BOOL negativeMode;
@property (nonatomic, strong) UISearchController *search;
@end

static char kWAGRWAABFlagKey;

@implementation WAGRWAABTriStateBrowserVC
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags negativeMode:(BOOL)negativeMode {
    if (!(self=[super initWithStyle:UITableViewStylePlain])) return nil;
    self.title=title?:@"Flags";
    self.allFlags=WAGRUniqueSorted(flags?:@[]);
    self.filtered=self.allFlags;
    self.negativeMode=negativeMode;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor=WAGRWAABBG();
    self.search=[[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater=self;
    self.search.obscuresBackgroundDuringPresentation=NO;
    self.search.searchBar.placeholder=@"Buscar flag…";
    self.navigationItem.searchController=self.search;
    self.navigationItem.hidesSearchBarWhenScrolling=NO;
    [self updateTitle];
}
- (void)updateTitle {
    NSUInteger on=0, off=0;
    for (NSString *f in self.allFlags) {
        NSString *s=WAGRWAABState(f);
        if ([s isEqualToString:@"on"]) on++;
        else if ([s isEqualToString:@"off"]) off++;
    }
    self.navigationItem.title=[NSString stringWithFormat:@"%@ (%lu on / %lu off)", self.title?:@"Flags", (unsigned long)on, (unsigned long)off];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q=sc.searchBar.text?:@"";
    self.filtered=q.length?[self.allFlags filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@", q]]:self.allFlags;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.filtered.count; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 62.0; }
static NSInteger WAGRIndexForState(NSString *state) { if ([state isEqualToString:@"off"]) return 1; if ([state isEqualToString:@"on"]) return 2; return 0; }
static NSString *WAGRStateForIndex(NSInteger idx) { if (idx==1) return @"off"; if (idx==2) return @"on"; return nil; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell=[tv dequeueReusableCellWithIdentifier:@"tri"];
    if (!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tri"];
    NSString *flag=self.filtered[(NSUInteger)ip.row];
    NSString *state=WAGRWAABState(flag);
    BOOL negative=WAGRFlagIsNegativeGate(flag);
    cell.backgroundColor=WAGRWAABCellBG();
    cell.textLabel.text=flag;
    cell.textLabel.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines=2;
    if ([state isEqualToString:@"on"]) cell.textLabel.textColor=negative?UIColor.systemOrangeColor:WAGRWAABGreen();
    else if ([state isEqualToString:@"off"]) cell.textLabel.textColor=negative?WAGRWAABGreen():UIColor.systemOrangeColor;
    else cell.textLabel.textColor=UIColor.labelColor;
    cell.detailTextLabel.text=negative ? @"negative gate: ON blocks, OFF allows" : @"System / force OFF / force ON";
    cell.detailTextLabel.textColor=WAGRWAABSecondary();
    UISegmentedControl *seg=[[UISegmentedControl alloc] initWithItems:@[@"System", @"Off", @"On"]];
    seg.selectedSegmentIndex=WAGRIndexForState(state);
    objc_setAssociatedObject(seg, &kWAGRWAABFlagKey, flag, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [seg addTarget:self action:@selector(segChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView=seg;
    cell.selectionStyle=UITableViewCellSelectionStyleNone;
    return cell;
}
- (void)segChanged:(UISegmentedControl *)seg {
    NSString *flag=objc_getAssociatedObject(seg, &kWAGRWAABFlagKey);
    WAGRWAABSetState(flag, WAGRStateForIndex(seg.selectedSegmentIndex));
    [self updateTitle];
    [self.tableView reloadData];
}
@end

@interface WAGRWAABCategoryBundleVC : UITableViewController
- (instancetype)initWithSpec:(WAGRWAABCategorySpec *)spec flags:(NSArray<NSString *> *)flags;
@property (nonatomic, strong) WAGRWAABCategorySpec *spec;
@property (nonatomic, strong) NSArray<NSString *> *flags;
@end
@implementation WAGRWAABCategoryBundleVC
- (instancetype)initWithSpec:(WAGRWAABCategorySpec *)spec flags:(NSArray<NSString *> *)flags {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.spec=spec; self.flags=WAGRUniqueSorted(flags?:@[]); self.title=spec.title;
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor=WAGRWAABBG(); }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return 1; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section==0) return self.spec.negativeMode ? @"Este grupo usa semântica invertida: master ON força os gates negativos para OFF, liberando a feature quando os outros gates positivos permitirem." : self.spec.subtitle;
    return nil;
}
- (NSUInteger)activeCount {
    NSUInteger n=0;
    NSString *target=self.spec.negativeMode?@"off":@"on";
    for (NSString *f in self.flags) if ([WAGRWAABState(f) isEqualToString:target]) n++;
    return n;
}
- (void)setAll:(BOOL)enabled {
    NSString *state=enabled?(self.spec.negativeMode?@"off":@"on"):nil;
    for (NSString *f in self.flags) WAGRWAABSetState(f, state);
    [self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    if (ip.section==0) {
        UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        c.backgroundColor=WAGRWAABCellBG();
        NSUInteger active=[self activeCount];
        c.textLabel.text=self.spec.negativeMode?@"Permitir grupo (force OFF)":@"Ativar grupo (force ON)";
        c.detailTextLabel.text=[NSString stringWithFormat:@"%lu/%lu aplicados", (unsigned long)active, (unsigned long)self.flags.count];
        c.detailTextLabel.textColor=active?WAGRWAABGreen():WAGRWAABSecondary();
        UISwitch *sw=[UISwitch new]; sw.on=(active==self.flags.count && self.flags.count>0); sw.onTintColor=WAGRWAABAccent();
        [sw addTarget:self action:@selector(master:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView=sw; c.selectionStyle=UITableViewCellSelectionStyleNone; return c;
    }
    if (ip.section==1) {
        UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        c.backgroundColor=WAGRWAABCellBG(); c.textLabel.text=@"Flags individuais"; c.detailTextLabel.text=[NSString stringWithFormat:@"%lu", (unsigned long)self.flags.count]; c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; return c;
    }
    UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    c.backgroundColor=WAGRWAABCellBG(); c.textLabel.text=@"Diagnóstico WAAB"; c.textLabel.textColor=WAGRWAABAccent(); return c;
}
- (void)master:(UISwitch *)sw { [self setAll:sw.isOn]; }
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section==1) {
        WAGRWAABTriStateBrowserVC *vc=[[WAGRWAABTriStateBrowserVC alloc] initWithTitle:self.spec.title flags:self.flags negativeMode:self.spec.negativeMode];
        [self.navigationController pushViewController:vc animated:YES];
    } else if (ip.section==2) {
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"WAAB" message:WAGRWAABDiagnosticText() preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}
@end

@interface WAGramWAABRuntimeCategoriesVC ()
@property (nonatomic, strong) NSArray<WAGRWAABCategorySpec *> *specs;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSString *> *> *flagsByTitle;
@property (nonatomic, strong) NSArray<NSString *> *runtimeFlags;
@end

@implementation WAGramWAABRuntimeCategoriesVC
- (instancetype)init {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title=@"WAAB Runtime";
    return self;
}
+ (NSArray<WAGRWAABCategorySpec *> *)categorySpecs {
    return @[
        [WAGRWAABCategorySpec title:@"Settings Rows" subtitle:@"SettingsView_* cells: Lists, Favorites, Events, Waffle, Subscriptions, FOA bookmarks, Vibes." tokens:@[@"settings",@"bookmark",@"waffle",@"vibes",@"threads",@"horizon",@"favorites",@"events",@"lists"] exact:@[@"lists_feature_enabled",@"call_favorites_enabled_companions",@"events_global_list",@"waffle_mobile_companions_enabled",@"waffle_enabled_for_unlinked_users",@"waffle_foa_to_wa_linking_enabled",@"aura_settings_row_enabled",@"aura_enabled",@"sections_in_help_menu",@"foa_threads_bookmarks_enabled",@"foa_bridges_bookmark_meta_horizon",@"ai_rich_response_vibes_promotion_enabled",@"premium_blue_enabled",@"wa_subscriptions_entry_point_settings_enabled",@"wa_subscriptions_settings_green_dot_enabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"Tab Bar / Multi Account" subtitle:@"Account switcher and tabbar gates; profile picture/account switcher replacing settings tab icon." tokens:@[@"tab",@"multi_account",@"multiaccount",@"account_switcher",@"accountswitcher",@"xfam_lg_switcher"] exact:@[@"sg_ios_multi_account_enabled",@"wa_xfam_ios_switcher_multiaccount_enabled",@"foa_bridges_account_switcher_ios_enabled",@"deletion_reason_multi_account_enabled",@"ai_meta_ai_in_app_tab_main_gate_enabled",@"ai_home_in_tab_main_gate_enabled",@"community_tab_v2_enabled",@"updates_tab_filter_pills_enabled",@"channels_creation_entrypoint_in_updates_tab_enabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"Developer / Dogfood / Internal" subtitle:@"Debug menu, internal/dogfood gates, help feedback/bug sections." tokens:@[@"debug",@"dogfood",@"internal",@"employee",@"tester"] exact:@[@"mobile_config_debug_internal",@"dogfooder_diagnostics",@"ios_internal_hall_enabled",@"is_internal_tester",@"isMetaEmployeeOrInternalTester",@"is_meta_employee_or_internal_tester",@"isInternalUser",@"graphQLEmployeeC1Disabled",@"sections_in_help_menu"] negative:NO],
        [WAGRWAABCategorySpec title:@"WA Plus / Aura / Subscription" subtitle:@"Aura, App Themes, App Icons, Ringtones, benefit and subscription simulation flags." tokens:@[@"aura",@"subscription",@"benefit",@"premium",@"ringtones",@"app_themes",@"app_icon",@"stickers"] exact:@[@"aura_enabled",@"aura_settings_row_enabled",@"aura_subscription_simulation_enabled",@"aura_app_icon_enabled",@"aura_app_icon_benefit_active",@"aura_app_themes_enabled",@"aura_app_themes_benefit_active",@"aura_ringtones_enabled",@"aura_ringtones_benefit_active",@"aura_stickers_enabled",@"aura_stickers_benefit_active",@"ai_subscription_enabled",@"ai_subscription_imagine_intent_enabled",@"wa_subscriptions_entry_point_settings_enabled",@"wa_subscriptions_settings_green_dot_enabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"AI / Meta AI" subtitle:@"All AI gates grouped together: Meta AI tab, side chat, incognito, hatch, voice, imagine." tokens:@[@"ai_",@"meta_ai",@"incognito",@"hatch",@"imagine",@"llama",@"genai"] exact:@[@"ai_meta_ai_in_app_tab_main_gate_enabled",@"ai_home_redesign_enabled",@"ai_incognito_mode_enabled",@"ai_side_chat_enabled",@"ai_hatch_integration_enabled",@"ai_chat_thread_capability_enabled",@"ai_chat_threads_infra_enabled",@"ai_chat_threads_enabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"Calls" subtitle:@"Calls tab, scheduled calls, call links, voicemail, privacy and call UI." tokens:@[@"call",@"calling",@"callkit",@"voip",@"voicemail"] exact:@[@"calling_voicemail_enabled",@"enable_schedule_call_from_calls_tab",@"enable_scheduled_calls_v2_entry_points_creation",@"enable_new_call_invite",@"enable_new_call_link_representation",@"enable_in_call_more_menu_ios",@"enable_call_transfer_notification",@"enable_calling_phone_number_privacy",@"enable_calling_username"] negative:NO],
        [WAGRWAABCategorySpec title:@"Status / Channels" subtitle:@"Status viewer, bolder tiles, music, channels, updates tab and admin replies." tokens:@[@"status",@"story",@"stories",@"channel",@"newsletter",@"updates_tab"] exact:@[@"status_viewer_redesign_enabled",@"status_bolder_tiles_enabled",@"status_close_friends_multi_select_enabled",@"channel_status_creation_music_enabled",@"channel_status_consumption_music_enabled",@"channel_poll_status_card_enabled",@"channels_creation_enabled",@"channels_admin_reply_enabled",@"newsletter_forward_counter_ui_enabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"Chats / Messaging" subtitle:@"Translation, AI threads, scheduled messages, stickers, polls, context menu and message UI." tokens:@[@"chat",@"message",@"messaging",@"sticker",@"poll",@"translation",@"scheduled"] exact:@[@"ai_translate_messages_enabled",@"ai_chat_thread_capability_enabled",@"ai_chat_threads_infra_enabled",@"ai_chat_threads_enabled",@"scheduled_messages_sender_enabled",@"scheduled_messages_receiver_enabled",@"poll_add_option_enabled",@"poll_creator_edit_enabled",@"poll_end_time_enabled",@"enable_sticker_lottie_reader_in_tray"] negative:NO],
        [WAGRWAABCategorySpec title:@"Privacy / Username" subtitle:@"Defense mode, passkeys, username, interop, relay calls, link preview, LID privacy." tokens:@[@"privacy",@"username",@"passkey",@"defense",@"interop",@"lid",@"relay"] exact:@[@"defense_mode_available",@"passkey_login",@"multiple_passkeys_delete_v2_enabled",@"username_suggestions_enabled",@"username_key_redesign_enabled",@"username_enabled_on_companion",@"allow_lid_contacts_privacy_settings",@"allow_lid_contacts_calling",@"allow_lid_contacts_status",@"privacy_setting_relay_all_calls",@"interop_client_ux_enabled",@"interop_group_messaging_enabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"Business / SMB" subtitle:@"Business, SMB, catalog, agents, ads/premium business flags." tokens:@[@"business",@"biz",@"smb",@"catalog",@"wamo",@"agent"] exact:@[@"smbi_premium_broadcast_enabled",@"smbi_subscription_content_models_enabled",@"smb_custom_url_display_v2_enabled",@"smb_verified_badge_parity_changes_enabled",@"biz_ai_smb_agents_entrypoint_enabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"Payments" subtitle:@"Payments, UPI, cards, merchant and payment settings." tokens:@[@"payment",@"payments",@"upi",@"pix",@"card",@"merchant"] exact:@[@"payments_selection_ui_updates_enabled",@"isPaymentP2PEnabled"] negative:NO],
        [WAGRWAABCategorySpec title:@"Liquid Glass" subtitle:@"All current ios_liquid_glass_* flags from the new framework." tokens:@[@"liquid_glass"] exact:@[@"ios_liquid_glass_enabled",@"ios_liquid_glass_launched",@"ios_liquid_glass_m1",@"ios_liquid_glass_m_1_5",@"ios_liquid_glass_m_2_action_tile",@"ios_liquid_glass_m_2_chips",@"ios_liquid_glass_m_2_lightweight_dialogs",@"ios_liquid_glass_m_2_text_layout",@"ios_liquid_glass_chat_top_bar_m2_enabled",@"ios_liquid_glass_enable_new_chatbar_ux",@"ios_liquid_glass_larger_composer"] negative:NO],
        [WAGRWAABCategorySpec title:@"Negative Gates / Killswitches" subtitle:@"Semântica invertida: ON no menu significa permitir/release, gravando OFF nos killswitch/disabled/block gates." tokens:@[@"killswitch",@"kill_switch",@"disabled",@"disable_",@"block",@"deny",@"hide_"] exact:@[@"aura_kill_switch",@"aura_premium_stickers_killswitch"] negative:YES]
    ];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor=WAGRWAABBG();
    self.specs=[[self class] categorySpecs];
    self.runtimeFlags=[WAGRABFlagBrowserVC runtimeFlags];
    [self rebuild];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
}
- (void)refresh { self.runtimeFlags=[WAGRABFlagBrowserVC runtimeFlags]; [self rebuild]; [self.tableView reloadData]; }
- (void)rebuild {
    NSMutableDictionary *d=[NSMutableDictionary dictionary];
    NSSet *runtimeSet=[NSSet setWithArray:self.runtimeFlags?:@[]];
    for (WAGRWAABCategorySpec *spec in self.specs) {
        NSMutableArray *flags=[NSMutableArray array];
        for (NSString *f in self.runtimeFlags) {
            if (WAGRContainsAnyToken(f, spec.tokens)) [flags addObject:f];
        }
        for (NSString *f in spec.exact) {
            // Include exact gates even if they are not in WAABProperties; it makes missing framework changes visible.
            if ([runtimeSet containsObject:f] || f.length) [flags addObject:f];
        }
        d[spec.title]=WAGRUniqueSorted(flags);
    }
    self.flagsByTitle=d;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.specs.count; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 62.0; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:@"cat"];
    if (!c) c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cat"];
    WAGRWAABCategorySpec *spec=self.specs[(NSUInteger)ip.row];
    NSArray *flags=self.flagsByTitle[spec.title]?:@[];
    NSUInteger applied=0;
    NSString *target=spec.negativeMode?@"off":@"on";
    for (NSString *f in flags) if ([WAGRWAABState(f) isEqualToString:target]) applied++;
    c.backgroundColor=WAGRWAABCellBG();
    c.textLabel.text=spec.title;
    c.textLabel.textColor=UIColor.labelColor;
    c.detailTextLabel.text=[NSString stringWithFormat:@"%lu flags · %lu aplicados", (unsigned long)flags.count, (unsigned long)applied];
    c.detailTextLabel.textColor=applied?WAGRWAABGreen():WAGRWAABSecondary();
    c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGRWAABCategorySpec *spec=self.specs[(NSUInteger)ip.row];
    NSArray *flags=self.flagsByTitle[spec.title]?:@[];
    WAGRWAABCategoryBundleVC *vc=[[WAGRWAABCategoryBundleVC alloc] initWithSpec:spec flags:flags];
    [self.navigationController pushViewController:vc animated:YES];
}
@end
