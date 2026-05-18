// WAGramMenuVC.m — WAGram v10
// UI: Ryukgram-style (UIListContentConfiguration + SF Symbol rounded-square icons)
// Storage: wagr.waab.<flag> = @"on" / @"off" / absent  (AGENTS.md §4.2)
// Hook: WAGRBundleEnsureHooksInstalled + WAGRWAABEnsureHooksInstalled after every write.
// No .mode storage. No extern C in this .m.

#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import "WAGramMenuVC.h"
#import "WAGRRuntimeMethodBrowserVC.h"
#import "WAGramWAABRuntimeCategoriesVC.h"
#import "../WAGramPrefix.h"
#import "../WAUtils.h"

// ── Ryukgram-style icon helper ────────────────────────────────────────────────
static UIImage *WAGRIconImage(NSString *sfSymbol, CGFloat ptSize) {
    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:ptSize
                                                        weight:UIImageSymbolWeightMedium];
    return [UIImage systemImageNamed:sfSymbol withConfiguration:cfg];
}

// Rounded-square icon view (32×32, corner radius 7) — Ryukgram visual style
static UIView *WAGRIconBox(NSString *sfSymbol, UIColor *bgColor) {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0,0,32,32)];
    box.backgroundColor = bgColor;
    box.layer.cornerRadius = 7;
    box.layer.masksToBounds = YES;
    UIImageView *iv = [[UIImageView alloc]
        initWithImage:WAGRIconImage(sfSymbol, 15)];
    iv.tintColor = UIColor.whiteColor;
    iv.contentMode = UIViewContentModeCenter;
    iv.frame = CGRectMake(0,0,32,32);
    [box addSubview:iv];
    return box;
}

// Build cell using UIListContentConfiguration (Ryukgram pattern)
static UITableViewCell *WAGRCell(NSString *title, NSString *sub,
                                  NSString *sfSymbol, UIColor *iconBG,
                                  UITableViewCellAccessoryType acc) {
    UITableViewCell *c = [[UITableViewCell alloc]
        initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (@available(iOS 14,*)) {
        UIListContentConfiguration *cfg = c.defaultContentConfiguration;
        cfg.text = title;
        cfg.textProperties.font = [UIFont systemFontOfSize:16];
        if (sub.length) {
            cfg.secondaryText = sub;
            cfg.secondaryTextProperties.font = [UIFont systemFontOfSize:12];
            cfg.secondaryTextProperties.color = UIColor.secondaryLabelColor;
            cfg.textToSecondaryTextVerticalPadding = 2;
        }
        cfg.image = WAGRIconImage(sfSymbol ?: @"slider.horizontal.3", 15);
        cfg.imageProperties.tintColor = UIColor.whiteColor;
        cfg.imageProperties.maximumSize = CGSizeMake(32,32);
        cfg.imageToTextPadding = 12;
        c.contentConfiguration = cfg;
        // Background icon box as imageView background workaround
        [c.imageView setImage:WAGRIconImage(sfSymbol ?: @"slider.horizontal.3", 15)];
        c.imageView.backgroundColor = iconBG;
        c.imageView.layer.cornerRadius = 7;
        c.imageView.layer.masksToBounds = YES;
        c.imageView.tintColor = UIColor.whiteColor;
        c.imageView.frame = CGRectMake(0,0,32,32);
        c.imageView.contentMode = UIViewContentModeCenter;
        c.textLabel.text = title;
        c.detailTextLabel.text = sub;
    } else {
        c.textLabel.text = title;
        c.detailTextLabel.text = sub;
        UIView *icon = WAGRIconBox(sfSymbol ?: @"slider.horizontal.3", iconBG);
        c.imageView.image = [UIImage new];
        [c.contentView insertSubview:icon atIndex:0];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [icon.leadingAnchor constraintEqualToAnchor:c.contentView.leadingAnchor constant:15],
            [icon.centerYAnchor constraintEqualToAnchor:c.contentView.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:32],
            [icon.heightAnchor constraintEqualToConstant:32],
        ]];
    }
    c.accessoryType = acc;
    return c;
}

// Semantic colours
static UIColor *WAGRC(uint32_t rgb) {
    return [UIColor colorWithRed:((rgb>>16)&0xFF)/255.0
                          green:((rgb>>8)&0xFF)/255.0
                           blue:(rgb&0xFF)/255.0 alpha:1];
}
#define CLUE   WAGRC(0x3B82F6) // blue
#define CGREEN WAGRC(0x22C55E) // green
#define CORA   WAGRC(0xF97316) // orange
#define CRED   WAGRC(0xEF4444) // red
#define CPURP  WAGRC(0x8B5CF6) // purple
#define CTEAL  WAGRC(0x14B8A6) // teal
#define CGRAY  WAGRC(0x6B7280) // gray

// TopVC helper
static UIViewController *WAGRTopVC(void) {
    UIViewController *c = nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if (![sc isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene*)sc).windows)
            if (w.isKeyWindow) { c = w.rootViewController; break; }
        if (c) break;
    }
    UIViewController *p=nil;
    while(c!=p){p=c;
        if(c.presentedViewController){c=c.presentedViewController;continue;}
        if([c isKindOfClass:UINavigationController.class]){UIViewController*v=((UINavigationController*)c).visibleViewController;if(v&&v!=c){c=v;continue;}}
        if([c isKindOfClass:UITabBarController.class]){UIViewController*v=((UITabBarController*)c).selectedViewController;if(v&&v!=c){c=v;continue;}}
        break;}
    return c;
}
static void WAGRAlert(NSString *t, NSString *m) {
    dispatch_async(dispatch_get_main_queue(),^{
        UIAlertController *a=[UIAlertController alertControllerWithTitle:t message:m
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault
            handler:^(id _){UIPasteboard.generalPasteboard.string=m?:@"";}]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [WAGRTopVC() presentViewController:a animated:YES completion:nil];
    });
}

