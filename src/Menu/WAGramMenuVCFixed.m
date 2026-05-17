#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import "WAGramMenuVC.h"
#import "WAGRRuntimeBrowserVC.h"
#import "../WAUtils.h"
#import "../WAGramPrefix.h"

static UIColor *WBG(void){return UIColor.systemBackgroundColor;}
static UIColor *WCell(void){return UIColor.secondarySystemBackgroundColor;}
static UIColor *WAccent(void){return UIColor.systemBlueColor;}
static NSString *WState(NSString *f){return [NSUserDefaults.standardUserDefaults stringForKey:WAGRKey(f)];}
static BOOL WOn(NSString *f){return [WState(f) isEqualToString:@"on"];}
static void WSet(NSString *f, BOOL on){if(!f.length)return; NSUserDefaults*ud=NSUserDefaults.standardUserDefaults; if(on)[ud setObject:@"on" forKey:WAGRKey(f)]; else [ud setObject:@"off" forKey:WAGRKey(f)]; [ud synchronize]; WAGRWAABEnsureHooksInstalled(); if([f containsString:@"liquid_glass"])WAGRLGPrefsDidChange(); if([f hasPrefix:@"aura_"]||[f containsString:@"benefit"])WAGRAuraGatingEnsureHooksInstalled();}
static UIViewController *Top(void){UIViewController*c=nil; for(UIScene*s in UIApplication.sharedApplication.connectedScenes){if(![s isKindOfClass:UIWindowScene.class])continue; for(UIWindow*w in ((UIWindowScene*)s).windows)if(w.isKeyWindow&&w.rootViewController){c=w.rootViewController;break;} if(c)break;} while(c.presentedViewController)c=c.presentedViewController; if([c isKindOfClass:UINavigationController.class])c=((UINavigationController*)c).visibleViewController; return c;}
static void Al(NSString*t,NSString*m){dispatch_async(dispatch_get_main_queue(),^{UIAlertController*a=[UIAlertController alertControllerWithTitle:t?:@"WAGram" message:m?:@"" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];[Top() presentViewController:a animated:YES completion:nil];});}
static NSArray*LG(void){return @[@"ios_liquid_glass_enabled",@"ios_liquid_glass_launched",@"ios_liquid_glass_m1",@"ios_liquid_glass_m_1_5",@"ios_liquid_glass_m_2_action_tile",@"ios_liquid_glass_m_2_chips",@"ios_liquid_glass_chat_top_bar_m2_enabled",@"ios_liquid_glass_enable_new_chatbar_ux",@"status_viewer_redesign_enabled"];}
static NSArray*Aura(void){return @[@"aura_enabled",@"aura_settings_row_enabled",@"aura_subscription_simulation_enabled",@"aura_app_icon_enabled",@"aura_app_themes_enabled",@"aura_ringtones_enabled",@"aura_stickers_enabled",@"isEligibleForSubscriptions",@"wa_subscriptions_entry_point_settings_enabled"];}
static NSArray*AI(void){return @[@"ai_meta_ai_in_app_tab_main_gate_enabled",@"ai_home_redesign_enabled",@"ai_chat_threads_enabled",@"ai_chat_threads_infra_enabled",@"ai_chat_thread_capability_enabled",@"ai_translate_messages_enabled"];}
static NSArray*Tab(void){return @[@"sg_ios_multi_account_enabled",@"wa_xfam_ios_switcher_multiaccount_enabled",@"foa_bridges_account_switcher_ios_enabled",@"community_tab_v2_enabled"];}
static NSArray*Settings(void){return @[@"lists_feature_enabled",@"events_global_list",@"call_favorites_enabled_companions",@"waffle_mobile_companions_enabled",@"aura_settings_row_enabled",@"aura_enabled",@"sections_in_help_menu"];}

