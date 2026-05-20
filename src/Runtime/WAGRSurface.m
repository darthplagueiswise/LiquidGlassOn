#import "WAGRSurface.h"
#import <objc/runtime.h>

@implementation WAGREntry @end

static WAGRSurfaceSpec *WAGRMakeSurface(NSString *sid,
                                        NSString *title,
                                        NSString *subtitle,
                                        NSString *icon,
                                        NSArray<NSString *> *names,
                                        NSArray<NSString *> *frags,
                                        NSArray<NSString *> *tokens,
                                        NSArray<NSString *> *cats,
                                        BOOL inst,
                                        BOOL cls,
                                        BOOL props,
                                        BOOL advanced) {
    WAGRSurfaceSpec *s = [WAGRSurfaceSpec new];
    s.surfaceID = sid;
    s.title = title;
    s.subtitle = subtitle ?: @"";
    s.icon = icon ?: @"circle";
    s.classNames = names ?: @[];
    s.classNameFragments = frags ?: @[];
    s.selectorTokens = tokens ?: @[];
    s.categoryAllowList = cats ?: @[];
    s.scanInstanceMethods = inst;
    s.scanClassMethods = cls;
    s.scanProperties = props;
    s.advancedOnly = advanced;
    return s;
}

@implementation WAGRSurfaceSpec