// Safe apply policy: toggles only write preferences by default. Heavy hooks are
// installed at launch only when explicitly enabled, or from diagnostic actions.
static BOOL WAGRImmediateHookApplyEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"wagr_immediate_apply_hooks_enabled"];
}

static NSUInteger WAGRNuclearResetAllUserDefaults(void) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSDictionary *before = [ud dictionaryRepresentation] ?: @{};
    NSUInteger removed = before.count;

    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (bundleID.length) [ud removePersistentDomainForName:bundleID];

    // Belt-and-suspenders pass: clear any residual key visible through the
    // standard defaults stack, including older bad storage shapes from prior
    // tweak builds. This intentionally does not filter by prefix.
    for (NSString *key in before.allKeys) [ud removeObjectForKey:key];

    [ud synchronize];
    if (bundleID.length) CFPreferencesAppSynchronize((__bridge CFStringRef)bundleID);
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
    return removed;
}

// Write WAAB flag. Do not install heavy hooks synchronously by default.
// This keeps the menu usable even when stale NSUserDefaults from older builds
// contain incompatible values. Restart/apply explicitly after a clean reset.
static void WAGRApplyFlagOn(NSString *flag) {
    WAGRSet(flag, @"on");
    if (!WAGRImmediateHookApplyEnabled()) return;
    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
    if ([flag containsString:@"liquid_glass"]) WAGRLGPrefsDidChange();
    if ([flag hasPrefix:@"aura_"]||[flag containsString:@"benefit"]||[flag containsString:@"subscri"])
        WAGRAuraEnsureHooksInstalled();
    if ([flag containsString:@"dogfood"]||[flag containsString:@"internal"]||[flag containsString:@"employee"])
        WAGRDogfoodEnsureHooksInstalled();
}
static void WAGRApplyFlagOff(NSString *flag) {
    WAGRSet(flag, @"off");
    if (!WAGRImmediateHookApplyEnabled()) return;
    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
}
static void WAGRApplyFlagSystem(NSString *flag) {
    WAGRSet(flag, nil);
    if (!WAGRImmediateHookApplyEnabled()) return;
    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
}

// ─────────────────────────────────────────────────────────────────────────────
// WAGRABFlagBrowserVC — simple flag browser (AGENTS.md §14 interface contract)
// ─────────────────────────────────────────────────────────────────────────────
static char kWAGRSwKey;

@interface WAGRABFlagBrowserVC () <UISearchResultsUpdating>
@property (nonatomic,strong) NSMutableArray<NSString*> *mutableFlags;
@property (nonatomic,strong) NSArray<NSString*> *filtered;
@property (nonatomic,strong) UISearchController *search;
@end

@implementation WAGRABFlagBrowserVC
@synthesize allFlags=_allFlags;

- (instancetype)initWithTitle:(NSString*)t flags:(NSArray<NSString*>*)flags {
    if (!(self=[super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = t;
    _mutableFlags = flags ? [NSMutableArray arrayWithArray:
        [flags sortedArrayUsingSelector:@selector(compare:)]] : [NSMutableArray array];
    _allFlags = _mutableFlags.copy;
    _filtered = _allFlags;
    return self;
}

+ (NSArray<NSString*>*)runtimeFlags {
    Class cls = NSClassFromString(@"WAABProperties");
    if (!cls) return @[];
    NSMutableArray *out = [NSMutableArray array];
    unsigned int n=0; Method *ms = class_copyMethodList(cls,&n);
    for (unsigned int i=0;i<n;i++) {
        if (method_getNumberOfArguments(ms[i])!=2) continue;
        char ret[8]={0}; method_getReturnType(ms[i],ret,8);
        if (ret[0]!='B'&&ret[0]!='c') continue;
        NSString *nm=NSStringFromSelector(method_getName(ms[i]));
        if ([nm containsString:@":"]) continue;
        [out addObject:nm];
    }
    free(ms);
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = 52;
    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Buscar flag…";
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    UIBarButtonItem *resetBtn = [[UIBarButtonItem alloc]
        initWithTitle:@"Reset" style:UIBarButtonItemStylePlain
               target:self action:@selector(resetFiltered)];
    resetBtn.tintColor = UIColor.systemRedColor;
    self.navigationItem.rightBarButtonItem = resetBtn;
    if (_mutableFlags.count == 0) [self loadRuntime];
    [self updateBadge];
}

- (void)loadRuntime {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{
        NSArray *flags = [[self class] runtimeFlags];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_mutableFlags = [NSMutableArray arrayWithArray:flags];
            self->_allFlags = flags;
            self->_filtered = flags;
            [self.tableView reloadData];
            [self updateBadge];
        });
    });
}