@interface WAGRABFlagBrowserVC ()
@property(nonatomic,strong,readwrite)NSArray<NSString*>*allFlags;
@property(nonatomic,strong)NSArray<NSString*>*filtered;
@property(nonatomic,strong)UISearchController*search;
@end
static char K;
@implementation WAGRABFlagBrowserVC
- (instancetype)initWithTitle:(NSString*)t flags:(NSArray<NSString*>*)flags{if(!(self=[super initWithStyle:UITableViewStylePlain]))return nil;self.title=t?:@"Flags";self.allFlags=[flags?:@[] sortedArrayUsingSelector:@selector(compare:)];self.filtered=self.allFlags;return self;}
+ (NSArray*)runtimeFlags{Class c=NSClassFromString(@"WAABProperties");if(!c)return @[];NSMutableArray*a=[NSMutableArray array];unsigned int n=0;Method*m=class_copyMethodList(c,&n);for(unsigned int i=0;i<n;i++){if(method_getNumberOfArguments(m[i])!=2)continue;char r[8]={0};method_getReturnType(m[i],r,8);if(r[0]!='B'&&r[0]!='c')continue;NSString*nm=NSStringFromSelector(method_getName(m[i]));if(![nm containsString:@":"])[a addObject:nm];}free(m);return [[NSSet setWithArray:a].allObjects sortedArrayUsingSelector:@selector(compare:)];}
- (void)viewDidLoad{[super viewDidLoad];self.tableView.backgroundColor=WBG();self.search=[[UISearchController alloc]initWithSearchResultsController:nil];self.search.searchResultsUpdater=(id)self;self.search.obscuresBackgroundDuringPresentation=NO;self.navigationItem.searchController=self.search;if(!self.allFlags.count)[self reload];}
- (void)reload{if(!self.allFlags.count)self.allFlags=[[self class] runtimeFlags];[self updateSearchResultsForSearchController:self.search];}
- (void)updateTitle{}
- (void)updateSearchResultsForSearchController:(UISearchController*)sc{NSString*q=sc.searchBar.text?:@"";self.filtered=q.length?[self.allFlags filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@",q]]:self.allFlags;[self.tableView reloadData];}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return self.filtered.count;}
- (CGFloat)tableView:(UITableView*)tv heightForRowAtIndexPath:(NSIndexPath*)ip{return 54;}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip{UITableViewCell*c=[tv dequeueReusableCellWithIdentifier:@"f"]?:[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"f"];NSString*f=self.filtered[ip.row];c.backgroundColor=WCell();c.textLabel.text=f;c.textLabel.numberOfLines=2;c.textLabel.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];UISwitch*sw=[UISwitch new];sw.on=WOn(f);sw.onTintColor=WAccent();objc_setAssociatedObject(sw,&K,f,OBJC_ASSOCIATION_COPY_NONATOMIC);[sw addTarget:self action:@selector(ch:) forControlEvents:UIControlEventValueChanged];c.accessoryView=sw;return c;}
- (void)ch:(UISwitch*)sw{WSet(objc_getAssociatedObject(sw,&K),sw.isOn);}
@end

@implementation WAGramMenuVC
- (instancetype)init{if(!(self=[super initWithStyle:UITableViewStyleInsetGrouped]))return nil;self.title=@"WAGram";return self;}
- (void)viewDidLoad{[super viewDidLoad];self.tableView.backgroundColor=WBG();}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return 4;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return s==0?5:(s==1?5:(s==2?4:2));}
- (NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)s{return s==0?@"Controles":(s==1?@"Menus":(s==2?@"Runtime":nil));}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip{UITableViewCell*c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];c.backgroundColor=WCell();if(ip.section==0){NSString*t[]={@"Liquid Glass",@"Employee/Internal",@"Debug Menu",@"WAAB Observer",@"Aura Simulation"};NSString*k[]={WA_PREF_LIQUID_GLASS,kWAGREmployeeMaster,@"wagr.context.debugMenuAllowed",WA_PREF_AB_OBSERVER,@"wagr_aura_simulation_enabled"};c.textLabel.text=t[ip.row];UISwitch*sw=[UISwitch new];sw.on=WAEnabled(k[ip.row]);sw.tag=ip.row;[sw addTarget:self action:@selector(master:) forControlEvents:UIControlEventValueChanged];c.accessoryView=sw;c.selectionStyle=UITableViewCellSelectionStyleNone;return c;}if(ip.section==1){NSString*t[]={@"Liquid Glass",@"WA Plus / Aura",@"AI",@"Tab Bar / Multi Account",@"Settings Rows"};c.textLabel.text=t[ip.row];c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return c;}if(ip.section==2){NSString*t[]={@"Todos WAAB",@"Aura Runtime",@"Context / Debug Runtime",@"Diagnóstico"};c.textLabel.text=t[ip.row];c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return c;}NSString*t[]={@"Reiniciar WhatsApp",@"Reset Overrides"};c.textLabel.text=t[ip.row];c.textLabel.textAlignment=NSTextAlignmentCenter;c.textLabel.textColor=ip.row==0?UIColor.systemRedColor:UIColor.systemOrangeColor;return c;}
- (void)master:(UISwitch*)sw{NSString*k[]={WA_PREF_LIQUID_GLASS,kWAGREmployeeMaster,@"wagr.context.debugMenuAllowed",WA_PREF_AB_OBSERVER,@"wagr_aura_simulation_enabled"};WASetEnabled(k[sw.tag],sw.isOn);if(sw.tag==0)WAGRLGPrefsDidChange();if(sw.tag==1)WAGRDogfoodEnsureHooksInstalled();if(sw.tag==2){WAGRContextSetSimulateDebug(sw.isOn);WAGRContextEnsureHooksInstalled();}if(sw.tag==3)WAGRWAABEnsureHooksInstalled();if(sw.tag==4){WAGRAuraGatingActivate(sw.isOn);WAGRAuraEnsureHooksInstalled();}}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip{[tv deselectRowAtIndexPath:ip animated:YES];if(ip.section==1){NSArray*g[]={LG(),Aura(),AI(),Tab(),Settings()};NSString*t[]={@"Liquid Glass",@"WA Plus / Aura",@"AI",@"Tab Bar",@"Settings Rows"};[self.navigationController pushViewController:[[WAGRABFlagBrowserVC alloc]initWithTitle:t[ip.row] flags:g[ip.row]] animated:YES];return;}if(ip.section==2){UIViewController*vc=nil;if(ip.row==0)vc=[WAGRRuntimeBrowserVC browserForWAABProperties];else if(ip.row==1)vc=[WAGRRuntimeBrowserVC browserForAuraGating];else if(ip.row==2)vc=[WAGRRuntimeBrowserVC browserForContextGates];else{NSString*m=[NSString stringWithFormat:@"%@\n\n%@\n\n%@",WAGRWAABDiagnosticText(),WAGRAuraDiagnostic(),WAGRContextDiagnosticText()];Al(@"Diagnóstico",m);}if(vc)[self.navigationController pushViewController:vc animated:YES];return;}if(ip.section==3){if(ip.row==0)exit(0);else [self resetAll];}}
- (void)resetAll{NSUserDefaults*ud=NSUserDefaults.standardUserDefaults;NSUInteger n=0;for(NSString*k in [[ud dictionaryRepresentation]allKeys]){if([k hasPrefix:@"wagr."]||[k hasPrefix:@"ios_liquid_glass_"]||[k hasPrefix:@"aura_"]){[ud removeObjectForKey:k];n++;}}[ud synchronize];CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);WAGRLGPrefsDidChange();WAGRWAABEnsureHooksInstalled();Al(@"Reset",[NSString stringWithFormat:@"%lu entradas removidas",(unsigned long)n]);}
@end
