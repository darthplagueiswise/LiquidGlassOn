#import "WAGRSurface.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <string.h>

@implementation WAGREntry @end

static NSString * const kWAGRSurfaceRuntimeExec   = @"runtime_exec_bool";
static NSString * const kWAGRSurfaceRuntimeShared = @"runtime_shared_bool";

static WAGRSurfaceSpec *WAGRMakeSurface(NSString *sid, NSString *title, NSString *subtitle, NSString *icon,
                                        NSArray<NSString *> *names, NSArray<NSString *> *frags,
                                        NSArray<NSString *> *tokens, NSArray<NSString *> *cats,
                                        BOOL inst, BOOL cls, BOOL props, BOOL advanced) {
    WAGRSurfaceSpec *s = [WAGRSurfaceSpec new];
    s.surfaceID = sid; s.title = title; s.subtitle = subtitle ?: @""; s.icon = icon ?: @"circle";
    s.classNames = names ?: @[]; s.classNameFragments = frags ?: @[];
    s.selectorTokens = tokens ?: @[]; s.categoryAllowList = cats ?: @[];
    s.scanInstanceMethods = inst; s.scanClassMethods = cls; s.scanProperties = props; s.advancedOnly = advanced;
    return s;
}

typedef NS_ENUM(NSUInteger, WAGRImageScope) { WAGRImageScopeAnyWhatsApp = 0, WAGRImageScopeMainExec, WAGRImageScopeSharedModules };
static WAGRImageScope WAGRScopeForSurface(WAGRSurfaceSpec *spec) {
    if ([spec.surfaceID isEqualToString:kWAGRSurfaceRuntimeExec]) return WAGRImageScopeMainExec;
    if ([spec.surfaceID isEqualToString:kWAGRSurfaceRuntimeShared]) return WAGRImageScopeSharedModules;
    return WAGRImageScopeAnyWhatsApp;
}
static BOOL WAGRPathIsWhatsAppExec(NSString *path) { return [path.lowercaseString containsString:@"/whatsapp.app/whatsapp"]; }
static BOOL WAGRPathIsSharedModules(NSString *path) { return [path.lowercaseString containsString:@"/frameworks/sharedmodules.framework/sharedmodules"]; }
static BOOL WAGRPathAllowedForScope(NSString *path, WAGRImageScope scope) {
    if (!path.length) return NO;
    if (scope == WAGRImageScopeMainExec) return WAGRPathIsWhatsAppExec(path);
    if (scope == WAGRImageScopeSharedModules) return WAGRPathIsSharedModules(path);
    return WAGRPathIsWhatsAppExec(path) || WAGRPathIsSharedModules(path);
}
static BOOL WAGRClassAllowedForScope(Class cls, WAGRImageScope scope) {
    if (!cls) return NO; const char *img = class_getImageName(cls);
    return img ? WAGRPathAllowedForScope(@(img), scope) : NO;
}
static BOOL WAGRMethodAllowedForScope(Method m, WAGRImageScope scope) {
    if (!m) return NO; IMP imp = method_getImplementation(m); if (!imp) return NO;
    Dl_info info; memset(&info, 0, sizeof(info));
    if (!dladdr((const void *)imp, &info) || !info.dli_fname) return NO;
    return WAGRPathAllowedForScope(@(info.dli_fname), scope);
}