- (void)updateBadge {
    NSUInteger on=0;
    for (NSString *f in _allFlags) if (WAGRIsOn(f)) on++;
    self.title = on>0 ? [NSString stringWithFormat:@"%@ (%lu✓)", self.navigationItem.backButtonTitle ?: @"Flags", (unsigned long)on] : (self.navigationItem.backButtonTitle ?: @"Flags");
}
- (void)reload { [self updateSearchResultsForSearchController:_search]; }
- (void)resetFiltered {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reset flags visíveis?"
        message:[NSString stringWithFormat:@"%lu flags visíveis voltarão para sistema.", (unsigned long)_filtered.count]
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(id _){
        for (NSString *f in self->_filtered) WAGRApplyFlagSystem(f);
        [self.tableView reloadData]; [self updateBadge];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Reset TOTAL NSUserDefaults" style:UIAlertActionStyleDestructive handler:^(id _){
        [self confirmNuclearReset];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = sc.searchBar.text;
    _filtered = q.length ? [_allFlags filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"SELF contains[c] %@",q]] : _allFlags;
    [self.tableView reloadData]; [self updateBadge];
}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)_filtered.count; }
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:@"f"];
    if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"f"];
    NSString *flag=_filtered[(NSUInteger)ip.row];
    BOOL on=WAGRIsOn(flag); BOOL off=WAGRIsOff(flag);
    c.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    c.textLabel.text=flag; c.textLabel.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    c.textLabel.numberOfLines=2;
    c.textLabel.textColor=on?CGREEN:off?CRED:UIColor.labelColor;
    c.detailTextLabel.text=on?@"✓ ON":off?@"✕ OFF":@"system";
    c.detailTextLabel.textColor=on?CGREEN:off?CRED:UIColor.secondaryLabelColor;
    c.selectionStyle=UITableViewCellSelectionStyleNone;
    UISwitch *sw=(UISwitch*)objc_getAssociatedObject(c,&kWAGRSwKey);
    if (!sw){sw=[[UISwitch alloc]init];sw.onTintColor=CLUE;[sw addTarget:self action:@selector(tog:) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(c,&kWAGRSwKey,sw,OBJC_ASSOCIATION_RETAIN_NONATOMIC);c.accessoryView=sw;}
    sw.on=on; sw.tag=ip.row; return c;
}
- (void)tog:(UISwitch*)sw {
    NSString *flag=_filtered[(NSUInteger)sw.tag];
    if (sw.isOn) WAGRApplyFlagOn(flag); else WAGRApplyFlagSystem(flag);
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:sw.tag inSection:0]]
        withRowAnimation:UITableViewRowAnimationNone];
    [self updateBadge];
}
@end

// ─────────────────────────────────────────────────────────────────────────────
// WAGRWAABTriStateBrowserVC (AGENTS.md §14 interface contract)
// ─────────────────────────────────────────────────────────────────────────────
static char kWAGRSegKey;
@interface WAGRWAABTriStateBrowserVC ()
@property (nonatomic,strong) NSArray<NSString*> *allFlags, *filtered;
@property (nonatomic,strong) UISearchController *search;
@end
@implementation WAGRWAABTriStateBrowserVC
- (instancetype)initWithTitle:(NSString*)t flags:(NSArray<NSString*>*)flags negativeMode:(BOOL)neg {
    if (!(self=[super initWithStyle:UITableViewStylePlain])) return nil;
    self.title=t; _negativeMode=neg;
    _allFlags=[[[NSSet setWithArray:flags?:@[]].allObjects sortedArrayUsingSelector:@selector(compare:)] copy];
    _filtered=_allFlags; return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor; self.tableView.rowHeight=62;
    _search=[[UISearchController alloc]initWithSearchResultsController:nil]; _search.searchResultsUpdater=self; _search.obscuresBackgroundDuringPresentation=NO; _search.searchBar.placeholder=@"Buscar flag…"; self.navigationItem.searchController=_search; self.navigationItem.hidesSearchBarWhenScrolling=NO; [self updateTitle];}
- (void)updateTitle {
    NSUInteger on=0,off=0; for (NSString*f in _allFlags){if(WAGRIsOn(f))on++;else if(WAGRIsOff(f))off++;}
    self.navigationItem.title=[NSString stringWithFormat:@"%@ (%lu on / %lu off)",self.title,(unsigned long)on,(unsigned long)off];}
- (void)updateSearchResultsForSearchController:(UISearchController*)sc {
    NSString*q=sc.searchBar.text;
    _filtered=q.length?[_allFlags filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@",q]]:_allFlags;
    [self.tableView reloadData];}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return(NSInteger)_filtered.count;}