+ (NSArray<WAGRSurfaceSpec *> *)allSurfaces {
    return @[
        WAGRMakeSurface(kWAGRSurfaceWAAB, @"WAABProperties",
                        @"AB props / feature flags",
                        @"switch.2",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl"],
                        @[@"WAABProperties", @"ABProperties"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceContext, @"WAContextMain",
                        @"Context services, feature keepers, properties",
                        @"cube.transparent",
                        @[@"WAContextMain", @"WAContext"],
                        @[@"WAContextMain", @"WAContext"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceGateKeep, @"Feature Gate Keepers",
                        @"FeatureControlGateKeeper and related services",
                        @"shield",
                        @[@"WAFeatureControlGateKeeper", @"WAFeatureKeyManagerStore"],
                        @[@"FeatureControlGateKeeper", @"FeatureKeyManager", @"GateKeeper", @"Gating"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceAura, @"WAAuraGating",
                        @"WA Plus / Aura gates and benefit checks",
                        @"star",
                        @[@"WAAuraGating", @"WAAuraGating.AuraGating"],
                        @[@"AuraGating", @"AuraBenefit", @"AuraSubscription", @"Aura"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceSettings, @"Settings Navigation",
                        @"Settings controllers, rows, internal menus",
                        @"gearshape",
                        @[@"WASettingsViewController", @"WASettingsNavigationController",
                          @"WANewSettingsViewController", @"WASettingsTableViewController"],
                        @[@"Settings", @"NavigationController", @"Developer", @"Debug"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceEmployee, @"Employee / Dogfood",
                        @"Employee, dogfood, internal and debug gates",
                        @"person.badge.key",
                        @[@"WAABProperties", @"WAUserContext", @"WAAccountInfo",
                          @"WAAccountManager", @"WAEmployeeGating", @"WADebugMenuMain",
                          @"WASettingsViewController"],
                        @[@"Employee", @"Dogfood", @"Internal", @"DebugMenu", @"Developer"],
                        @[], @[], YES, YES, YES, YES),
    ];
}

+ (NSArray<WAGRSurfaceSpec *> *)featureBundles {
    return @[
        WAGRMakeSurface(@"bundle_general", @"Geral",
                        @"Feature gates gerais e flags de app",
                        @"gearshape",
                        @[@"WAABProperties", @"WAContextMain", @"WAFeatureControlGateKeeper"],
                        @[@"WAABProperties", @"FeatureControl", @"GateKeeper", @"Gating"],
                        @[@"feature", @"enabled", @"gate", @"keeper", @"eligible"],
                        @[], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_liquidglass", @"LiquidGlass",
                        @"liquid/glass/WDS/visual effects",
                        @"drop",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WDSLiquidGlass"],
                        @[@"LiquidGlass", @"WDSLiquidGlass", @"WAABProperties", @"MobileConfig"],
                        @[@"liquid", @"glass", @"wds"],
                        @[@"Liquid Glass"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_aura", @"WA Plus / Aura",
                        @"Aura, premium, subscription, benefits",
                        @"star",
                        @[@"WAAuraGating", @"WAAuraGating.AuraGating", @"WAABProperties"],
                        @[@"Aura", @"Premium", @"Subscription", @"Benefit", @"Plus"],
                        @[@"aura", @"premium", @"subscription", @"benefit", @"plus"],
                        @[@"WA Plus / Aura", @"Premium / Business"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_status", @"Status",
                        @"Status, stickers, stamps and viewer gates",
                        @"checkmark.circle",
                        @[@"WAABProperties", @"WAContextMain"],
                        @[@"Status", @"Sticker", @"Stamp", @"Viewer"],
                        @[@"status", @"sticker", @"stamp", @"viewer", @"story"],
                        @[@"Status", @"Status / Channels"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_channels", @"Channels",
                        @"Channels, newsletters and broadcast",
                        @"megaphone",
                        @[@"WAABProperties", @"WAContextMain"],
                        @[@"Channel", @"Newsletter", @"Broadcast"],
                        @[@"channel", @"newsletter", @"broadcast"],
                        @[@"Status / Channels"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_calls", @"Calls",
                        @"Call, VOIP and voicemail gates",
                        @"phone",
                        @[@"WAABProperties", @"WAContextMain"],
                        @[@"Call", @"Voip", @"VOIP", @"Voice"],
                        @[@"call", @"voip", @"voice", @"voicemail"],
                        @[@"Calls"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_messages", @"Mensagens",
                        @"Messaging, chat, composer, stickers, polls",
                        @"paperplane",
                        @[@"WAABProperties", @"WAContextMain"],
                        @[@"Message", @"Chat", @"Composer", @"Sticker", @"Poll", @"Thread"],
                        @[@"message", @"chat", @"composer", @"sticker", @"poll", @"thread", @"inline"],
                        @[@"Messaging", @"Messages"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_ai", @"AI / Meta AI",
                        @"Meta AI, imagine, bots and incognito AI",
                        @"sparkles",
                        @[@"WAABProperties", @"WAContextMain"],
                        @[@"AI", @"MetaAI", @"Imagine", @"Llama", @"Bot", @"Incognito"],
                        @[@"ai", @"metaai", @"imagine", @"llama", @"bot", @"incognito", @"hatch"],
                        @[@"AI / Meta AI"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_privacy", @"Privacy & Username",
                        @"Privacy, username, passkey and defense gates",
                        @"lock.shield",
                        @[@"WAABProperties", @"WAContextMain"],
                        @[@"Privacy", @"Username", @"Passkey", @"Defense"],
                        @[@"privacy", @"username", @"passkey", @"defense", @"block", @"contact"],
                        @[@"Privacy / Username"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_business", @"Premium & Business",
                        @"Business, SMB, commerce and premium gates",
                        @"briefcase",
                        @[@"WAABProperties", @"WAContextMain"],
                        @[@"Business", @"SMB", @"Commerce", @"Premium"],
                        @[@"business", @"smb", @"commerce", @"premium", @"paid"],
                        @[@"Premium / Business"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_settings", @"Settings Rows",
                        @"Settings rows and hidden native developer entries",
                        @"rectangle.grid.2x2",
                        @[@"WASettingsViewController", @"WASettingsNavigationController",
                          @"WANewSettingsViewController", @"WASettingsTableViewController",
                          @"WAContextMain", @"WAFeatureControlGateKeeper"],
                        @[@"Settings", @"NavigationController", @"Developer", @"Debug", @"FeatureControl"],
                        @[@"settings", @"row", @"cell", @"menu", @"developer", @"debug", @"internal"],
                        @[@"Settings Rows", @"Debug / Internal"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_internal", @"Developer / Dogfood / Internal",
                        @"Employee, dogfood, debug menu, internal gates",
                        @"person.badge.key",
                        @[@"WAABProperties", @"WAUserContext", @"WAAccountInfo",
                          @"WAAccountManager", @"WAEmployeeGating", @"WADebugMenuMain",
                          @"WASettingsViewController", @"WAContextMain"],
                        @[@"Employee", @"Dogfood", @"Internal", @"DebugMenu", @"Developer"],
                        @[@"employee", @"dogfood", @"internal", @"debug", @"developer", @"tester"],
                        @[@"Debug / Internal"], YES, YES, YES, NO),
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
    if ([s containsString:@"aura"] || [s containsString:@"subscri"] ||
        [s containsString:@"premium"] || [s containsString:@"benefit"] ||
        [s containsString:@"plus"]) return @"WA Plus / Aura";

    if ([s containsString:@"liquid"] || [s containsString:@"glass"] ||
        [s containsString:@"wds"]) return @"Liquid Glass";

    if ([s containsString:@"ai_"] || [s hasPrefix:@"ai"] ||
        [s containsString:@"metaai"] || [s containsString:@"imagine"] ||
        [s containsString:@"hatch"] || [s containsString:@"llama"] ||
        [s containsString:@"bot"] || [s containsString:@"incognito"]) return @"AI / Meta AI";

    if ([s containsString:@"debug"] || [s containsString:@"developer"] ||
        [s containsString:@"internal"] || [s containsString:@"dogfood"] ||
        [s containsString:@"employee"] || [s containsString:@"tester"]) return @"Debug / Internal";

    if ([s containsString:@"settings"] || [s containsString:@"row"] ||
        [s containsString:@"cell"] || [s containsString:@"menu"]) return @"Settings Rows";

    if ([s containsString:@"account"] || [s containsString:@"multi"]) return @"Multi Account";

    if ([s containsString:@"privacy"] || [s containsString:@"username"] ||
        [s containsString:@"passkey"] || [s containsString:@"defense"] ||
        [s containsString:@"block"] || [s containsString:@"contact"]) return @"Privacy / Username";

    if ([s containsString:@"business"] || [s containsString:@"smb"] ||
        [s containsString:@"commerce"] || [s containsString:@"paid"]) return @"Premium / Business";

    if ([s containsString:@"call"] || [s containsString:@"voip"] ||
        [s containsString:@"voice"]) return @"Calls";

    if ([s containsString:@"message"] || [s containsString:@"chat"] ||
        [s containsString:@"composer"] || [s containsString:@"thread"] ||
        [s containsString:@"poll"]) return @"Messaging";

    if ([s containsString:@"status"] || [s containsString:@"sticker"] ||
        [s containsString:@"stamp"] || [s containsString:@"viewer"] ||
        [s containsString:@"story"]) return @"Status";

    if ([s containsString:@"channel"] || [s containsString:@"newsletter"] ||
        [s containsString:@"broadcast"]) return @"Status / Channels";

    return @"Other";
}

static BOOL WAGRReturnIsBool(const char *ret) {
    return ret && (ret[0] == 'B' || ret[0] == 'c');
}

static BOOL WAGRTokenMatch(NSArray<NSString *> *tokens, NSString *haystack) {
    if (!tokens.count) return YES;
    NSString *lo = haystack.lowercaseString ?: @"";
    for (NSString *t in tokens) {
        if (t.length && [lo containsString:t.lowercaseString]) return YES;
    }
    return NO;
}

static BOOL WAGRCategoryAllowed(WAGRSurfaceSpec *spec, NSString *cat) {
    if (!spec.categoryAllowList.count) return YES;
    for (NSString *c in spec.categoryAllowList) {
        if ([c caseInsensitiveCompare:cat] == NSOrderedSame) return YES;
    }
    return NO;
}

static void WAGRAddEntry(NSMutableArray *out,
                         NSMutableSet *seen,
                         WAGRSurfaceSpec *spec,
                         Class cls,
                         BOOL meta,
                         NSString *selector,
                         BOOL property,
                         NSString *returnType) {
    if (!selector.length || [selector containsString:@":"]) return;
    NSString *cname = NSStringFromClass(cls);
    NSString *display = WAGRCleanDisplayName(selector);
    NSString *cat = WAGRCategoryForSelector([NSString stringWithFormat:@"%@ %@ %@", cname, selector, display]);
    NSString *hay = [NSString stringWithFormat:@"%@ %@ %@", cname, selector, cat];

    if (!WAGRTokenMatch(spec.selectorTokens, hay)) return;
    if (!WAGRCategoryAllowed(spec, cat)) return;

    NSString *uid = [NSString stringWithFormat:@"%@.%@", meta ? @"class" : @"inst", selector];
    // Deduplicate by selector+method-type — different classes may declare same BOOL getter
    // (e.g. WAABProperties and FOAWAABPropertiesImpl both have ios_liquid_glass_enabled).
    // We keep the FIRST class encountered (classNames order) to avoid duplicate UI rows.
    if ([seen containsObject:uid]) return;
    [seen addObject:uid];

    WAGREntry *e = [WAGREntry new];
    e.surfaceID = spec.surfaceID ?: @"runtime";
    e.className = cname;
    e.isClassMethod = meta;
    e.isProperty = property;
    e.selectorName = selector;
    e.displayName = display;
    e.returnType = returnType ?: @"BOOL";
    e.category = cat ?: @"Other";
    e.overrideKey = WAGROverrideKey(e.surfaceID, cname, meta, selector);
    [out addObject:e];
}

@implementation WAGRScanner
+ (NSArray<WAGREntry *> *)scanSurface:(WAGRSurfaceSpec *)spec {
    if (!spec) return @[];
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    NSMutableArray *classesToScan = [NSMutableArray array];
    for (NSString *n in spec.classNames) {
        Class c = NSClassFromString(n);
        if (c && ![classesToScan containsObject:c]) [classesToScan addObject:c];
    }

    if (spec.classNameFragments.count) {
        unsigned int total = 0;
        Class *all = objc_copyClassList(&total);
        if (all) {
            for (unsigned int i = 0; i < total; i++) {
                NSString *n = NSStringFromClass(all[i]);
                for (NSString *frag in spec.classNameFragments) {
                    if (frag.length && [n rangeOfString:frag options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        if (![classesToScan containsObject:all[i]]) [classesToScan addObject:all[i]];
                        break;
                    }
                }
            }
            free(all);
        }
    }

    for (Class cls in classesToScan) {
        if (spec.scanProperties) {
            unsigned int pc = 0;
            objc_property_t *props = class_copyPropertyList(cls, &pc);
            if (props) {
                for (unsigned int i = 0; i < pc; i++) {
                    const char *pn = property_getName(props[i]);
                    const char *attrs = property_getAttributes(props[i]);
                    if (!pn || !attrs) continue;
                    NSString *attr = @(attrs);
                    if (![attr hasPrefix:@"TB"] && ![attr hasPrefix:@"Tc"]) continue;
                    NSString *sel = @(pn);
                    Method m = class_getInstanceMethod(cls, NSSelectorFromString(sel));
                    if (!m || method_getNumberOfArguments(m) != 2) continue;
                    WAGRAddEntry(out, seen, spec, cls, NO, sel, YES, @"BOOL");
                }
                free(props);
            }
        }

        for (int meta = 0; meta <= 1; meta++) {
            if (meta == 0 && !spec.scanInstanceMethods) continue;
            if (meta == 1 && !spec.scanClassMethods) continue;
            Class target = meta ? object_getClass(cls) : cls;
            unsigned int n = 0;
            Method *ms = class_copyMethodList(target, &n);
            if (!ms) continue;
            for (unsigned int i = 0; i < n; i++) {
                if (method_getNumberOfArguments(ms[i]) != 2) continue;
                char ret[8] = {0};
                method_getReturnType(ms[i], ret, sizeof(ret));
                if (!WAGRReturnIsBool(ret)) continue;
                NSString *sel = NSStringFromSelector(method_getName(ms[i]));
                WAGRAddEntry(out, seen, spec, cls, (BOOL)meta, sel, NO, @"BOOL");
            }
            free(ms);
        }
    }

    return [out sortedArrayUsingComparator:^NSComparisonResult(WAGREntry *a, WAGREntry *b) {
        NSComparisonResult r = [a.category localizedCaseInsensitiveCompare:b.category];
        if (r != NSOrderedSame) return r;
        r = [a.className localizedCaseInsensitiveCompare:b.className];
        if (r != NSOrderedSame) return r;
        return [a.displayName localizedCaseInsensitiveCompare:b.displayName];
    }];
}
@end