@implementation WAGRSurfaceSpec
+ (NSArray<WAGRSurfaceSpec *> *)allSurfaces {
    return @[
        WAGRMakeSurface(kWAGRSurfaceRuntimeExec, @"WhatsApp Exec BOOL Browser", @"Todos os getters BOOL do executável principal; patchável e seguro", @"app.dashed", @[], @[], @[], @[], YES, YES, YES, YES),
        WAGRMakeSurface(kWAGRSurfaceRuntimeShared, @"SharedModules BOOL Browser", @"Todos os getters BOOL do SharedModules + catálogo WAAB bool", @"shippingbox", @[], @[], @[], @[], YES, YES, YES, YES),
        WAGRMakeSurface(kWAGRSurfaceWAAB, @"WAAB / AB Props", @"Catálogo WAAB bool + getters WAABProperties/FOAWAABPropertiesImpl", @"switch.2", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAPropertiesStore", @"WAProperties"], @[@"WAABProperties", @"ABProperties", @"WAPropertiesStore", @"WAProperties"], @[], @[], YES, YES, YES, YES),
        WAGRMakeSurface(kWAGRSurfaceContext, @"WAContextMain / WAContext", @"Context services, provider and feature gates", @"cube.transparent", @[@"WAContextMain", @"WAContext"], @[@"WAContextMain", @"WAContext"], @[], @[], YES, YES, YES, YES),
        WAGRMakeSurface(kWAGRSurfaceGateKeep, @"Feature Gate Keepers", @"FeatureControlGateKeeper, MobileConfigGating and related services", @"shield", @[@"WAFeatureControlGateKeeper", @"MobileConfigGating", @"WAMobileConfigGating"], @[@"FeatureControlGateKeeper", @"MobileConfigGating", @"FeatureKeyManager", @"GateKeeper", @"Gating"], @[], @[], YES, YES, YES, YES),
        WAGRMakeSurface(kWAGRSurfaceAura, @"WAAuraGating", @"WA Plus / Aura gates from SharedModules", @"star", @[@"WAAuraGating"], @[@"WAAuraGating", @"AuraGating", @"AuraBenefit", @"AuraSubscription", @"Aura"], @[], @[], YES, YES, YES, YES),
        WAGRMakeSurface(kWAGRSurfaceSettings, @"Native Settings / Developer", @"WASettings, WADebugViewController and DebugMenuProvider", @"gearshape", @[@"WASettingsNavigationController", @"WASettingsViewController", @"WANewSettingsViewController", @"WASettingsTableViewController", @"WADebugViewController", @"_TtC15WADebugMenuMain17DebugMenuProvider", @"WACustomBehaviorsTableView"], @[@"WASettings", @"WANewSettings", @"WADebugViewController", @"DebugMenuProvider", @"WACustomBehaviors"], @[], @[], YES, YES, YES, YES),
        WAGRMakeSurface(kWAGRSurfaceEmployee, @"Developer Native Gates", @"Validated native Developer gates; no broad system scan", @"person.badge.key", @[@"_TtC15WADebugMenuMain17DebugMenuProvider", @"WAContext", @"WAContextMain", @"WADebugViewController", @"WAServerProperties", @"WAABProperties"], @[@"DebugMenuProvider", @"WADebugViewController", @"WAServerProperties", @"WAContext"], @[], @[], YES, YES, YES, YES),
    ];
}
+ (NSArray<WAGRSurfaceSpec *> *)featureBundles {
    return @[
        WAGRMakeSurface(@"bundle_general", @"Geral", @"Feature gates reais do WhatsApp/SharedModules", @"gearshape", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAPropertiesStore", @"WAProperties", @"WAContextMain", @"WAContext", @"WAFeatureControlGateKeeper", @"MobileConfigGating"], @[@"WAABProperties", @"ABProperties", @"WAContextMain", @"WAContext", @"FeatureControlGateKeeper", @"MobileConfigGating", @"GateKeeper", @"Gating"], @[@"feature", @"enabled", @"gate", @"keeper", @"eligible", @"waab"], @[], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_developer", @"Developer Nativo", @"DebugMenuProvider, WADebugViewController and WAContext", @"chevron.left.forwardslash.chevron.right", @[@"_TtC15WADebugMenuMain17DebugMenuProvider", @"WAContext", @"WAContextMain", @"WADebugViewController", @"WAServerProperties", @"WAABProperties"], @[@"DebugMenuProvider", @"WADebugViewController", @"WADebugMenu", @"WAContext", @"WAServerProperties"], @[@"debug", @"developer", @"shortcut", @"provider", @"internal", @"employee", @"abprops"], @[@"Debug / Internal", @"Settings Rows"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_liquidglass", @"LiquidGlass", @"liquid/glass/WDS/visual effects", @"drop", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WDSLiquidGlass"], @[@"LiquidGlass", @"WDSLiquidGlass", @"WAABProperties", @"MobileConfig"], @[@"liquid", @"glass", @"wds"], @[@"Liquid Glass"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_aura", @"WA Plus / Aura", @"Aura, premium, subscription, benefits", @"star", @[@"WAAuraGating", @"WAABProperties", @"FOAWAABPropertiesImpl"], @[@"Aura", @"Premium", @"Subscription", @"Benefit", @"Plus"], @[@"aura", @"premium", @"subscription", @"benefit", @"plus"], @[@"WA Plus / Aura", @"Premium / Business"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_status", @"Status", @"Status, stickers, stamps and viewer gates", @"checkmark.circle", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"], @[@"Status", @"Sticker", @"Stamp", @"Viewer"], @[@"status", @"sticker", @"stamp", @"viewer", @"story"], @[@"Status", @"Status / Channels"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_channels", @"Channels", @"Channels, newsletters and broadcast", @"megaphone", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"], @[@"Channel", @"Newsletter", @"Broadcast"], @[@"channel", @"newsletter", @"broadcast"], @[@"Status / Channels"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_calls", @"Calls", @"Call, VOIP and voicemail gates", @"phone", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"], @[@"Call", @"Voip", @"VOIP", @"Voice"], @[@"call", @"voip", @"voice", @"voicemail"], @[@"Calls"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_messages", @"Mensagens", @"Messaging, chat, composer, stickers, polls", @"paperplane", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"], @[@"Message", @"Chat", @"Composer", @"Sticker", @"Poll", @"Thread"], @[@"message", @"chat", @"composer", @"sticker", @"poll", @"thread", @"inline"], @[@"Messaging", @"Messages"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_ai", @"AI / Meta AI", @"Meta AI, imagine, bots and incognito AI", @"sparkles", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"], @[@"AI", @"MetaAI", @"Imagine", @"Llama", @"Bot", @"Incognito"], @[@"ai", @"metaai", @"imagine", @"llama", @"bot", @"incognito", @"hatch"], @[@"AI / Meta AI"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_privacy", @"Privacy & Username", @"Privacy, username, passkey and defense gates", @"lock.shield", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"], @[@"Privacy", @"Username", @"Passkey", @"Defense"], @[@"privacy", @"username", @"passkey", @"defense", @"block", @"contact"], @[@"Privacy / Username"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_business", @"Premium & Business", @"Business, SMB, commerce and premium gates", @"briefcase", @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"], @[@"Business", @"SMB", @"Commerce", @"Premium"], @[@"business", @"smb", @"commerce", @"premium", @"paid"], @[@"Premium / Business"], YES, YES, YES, NO),
        WAGRMakeSurface(@"bundle_settings", @"Settings Rows", @"Settings rows and native developer/debug entries", @"rectangle.grid.2x2", @[@"WASettingsNavigationController", @"WASettingsViewController", @"WANewSettingsViewController", @"WASettingsTableViewController", @"WADebugViewController", @"_TtC15WADebugMenuMain17DebugMenuProvider", @"WAContextMain", @"WAContext", @"WAFeatureControlGateKeeper"], @[@"WASettings", @"WANewSettings", @"WADebugViewController", @"DebugMenuProvider", @"WAFeatureControl", @"WAContext"], @[@"settings", @"row", @"cell", @"menu", @"developer", @"debug", @"internal", @"abprops"], @[@"Settings Rows", @"Debug / Internal"], YES, YES, YES, NO),
    ];
}
@end

NSString *WAGRCleanDisplayName(NSString *name) {
    if (!name.length) return @"";
    NSString *s = [name copy];
    while ([s hasPrefix:@"@property "]) s = [s substringFromIndex:10];
    while ([s hasPrefix:@"- "]) s = [s substringFromIndex:2];
    while ([s hasPrefix:@"+ "]) s = [s substringFromIndex:2];
    return s;
}
NSString *WAGRCategoryForSelector(NSString *name) {
    NSString *s = name.lowercaseString ?: @"";
    if ([s containsString:@"aura"] || [s containsString:@"subscri"] || [s containsString:@"premium"] || [s containsString:@"benefit"] || [s containsString:@"plus"]) return @"WA Plus / Aura";
    if ([s containsString:@"liquid"] || [s containsString:@"glass"] || [s containsString:@"wds"]) return @"Liquid Glass";
    if ([s containsString:@"ai_"] || [s hasPrefix:@"ai"] || [s containsString:@"metaai"] || [s containsString:@"imagine"] || [s containsString:@"hatch"] || [s containsString:@"llama"] || [s containsString:@"bot"] || [s containsString:@"incognito"]) return @"AI / Meta AI";
    if ([s containsString:@"debug"] || [s containsString:@"developer"] || [s containsString:@"internal"] || [s containsString:@"dogfood"] || [s containsString:@"employee"] || [s containsString:@"tester"] || [s containsString:@"abprops"]) return @"Debug / Internal";
    if ([s containsString:@"settings"] || [s containsString:@"row"] || [s containsString:@"cell"] || [s containsString:@"menu"]) return @"Settings Rows";
    if ([s containsString:@"account"] || [s containsString:@"multi"]) return @"Multi Account";
    if ([s containsString:@"privacy"] || [s containsString:@"username"] || [s containsString:@"passkey"] || [s containsString:@"defense"] || [s containsString:@"block"] || [s containsString:@"contact"]) return @"Privacy / Username";
    if ([s containsString:@"business"] || [s containsString:@"smb"] || [s containsString:@"commerce"] || [s containsString:@"paid"]) return @"Premium / Business";
    if ([s containsString:@"call"] || [s containsString:@"voip"] || [s containsString:@"voice"]) return @"Calls";
    if ([s containsString:@"message"] || [s containsString:@"chat"] || [s containsString:@"composer"] || [s containsString:@"thread"] || [s containsString:@"poll"]) return @"Messaging";
    if ([s containsString:@"status"] || [s containsString:@"sticker"] || [s containsString:@"stamp"] || [s containsString:@"viewer"] || [s containsString:@"story"]) return @"Status";
    if ([s containsString:@"channel"] || [s containsString:@"newsletter"] || [s containsString:@"broadcast"]) return @"Status / Channels";
    return @"Other";
}
static BOOL WAGRReturnIsBool(const char *ret) { return ret && (ret[0] == 'B' || ret[0] == 'c'); }
static BOOL WAGRTokenMatch(NSArray<NSString *> *tokens, NSString *haystack) {
    if (!tokens.count) return YES; NSString *lo = haystack.lowercaseString ?: @"";
    for (NSString *t in tokens) if (t.length && [lo containsString:t.lowercaseString]) return YES;
    return NO;
}
static BOOL WAGRCategoryAllowed(WAGRSurfaceSpec *spec, NSString *cat) {
    if (!spec.categoryAllowList.count) return YES;
    for (NSString *c in spec.categoryAllowList) if ([c caseInsensitiveCompare:cat] == NSOrderedSame) return YES;
    return NO;
}
static void WAGRAddEntry(NSMutableArray *out, NSMutableSet *seen, WAGRSurfaceSpec *spec, Class cls, BOOL meta, NSString *selector, BOOL property, NSString *returnType) {
    if (!selector.length || [selector containsString:@":"]) return;
    NSString *cname = NSStringFromClass(cls); NSString *display = WAGRCleanDisplayName(selector);
    NSString *cat = WAGRCategoryForSelector([NSString stringWithFormat:@"%@ %@ %@", cname, selector, display]);
    NSString *hay = [NSString stringWithFormat:@"%@ %@ %@", cname, selector, cat];
    if (!WAGRTokenMatch(spec.selectorTokens, hay) || !WAGRCategoryAllowed(spec, cat)) return;
    NSString *uid = [NSString stringWithFormat:@"objc.%@.%d.%@", cname, meta, selector];
    if ([seen containsObject:uid]) return; [seen addObject:uid];
    WAGREntry *e = [WAGREntry new]; e.surfaceID = spec.surfaceID ?: @"runtime"; e.className = cname;
    e.isClassMethod = meta; e.isProperty = property; e.selectorName = selector; e.displayName = display;
    e.returnType = returnType ?: @"BOOL"; e.category = cat ?: @"Other"; e.overrideKey = WAGROverrideKey(e.surfaceID, cname, meta, selector);
    [out addObject:e];
}
static NSArray<NSString *> *WAGRWAABCatalogCandidatePaths(void) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSArray<NSString *> *names = @[@"waab_selected_categories_bool_only_catalog", @"waab_selected_categories_getter_validated_catalog"];
    NSArray<NSString *> *dirs = @[@"/Library/Application Support/WAGram", @"/var/jb/Library/Application Support/WAGram", @"/Library/Application Support/WATweaks", @"/var/jb/Library/Application Support/WATweaks"];
    for (NSString *d in dirs) for (NSString *n in names) [paths addObject:[[d stringByAppendingPathComponent:n] stringByAppendingPathExtension:@"json"]];
    for (NSString *n in names) { NSString *p = [NSBundle.mainBundle pathForResource:n ofType:@"json"]; if (p.length) [paths addObject:p]; }
    return paths;
}
static NSDictionary *WAGRLoadWAABCatalog(void) {
    static NSDictionary *catalog = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *p in WAGRWAABCatalogCandidatePaths()) {
            NSData *d = [NSData dataWithContentsOfFile:p]; if (!d.length) continue;
            id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if ([obj isKindOfClass:NSDictionary.class] && [obj[@"flags"] isKindOfClass:NSArray.class]) { catalog = obj; break; }
        }
        if (!catalog) catalog = @{};
    });
    return catalog;
}
static void WAGRAddWAABCatalogEntries(NSMutableArray *out, NSMutableSet *seen, WAGRSurfaceSpec *spec) {
    NSArray *flags = WAGRLoadWAABCatalog()[@"flags"];
    if (![flags isKindOfClass:NSArray.class] || !flags.count) return;
    for (NSDictionary *f in flags) {
        if (![f isKindOfClass:NSDictionary.class]) continue;
        NSString *key = [f[@"key"] isKindOfClass:NSString.class] ? f[@"key"] : nil; if (!key.length) continue;
        NSString *type = [f[@"value_type"] isKindOfClass:NSString.class] ? f[@"value_type"] : @""; if (type.length && ![type isEqualToString:@"bool"]) continue;
        NSString *title = [f[@"title"] isKindOfClass:NSString.class] ? f[@"title"] : key;
        NSString *section = [f[@"menu_section"] isKindOfClass:NSString.class] ? f[@"menu_section"] : nil;
        if (!section.length && [f[@"groups"] isKindOfClass:NSArray.class]) section = [(NSArray *)f[@"groups"] firstObject];
        if (!section.length) section = WAGRCategoryForSelector(key);
        NSString *displaySection = WAGRCategoryForSelector([NSString stringWithFormat:@"%@ %@", section, key]);
        NSString *hay = [NSString stringWithFormat:@"%@ %@ %@ %@", key, title, section, displaySection];
        if (!WAGRTokenMatch(spec.selectorTokens, hay) || !WAGRCategoryAllowed(spec, displaySection)) continue;
        NSString *uid = [@"waab." stringByAppendingString:key]; if ([seen containsObject:uid]) continue; [seen addObject:uid];
        WAGREntry *e = [WAGREntry new]; e.surfaceID = spec.surfaceID ?: kWAGRSurfaceWAAB; e.className = @"WAABFlag";
        e.isClassMethod = NO; e.isProperty = NO; e.selectorName = key; e.displayName = title.length ? title : key;
        e.returnType = @"BOOL"; e.category = displaySection ?: @"WAAB"; e.overrideKey = WATweaksWAABOverrideKey(key);
        [out addObject:e];
    }
}
static BOOL WAGRSurfaceShouldIncludeCatalog(WAGRSurfaceSpec *spec) {
    if ([spec.surfaceID isEqualToString:kWAGRSurfaceWAAB] || [spec.surfaceID isEqualToString:kWAGRSurfaceRuntimeShared]) return YES;
    for (NSString *n in spec.classNames) if ([n containsString:@"WAAB"] || [n containsString:@"FOAWAAB"]) return YES;
    for (NSString *n in spec.classNameFragments) if ([n containsString:@"WAAB"] || [n containsString:@"ABProperties"]) return YES;
    return NO;
}
@implementation WAGRScanner
+ (NSArray<WAGREntry *> *)scanSurface:(WAGRSurfaceSpec *)spec {
    if (!spec) return @[]; NSMutableArray *out = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    WAGRImageScope scope = WAGRScopeForSurface(spec);
    BOOL scanWholeImage = [spec.surfaceID isEqualToString:kWAGRSurfaceRuntimeExec] || [spec.surfaceID isEqualToString:kWAGRSurfaceRuntimeShared];
    if (WAGRSurfaceShouldIncludeCatalog(spec)) WAGRAddWAABCatalogEntries(out, seen, spec);
    NSMutableArray *classesToScan = [NSMutableArray array];
    if (scanWholeImage) {
        unsigned int total = 0; Class *all = objc_copyClassList(&total);
        if (all) { for (unsigned int i = 0; i < total; i++) if (WAGRClassAllowedForScope(all[i], scope)) [classesToScan addObject:all[i]]; free(all); }
    } else {
        for (NSString *n in spec.classNames) { Class c = NSClassFromString(n); if (c && WAGRClassAllowedForScope(c, scope) && ![classesToScan containsObject:c]) [classesToScan addObject:c]; }
        if (spec.classNameFragments.count) {
            unsigned int total = 0; Class *all = objc_copyClassList(&total);
            if (all) {
                for (unsigned int i = 0; i < total; i++) { if (!WAGRClassAllowedForScope(all[i], scope)) continue; NSString *n = NSStringFromClass(all[i]);
                    for (NSString *frag in spec.classNameFragments) if (frag.length && [n rangeOfString:frag options:NSCaseInsensitiveSearch].location != NSNotFound) { if (![classesToScan containsObject:all[i]]) [classesToScan addObject:all[i]]; break; }
                }
                free(all);
            }
        }
    }
    for (Class cls in classesToScan) {
        if (spec.scanProperties) {
            unsigned int pc = 0; objc_property_t *props = class_copyPropertyList(cls, &pc);
            if (props) { for (unsigned int i = 0; i < pc; i++) {
                const char *pn = property_getName(props[i]); const char *attrs = property_getAttributes(props[i]); if (!pn || !attrs) continue;
                NSString *attr = @(attrs); if (![attr hasPrefix:@"TB"] && ![attr hasPrefix:@"Tc"]) continue;
                NSString *sel = @(pn); Method m = class_getInstanceMethod(cls, NSSelectorFromString(sel));
                if (!m || method_getNumberOfArguments(m) != 2 || !WAGRMethodAllowedForScope(m, scope)) continue;
                WAGRAddEntry(out, seen, spec, cls, NO, sel, YES, @"BOOL");
            } free(props); }
        }
        for (int meta = 0; meta <= 1; meta++) {
            if (meta == 0 && !spec.scanInstanceMethods) continue; if (meta == 1 && !spec.scanClassMethods) continue;
            Class target = meta ? object_getClass(cls) : cls; unsigned int n = 0; Method *ms = class_copyMethodList(target, &n); if (!ms) continue;
            for (unsigned int i = 0; i < n; i++) {
                if (method_getNumberOfArguments(ms[i]) != 2 || !WAGRMethodAllowedForScope(ms[i], scope)) continue;
                char ret[8] = {0}; method_getReturnType(ms[i], ret, sizeof(ret)); if (!WAGRReturnIsBool(ret)) continue;
                WAGRAddEntry(out, seen, spec, cls, (BOOL)meta, NSStringFromSelector(method_getName(ms[i])), NO, @"BOOL");
            }
            free(ms);
        }
    }
    return [out sortedArrayUsingComparator:^NSComparisonResult(WAGREntry *a, WAGREntry *b) {
        NSComparisonResult r = [a.category localizedCaseInsensitiveCompare:b.category]; if (r != NSOrderedSame) return r;
        r = [a.className localizedCaseInsensitiveCompare:b.className]; if (r != NSOrderedSame) return r;
        return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
    }];
}
@end