- (CGFloat)tableView:(UITableView*)tv heightForRowAtIndexPath:(NSIndexPath*)ip{return 62;}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    UITableViewCell*c=[tv dequeueReusableCellWithIdentifier:@"tri"];
    if(!c)c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tri"];
    NSString*flag=_filtered[(NSUInteger)ip.row]; BOOL neg=(WAGRIsNegativeGate(flag)||_negativeMode);
    NSString*state=WAGRStoredFlagState(flag);
    c.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    c.textLabel.text=flag; c.textLabel.font=[UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular]; c.textLabel.numberOfLines=2;
    if([state isEqualToString:@"on"])c.textLabel.textColor=neg?CORA:CGREEN;
    else if([state isEqualToString:@"off"])c.textLabel.textColor=neg?CGREEN:CORA;
    else c.textLabel.textColor=UIColor.labelColor;
    c.detailTextLabel.text=neg?@"negative gate: ON blocks, OFF allows":@"System / OFF / ON";
    c.detailTextLabel.textColor=UIColor.secondaryLabelColor; c.selectionStyle=UITableViewCellSelectionStyleNone;
    UISegmentedControl*seg=[[UISegmentedControl alloc]initWithItems:@[@"System",@"Off",@"On"]];
    seg.selectedSegmentIndex=[state isEqualToString:@"off"]?1:[state isEqualToString:@"on"]?2:0;
    objc_setAssociatedObject(seg,&kWAGRSegKey,flag,OBJC_ASSOCIATION_COPY_NONATOMIC);
    [seg addTarget:self action:@selector(segChanged:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView=seg; return c;}
- (void)segChanged:(UISegmentedControl*)seg {
    NSString*flag=objc_getAssociatedObject(seg,&kWAGRSegKey);
    if(seg.selectedSegmentIndex==2)WAGRApplyFlagOn(flag);
    else if(seg.selectedSegmentIndex==1)WAGRApplyFlagOff(flag);
    else WAGRApplyFlagSystem(flag);
    [self updateTitle]; [self.tableView reloadData];}
@end

// ─────────────────────────────────────────────────────────────────────────────
// WAGramBundleVC — master toggle + individual browser
// ─────────────────────────────────────────────────────────────────────────────
@interface WAGramBundleVC ()
@property (nonatomic,strong) NSArray<NSString*> *flags, *negFlags;
@property (nonatomic,copy) NSString *icon, *bundleDesc;
@property (nonatomic,strong) UIColor *iconColor;
@property (nonatomic,strong) WAGRWAABTriStateBrowserVC *browser;
@end
@implementation WAGramBundleVC
- (instancetype)initWithTitle:(NSString*)t flags:(NSArray<NSString*>*)flags negFlags:(NSArray<NSString*>*)negs
                         icon:(NSString*)icon iconColor:(UIColor*)clr desc:(NSString*)desc {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title=t; _flags=flags?:@[]; _negFlags=negs?:@[];
    _icon=icon?:@"slider.horizontal.3"; _iconColor=clr?:CLUE; _bundleDesc=desc;
    _browser=[[WAGRWAABTriStateBrowserVC alloc]initWithTitle:t flags:_flags negativeMode:NO];
    _browser.navigationItem.backButtonTitle=t;
    return self;
}
- (NSUInteger)onCount{NSUInteger n=0;for(NSString*f in _flags)if(WAGRIsOn(f))n++;return n;}
- (void)viewDidLoad{[super viewDidLoad];self.tableView.backgroundColor=UIColor.systemGroupedBackgroundColor;}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return 3;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return 1;}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s{
    return s==0?[NSString stringWithFormat:@"%@\n\nUsa wagr.waab.<flag> = \"on\"/\"off\"/absent. Reiniciar após ativar.",_bundleDesc?:@""]:nil;}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip{
    if(ip.section==0){
        NSUInteger on=[self onCount];
        UITableViewCell*c=WAGRCell([NSString stringWithFormat:@"Ativar tudo (%lu/%lu)",(unsigned long)on,(unsigned long)_flags.count],
            on>0?[NSString stringWithFormat:@"%lu flags ativos",(unsigned long)on]:@"Todos no sistema",
            _icon,_iconColor,UITableViewCellAccessoryNone);
        c.selectionStyle=UITableViewCellSelectionStyleNone;
        UISwitch*sw=[[UISwitch alloc]init];sw.on=(on==_flags.count&&_flags.count>0);sw.onTintColor=CLUE;
        [sw addTarget:self action:@selector(masterToggle:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView=sw; return c;
    }
    if(ip.section==1) return WAGRCell(@"Flags individuais",[NSString stringWithFormat:@"%lu/%lu",(unsigned long)[self onCount],(unsigned long)_flags.count],@"slider.horizontal.3",CGRAY,UITableViewCellAccessoryDisclosureIndicator);
    return WAGRCell(@"Diagnóstico WAAB",@"Ver estado dos hooks",@"stethoscope",CTEAL,UITableViewCellAccessoryNone);
}
- (void)masterToggle:(UISwitch*)sw{
    if(sw.isOn){for(NSString*f in _flags)WAGRApplyFlagOn(f);for(NSString*f in _negFlags)WAGRApplyFlagOff(f);}
    else{for(NSString*f in _flags)WAGRApplyFlagSystem(f);for(NSString*f in _negFlags)WAGRApplyFlagSystem(f);}
    [self.tableView reloadData];
}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip{
    [tv deselectRowAtIndexPath:ip animated:YES];
    if(ip.section==1)[self.navigationController pushViewController:_browser animated:YES];
    if(ip.section==2)WAGRAlert(@"WAAB",WAGRWAABDiagnosticText());
}
@end

// ─────────────────────────────────────────────────────────────────────────────
// Bundle definitions (confirmed binary analysis — SM + WA 2.22.x)
// ─────────────────────────────────────────────────────────────────────────────
static WAGramBundleVC *WAGRLGBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Liquid Glass" flags:@[
        @"ios_liquid_glass_enabled",@"ios_liquid_glass_launched",@"ios_liquid_glass_m1",
        @"ios_liquid_glass_m_1_5",@"ios_liquid_glass_m_1_5_context_menu",
        @"ios_liquid_glass_m_2_action_tile",@"ios_liquid_glass_m_2_chips",
        @"ios_liquid_glass_m_2_lightweight_dialogs",@"ios_liquid_glass_m_2_text_layout",
        @"ios_liquid_glass_media_m0",@"ios_liquid_glass_media_editor_enabled",
        @"ios_liquid_glass_larger_composer",@"ios_liquid_glass_chat_top_bar_m2_enabled",
        @"ios_liquid_glass_enable_new_chatbar_ux",@"ios_liquid_glass_chatbar_lower_bottom_padding",
        @"ios_liquid_glass_reduce_transparency",@"ios_liquid_glass_fixes_for_older_ios",
        @"ios_liquid_glass_fix_voip_mutex_priority_inversion",
        @"ios_liquid_glass_fix_status_dismiss_when_locked",
        @"ios_liquid_glass_fix_context_menu_on_disappear",
        @"ios_liquid_glass_fix_context_menu_transition_safety",
        @"ios_liquid_glass_fix_feedback_generator_retain",
        @"ios_liquid_glass_fix_forward_picker_share_extension_crash",
        @"ios_liquid_glass_fix_multisend_preview_dealloc",
        @"ios_liquid_glass_fix_tabbar_badge_offthread",
        @"ios_liquid_glass_fix_uiimage_trait_collection",
        @"ios_liquid_glass_fix_updates_table_dynamic_color",
        @"ios_liquid_glass_fix_weak_hashtable_snapshot",
        @"ios_liquid_glass_workaround_attachment_tray",
        @"ios_liquid_glass_workaround_hides_bottombar",
        @"ios_liquid_glass_workaround_topbar_appearance",
        @"ios_liquid_glass_calling_improvement_enabled",
        @"ios_liquid_glass_ptt_oot",
        @"status_viewer_redesign_enabled",
    ] negFlags:@[] icon:@"drop.fill" iconColor:CLUE desc:@"34 flags LiquidGlass + WDSLiquidGlass Logos hooks."];
}

// WA Plus / Aura — WAABProperties flags + GatedBenefitProvider (Swift WAAuraGating)
static WAGramBundleVC *WAGRAuraBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"WA Plus / Aura" flags:@[
        @"aura_enabled",@"aura_settings_row_enabled",@"aura_subscription_simulation_enabled",
        @"aura_logging_enabled",
        @"aura_app_icon_enabled",@"aura_app_icon_benefit_active",@"aura_app_icon_multi_account_support",
        @"aura_app_themes_enabled",@"aura_app_themes_benefit_active",
        @"aura_app_themes_chat_checkmark_themed_enabled",@"aura_app_themes_new_selection_flow_enabled",
        @"aura_app_themes_status_ring_enabled",@"aura_app_themes_illustration_lottie_enabled",
        @"aura_apple_watch_app_theme_enabled",@"aura_apple_watch_app_themes_enabled",
        @"aura_pinned_chats_enabled",@"aura_pinned_chats_benefit_active",
        @"aura_pinned_chats_targeted_nux_force",
        @"aura_enhanced_lists_enabled",@"aura_enhanced_lists_benefit_active",
        @"aura_ringtones_enabled",@"aura_ringtones_benefit_active",@"aura_ringtones_per_chat_enabled",
        @"aura_stickers_enabled",@"aura_stickers_benefit_active",
        @"aura_stickers_overlay_animation_enabled",@"aura_painted_door_stickers_enabled",
        @"aura_media_offload_enabled",@"aura_vault_backups_enabled",@"aura_vault_backups_benefit_active",
        @"ai_subscription_enabled",@"ai_subscription_imagine_intent_enabled",
        @"isEligibleForSubscriptions",@"isExpandedFormattingPlusEnabled",
        @"isAppIconsBenefitActive",@"isAppThemesBenefitActive",
        @"isEnhancedListsBenefitActive",@"isExtendedPinnedChatBenefitActive",
        @"isRingtonesBenefitActive",@"isStickersBenefitActive",
        @"wa_subscriptions_entry_point_settings_enabled",@"wa_subscriptions_settings_green_dot_enabled",
    ] negFlags:@[@"aura_kill_switch",@"aura_premium_stickers_killswitch"]
          icon:@"star.fill" iconColor:CORA
          desc:@"WAABProperties aura_* flags + GatedBenefitProvider (Swift WAAuraGating module).\n\nO WA Plus usa:\n1. WAABProperties flags (acima) como AB gates\n2. GatedBenefitProvider / GatedSubscriptionProvider como subscription gates\n3. StoreKit IAP para validação de pagamento\n\nAtivando estes flags → Settings mostra 'Subscriptions'. Tap → UI nativa do WA Plus."];
}

static WAGramBundleVC *WAGRPrivacyBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Privacy & Username" flags:@[
        @"defense_mode_available",@"passkey_login",@"multiple_passkeys_delete_v2_enabled",
        @"username_suggestions_enabled",@"username_key_redesign_enabled",
        @"username_enabled_on_companion",@"username_call_search_enabled",
        @"username_group_mutation_enabled",@"username_group_learning_enabled",
        @"allow_lid_contacts_privacy_settings",@"allow_lid_contacts_calling",
        @"allow_lid_contacts_status",@"allow_lid_contacts_broadcast",
        @"enable_calling_phone_number_privacy",@"enable_calling_username",
        @"ios_wabi_enable_username_migration",@"privacy_checkup",
        @"interop_client_ux_enabled",@"interop_contact_master_enabled",
        @"interop_group_messaging_enabled",@"interop_bootstrap_enabled",
        @"wa_interop_unified_inbox_enabled",@"is_interop_available_badge_banner_enabled",
        @"high_quality_link_preview_enabled",@"privacy_setting_relay_all_calls",
    ] negFlags:@[] icon:@"lock.shield.fill" iconColor:CGREEN
          desc:@"Defense Mode, Passkey, Username, Interop, Privacy settings, Link Preview."];
}

static WAGramBundleVC *WAGRSettingsRowsBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Settings Rows" flags:@[
        @"lists_feature_enabled",@"lists_sync_enabled",@"events_global_list",
        @"call_favorites_enabled_companions",
        @"waffle_mobile_companions_enabled",@"waffle_enabled_for_unlinked_users",
        @"waffle_foa_to_wa_linking_enabled",@"isPAAEligibleForWaffle",
        @"isPaymentP2PEnabled",
        @"foa_threads_bookmarks_enabled",@"foa_bookmark_sk_overlay_enabled",
        @"foa_bridges_bookmark_meta_horizon",@"foa_bridges_bookmarks_design_update_enabled",
        @"ai_rich_response_vibes_promotion_enabled",@"ai_rich_response_c50_promotion_enabled",
        @"sections_in_help_menu",@"premium_blue_enabled",@"ios_contacts_surface_is_enabled",
        @"ios_me_tab_new_user_checklist_enabled",@"ios_me_tab_share_updates_enabled",
        @"me_tab_settings_header_enabled",@"xfam_lg_switcher_m2_me_tab_enabled",
        @"wa_subscriptions_entry_point_settings_enabled",
        @"wa_subscriptions_settings_green_dot_enabled",
        @"verified_badge_in_chats_list_enabled",
        @"sg_ios_multi_account_enabled",@"wa_xfam_ios_switcher_multiaccount_enabled",
        @"foa_bridges_account_switcher_ios_enabled",@"deletion_reason_multi_account_enabled",
    ] negFlags:@[] icon:@"rectangle.grid.2x2.fill" iconColor:CPURP
          desc:@"Células ocultas em Settings:\nSettingsView_ListCell, FavoritesCell, EventsCell, WAFFLECell, SubscriptionsCell, DeveloperCell, DogfoodingNudge, ThreadsBookmark, FBBookmark, IGBookmark, MetaAIBookmark, VibesBookmark, HelpMenu sections, Multi-account, Me Tab."];
}

static WAGramBundleVC *WAGRAIBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"AI & Meta AI" flags:@[
        @"ai_meta_ai_in_app_tab_main_gate_enabled",@"ai_home_in_tab_main_gate_enabled",
        @"ai_home_redesign_enabled",@"ai_dynamic_mode_selector_enabled",
        @"ai_tab_glyph_icon_enabled",@"ai_tab_perf_optimizations_enabled",
        @"ai_hatch_integration_tab_enabled",@"ai_hatch_integration_enabled",
        @"ai_hatch_commands_enabled",
        @"ai_incognito_mode_enabled",@"ai_incognito_mode_disappearing_messages_enabled",
        @"ai_incognito_mode_personalization_enabled",@"ai_incognito_media_input_enabled",
        @"ai_side_chat_enabled",@"ai_side_chat_summarization_enabled",
        @"ai_side_chat_writing_help_enabled",@"ai_side_chat_image_creation_enabled",
        @"ai_side_chat_media_input_enabled",@"ai_side_chat_search_starter_enabled",
        @"ai_chat_threads_enabled",@"ai_chat_threads_infra_enabled",
        @"ai_chat_thread_capability_enabled",@"ai_chat_threads_multiplayer_enabled",
        @"ai_chat_threads_pin_enabled",@"ai_chat_threads_side_sheet_enabled",
        @"ai_chat_threads_search_enabled",@"ai_chat_threads_shy_header_enabled",
        @"ai_chat_threads_fuzzy_search_enabled",
        @"ai_rewrite_in_context_menu_enabled",@"ai_rewrite_in_edit_message_enabled",
        @"ai_translate_messages_enabled",
        @"ai_voice_image_input_enabled",@"ai_voice_live_video_input_enabled",
        @"ai_voice_ptt_coexistence_enabled",@"ai_voice_live_video_pip_enabled",
        @"ai_llama_premium_model_main_gate_enabled",
        @"ai_bot_imagine_me_enabled",@"ai_imagine_bottom_sheet_enabled",
        @"ai_group_participation_enabled",@"ai_group_participation_send_enabled",
    ] negFlags:@[] icon:@"sparkles" iconColor:CPURP
          desc:@"Meta AI Tab, Incognito AI, Side Chat, AI Threads (3 flags!), Rewrite, Translate, Voice, Hatch, LLaMA."];
}

static WAGramBundleVC *WAGRDogfoodBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Developer / Dogfood / Internal" flags:@[
        @"mobile_config_debug_internal",@"dogfooder_diagnostics",
        @"ios_internal_hall_enabled",@"is_internal_tester",
        @"isMetaEmployeeOrInternalTester",@"is_meta_employee_or_internal_tester",
        @"isInternalUser",@"is_internal",
        @"map_pages_internal",@"md_internal_app_log",@"md_syncd_dogfooding_feature",
        @"username_dogfooding_pn_privacy_enabled",
        @"visible_message_drop_placeholder_enabled_internal_only",
        @"sections_in_help_menu",@"enableEphemeralMessagesDebugOptions",
    ] negFlags:@[@"graphQLEmployeeC1Disabled"]
          icon:@"ant.fill" iconColor:CRED
          desc:@"Debug/Internal flags via WAABProperties. graphQLEmployeeC1Disabled forçado OFF = libera C1."];
}

// ─────────────────────────────────────────────────────────────────────────────
// WAGramMenuVC — root (Ryukgram visual style)
// ─────────────────────────────────────────────────────────────────────────────
static char kBundleAssoc;
static char kSwAssoc;

@implementation WAGramMenuVC {
    // Section/row structure (fixed, not data-driven to keep AGENTS.md §4 intact)
    NSArray<WAGramBundleVC*> *_bundles;
}

- (instancetype)init {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WAGram";
    _bundles = @[WAGRLGBundle(), WAGRAuraBundle(), WAGRPrivacyBundle(),
                 WAGRSettingsRowsBundle(), WAGRAIBundle(), WAGRDogfoodBundle()];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Reset" style:UIBarButtonItemStylePlain target:self action:@selector(confirmNuclearReset)];
    self.navigationItem.leftBarButtonItem.tintColor = UIColor.systemRedColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
}
- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv { return 5; }
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s {
    switch(s) {
        case 0: return 5;           // Master switches
        case 1: return (NSInteger)_bundles.count; // Feature bundles
        case 2: return 3;           // Runtime browsers
        case 3: return 1;           // Backup/restore
        case 4: return 2;           // Actions
    }
    return 0;
}
- (NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)s {
    NSString *h[]={@"MASTERS",@"FEATURE BUNDLES",@"RUNTIME BROWSER",@"BACKUP & RESTORE",@"AÇÕES"};
    return h[s];
}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {
    if(s==0)return@"Toggles gravam NSUserDefaults. Hooks pesados não aplicam no toque por segurança; use reset total se veio de build antiga.";
    if(s==1)return@"wagr.waab.<flag> = \"on\"/\"off\"/absent. Mudanças são persistidas; reinicie para aplicar com segurança.";
    if(s==2)return@"Scan on-demand: nunca no startup. NativeSurface usa registry exato.";
    return nil;
}

// ── Section 0: Master switches ─────────────────────────────────────────────────
- (UITableViewCell*)masterCellForRow:(NSInteger)r {
    struct{const char*icon;uint32_t clr;const char*title;const char*sub;const char*key;}
    rows[]={
        {"drop.fill",         0x3B82F6,"Liquid Glass",      "WDSLiquidGlass + WAABProperties",WA_PREF_LIQUID_GLASS},
        {"person.badge.key",  0x8B5CF6,"Employee Mode",     "isMetaEmployee · isInternalUser",WA_PREF_EMPLOYEE_MASTER},
        {"eye.fill",          0x14B8A6,"WAAB Observer",      "Loga boolForKey calls",          WA_PREF_AB_OBSERVER},
        {"hammer.fill",       0xEF4444,"Debug Menu Nativo",  "isDebugMenuAllowed = YES",        "wagr_native_debug_menu_enabled"},
        {"ant.fill",          0x6366F1,"Debug Mode",         "Logs extras + dogfood helpers",  "wagr_debug_mode_enabled"},
    };
    NSString *key=@(rows[r].key);
    BOOL on=WAGRPref(key);
    UITableViewCell *c=WAGRCell(@(rows[r].title),@(rows[r].sub),@(rows[r].icon),WAGRC(rows[r].clr),UITableViewCellAccessoryNone);
    c.selectionStyle=UITableViewCellSelectionStyleNone;
    UISwitch *sw=(UISwitch*)objc_getAssociatedObject(c,&kSwAssoc);
    if(!sw){sw=[[UISwitch alloc]init];sw.onTintColor=CLUE;[sw addTarget:self action:@selector(masterToggle:) forControlEvents:UIControlEventValueChanged];objc_setAssociatedObject(c,&kSwAssoc,sw,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    sw.on=on; sw.tag=r; c.accessoryView=sw; return c;
}
- (void)masterToggle:(UISwitch*)sw {
    const char*keys[]={"wa_liquid_glass_enabled","wa_employee_master","wa_abprops_observer_enabled","wagr_native_debug_menu_enabled","wagr_debug_mode_enabled"};
    NSUserDefaults*ud=NSUserDefaults.standardUserDefaults;
    sw.isOn?[ud setBool:YES forKey:@(keys[sw.tag])]:[ud removeObjectForKey:@(keys[sw.tag])];
    [ud synchronize];
    if (WAGRImmediateHookApplyEnabled()) {
        switch(sw.tag){
            case 0: WAGRLGPrefsDidChange(); break;
            case 1: WAGRDogfoodEnsureHooksInstalled(); WAGRNativeSurfaceEnsureHooksInstalled(); break;
            case 2: WAGRWAABEnsureHooksInstalled(); break;
            case 3: case 4: WAGRDebugMenuEnsureHooksInstalled(); WAGRNativeSurfaceEnsureHooksInstalled(); break;
        }
    }
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:sw.tag inSection:0]]
        withRowAnimation:UITableViewRowAnimationNone];
}

// ── Section 1: Feature bundles ─────────────────────────────────────────────────
struct { const char *icon; uint32_t clr; } bundleStyle[] = {
    {"drop.fill",0x3B82F6},{"star.fill",0xF97316},{"lock.shield",0x22C55E},
    {"rectangle.grid.2x2",0x8B5CF6},{"sparkles",0x6366F1},{"ant.fill",0xEF4444}
};
- (UITableViewCell*)bundleCellForRow:(NSInteger)r {
    WAGramBundleVC *b=_bundles[(NSUInteger)r];
    NSUInteger on=[b onCount],total=b.flags.count;
    UITableViewCell *c=WAGRCell(b.title,
        on>0?[NSString stringWithFormat:@"%lu/%lu ativos",(unsigned long)on,(unsigned long)total]:@"Sistema",
        @(bundleStyle[r].icon),WAGRC(bundleStyle[r].clr),UITableViewCellAccessoryDisclosureIndicator);
    c.detailTextLabel.textColor=on>0?CGREEN:UIColor.secondaryLabelColor;
    objc_setAssociatedObject(c,&kBundleAssoc,b,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return c;
}

// ── Section 2: Runtime browsers ───────────────────────────────────────────────
- (UITableViewCell*)browserCellForRow:(NSInteger)r {
    struct{const char*t,*sub,*icon;uint32_t clr;}b[]={
        {"WAABProperties (~2000 flags)","Scan ao entrar — WAAB zero-arg + boolForKey","magnifyingglass",0x3B82F6},
        {"WAAB Categorias","13 categorias + negative gates","rectangle.3.group",0x8B5CF6},
        {"Runtime não-WAAB","MSHookMessageEx direto: Aura, debug, dogfood…","cpu",0xEF4444},
    };
    return WAGRCell(@(b[r].t),@(b[r].sub),@(b[r].icon),WAGRC(b[r].clr),UITableViewCellAccessoryDisclosureIndicator);
}

// ── Main cell dispatch ─────────────────────────────────────────────────────────
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    if(ip.section==0) return [self masterCellForRow:ip.row];
    if(ip.section==1) return [self bundleCellForRow:ip.row];
    if(ip.section==2) return [self browserCellForRow:ip.row];
    if(ip.section==3) return WAGRCell(@"Backup & Restore",@"Export JSON / Import / Reset completo",@"arrow.up.arrow.down.circle",CTEAL,UITableViewCellAccessoryDisclosureIndicator);
    // Section 4: Actions
    NSString*titles[]={@"Reiniciar WhatsApp",@"Reset TOTAL NSUserDefaults"};
    UIColor*clrs[]={CRED,CORA};
    UITableViewCell*c=WAGRCell(titles[ip.row],@"",@"power",clrs[ip.row],UITableViewCellAccessoryNone);
    c.textLabel.textAlignment=NSTextAlignmentCenter; return c;
}

- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    if(ip.section==1) {
        UITableViewCell *c=[tv cellForRowAtIndexPath:ip];
        WAGramBundleVC *b=(WAGramBundleVC*)objc_getAssociatedObject(c,&kBundleAssoc);
        if(b)[self.navigationController pushViewController:b animated:YES];
        return;
    }
    if(ip.section==2) {
        UIViewController *vc=nil;
        if(ip.row==0){WAGRABFlagBrowserVC*b=[[WAGRABFlagBrowserVC alloc]initWithTitle:@"Todos os Flags WAAB" flags:@[]];b.navigationItem.backButtonTitle=@"WAAB";vc=b;}
        if(ip.row==1){WAGramWAABRuntimeCategoriesVC*c=[[WAGramWAABRuntimeCategoriesVC alloc]init];vc=c;}
        if(ip.row==2){WAGRRuntimeMethodBrowserVC*c=[[WAGRRuntimeMethodBrowserVC alloc]initWithTitle:@"Runtime não-WAAB" tokens:@[@"aura",@"subscription",@"benefit",@"debug",@"internal",@"dogfood",@"employee",@"multiaccount",@"waffle",@"ai",@"plus",@"liquid",@"theme",@"icon",@"ringtone",@"sticker"]];vc=c;}
        if(vc)[self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if(ip.section==3) {
        [self presentRestoreMenu];
        return;
    }
    if(ip.section==4) {
        if(ip.row==0)[self confirmRestart:NO];
        else [self confirmNuclearReset];
    }
}

- (void)presentRestoreMenu {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Backup & Restore"
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    // Export
    [a addAction:[UIAlertAction actionWithTitle:@"Exportar configurações" style:UIAlertActionStyleDefault handler:^(id _){
        NSMutableDictionary *d=[NSMutableDictionary dictionary];
        NSDictionary *all=[[NSUserDefaults standardUserDefaults]dictionaryRepresentation];
        for(NSString*k in all) if([k hasPrefix:@"wagr."]) d[k]=all[k];
        NSData *json=[NSJSONSerialization dataWithJSONObject:@{@"wagrgram_export":@YES,@"version":@2,@"settings":d} options:NSJSONWritingPrettyPrinted error:nil];
        NSDateFormatter*fmt=[[NSDateFormatter alloc]init];fmt.dateFormat=@"yyyyMMdd-HHmmss";
        NSString*fname=[NSString stringWithFormat:@"wagrgram-%@.json",[fmt stringFromDate:NSDate.date]];
        NSURL*tmp=[[NSFileManager.defaultManager temporaryDirectory]URLByAppendingPathComponent:fname];
        [json writeToURL:tmp atomically:YES];
        UIActivityViewController*share=[[UIActivityViewController alloc]initWithActivityItems:@[tmp] applicationActivities:nil];
        [WAGRTopVC() presentViewController:share animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    if(UIDevice.currentDevice.userInterfaceIdiom==UIUserInterfaceIdiomPad)
        a.popoverPresentationController.sourceView=self.view;
    [self presentViewController:a animated:YES completion:nil];
}

- (void)confirmRestart:(BOOL)fullReset {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Reiniciar?"
        message:@"Fecha o WhatsApp para relaunch limpo. Use Reset TOTAL se veio de uma build antiga ou crashou ao ligar toggles."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Reiniciar" style:UIAlertActionStyleDestructive handler:^(id _){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),
            dispatch_get_main_queue(),^{exit(0);});
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)confirmNuclearReset {
    NSString *msg = @"Remove TODO o domínio NSUserDefaults do app, sem filtrar por prefixo. Isto limpa wagr.*, wa_*, aura_*, ios_*, valores antigos boolean/string/.mode e qualquer preferência do WhatsApp visível via NSUserDefaults. Não limpa Keychain, banco de dados, cache de servidor ou app group fora do standard defaults. O app fecha após limpar.";
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Reset TOTAL NSUserDefaults?"
        message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Limpar tudo e fechar" style:UIAlertActionStyleDestructive handler:^(id _){
        NSUInteger removed = WAGRNuclearResetAllUserDefaults();
        NSLog(@"[WAGram] nuclear NSUserDefaults reset removed %lu visible keys", (unsigned long)removed);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.6*NSEC_PER_SEC)),
            dispatch_get_main_queue(),^{exit(0);});
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
