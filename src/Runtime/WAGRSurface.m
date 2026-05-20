#import "WAGRSurface.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <string.h>

@implementation WAGREntry @end

static NSString * const kWATRuntimeExecSurface   = @"runtime.exec";
static NSString * const kWATRuntimeSharedSurface = @"runtime.sharedmodules";

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
    s.surfaceID = sid ?: @"runtime";
    s.title = title ?: @"Runtime";
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

static BOOL WAGRPathIsWhatsAppExec(NSString *path) {
    if (!path.length) return NO;
    NSString *p = path.lowercaseString;
    return [p containsString:@"/whatsapp.app/whatsapp"] &&
           ![p containsString:@".framework/"];
}

static BOOL WAGRPathIsSharedModules(NSString *path) {
    if (!path.length) return NO;
    NSString *p = path.lowercaseString;
    return [p containsString:@"/frameworks/sharedmodules.framework/sharedmodules"];
}

static BOOL WAGRPathIsWhatsAppOwned(NSString *path) {
    return WAGRPathIsWhatsAppExec(path) || WAGRPathIsSharedModules(path);
}

static NSString *WAGRImagePathForClass(Class cls) {
    if (!cls) return nil;
    const char *img = class_getImageName(cls);
    return img ? @(img) : nil;
}

static NSString *WAGRImagePathForMethod(Method m) {
    if (!m) return nil;
    IMP imp = method_getImplementation(m);
    if (!imp) return nil;
    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (!dladdr((const void *)imp, &info) || !info.dli_fname) return nil;
    return @(info.dli_fname);
}

static BOOL WAGRClassIsWhatsAppOwned(Class cls) {
    return WAGRPathIsWhatsAppOwned(WAGRImagePathForClass(cls));
}

static BOOL WAGRMethodIsWhatsAppOwned(Method m) {
    return WAGRPathIsWhatsAppOwned(WAGRImagePathForMethod(m));
}

static BOOL WAGRSpecWantsExec(WAGRSurfaceSpec *spec) {
    return [spec.surfaceID isEqualToString:kWATRuntimeExecSurface];
}

static BOOL WAGRSpecWantsShared(WAGRSurfaceSpec *spec) {
    return [spec.surfaceID isEqualToString:kWATRuntimeSharedSurface];
}

static BOOL WAGRSpecIsRawImageBrowser(WAGRSurfaceSpec *spec) {
    return WAGRSpecWantsExec(spec) || WAGRSpecWantsShared(spec);
}

static BOOL WAGRClassMatchesSpecImage(Class cls, WAGRSurfaceSpec *spec) {
    NSString *path = WAGRImagePathForClass(cls);
    if (WAGRSpecWantsExec(spec)) return WAGRPathIsWhatsAppExec(path);
    if (WAGRSpecWantsShared(spec)) return WAGRPathIsSharedModules(path);
    return WAGRPathIsWhatsAppOwned(path);
}

static BOOL WAGRMethodMatchesSpecImage(Method m, WAGRSurfaceSpec *spec) {
    NSString *path = WAGRImagePathForMethod(m);
    if (WAGRSpecWantsExec(spec)) return WAGRPathIsWhatsAppExec(path);
    if (WAGRSpecWantsShared(spec)) return WAGRPathIsSharedModules(path);
    return WAGRPathIsWhatsAppOwned(path);
}

@implementation WAGRSurfaceSpec

+ (NSArray<WAGRSurfaceSpec *> *)allSurfaces {
    return @[
        WAGRMakeSurface(kWATRuntimeExecSurface, @"WhatsApp Exec BOOL Browser",
                        @"Todos os métodos/propriedades BOOL do executável principal, patcháveis por toggle",
                        @"iphone", @[], @[], @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWATRuntimeSharedSurface, @"SharedModules BOOL Browser",
                        @"Todos os métodos/propriedades BOOL do SharedModules.framework, patcháveis por toggle",
                        @"shippingbox", @[], @[], @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceWAAB, @"WAAB / AB Props",
                        @"WAABProperties and FOAWAABPropertiesImpl in SharedModules",
                        @"switch.2",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAPropertiesStore"],
                        @[@"WAABProperties", @"ABProperties", @"WAPropertiesStore"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceContext, @"WAContextMain / WAContext",
                        @"Developer provider and context services",
                        @"cube.transparent",
                        @[@"WAContextMain", @"WAContext"],
                        @[@"WAContextMain", @"WAContext"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceGateKeep, @"Feature Gate Keepers",
                        @"WAFeatureControlGateKeeper and mobile config gating",
                        @"shield",
                        @[@"WAFeatureControlGateKeeper", @"MobileConfigGating", @"WAMobileConfigGating"],
                        @[@"FeatureControlGateKeeper", @"MobileConfigGating", @"FeatureKeyManager", @"GateKeeper", @"Gating"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceAura, @"WAAuraGating",
                        @"WA Plus / Aura gates from SharedModules",
                        @"star",
                        @[@"WAAuraGating"],
                        @[@"WAAuraGating", @"AuraGating", @"AuraBenefit", @"AuraSubscription", @"Aura"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceSettings, @"Native Settings / Developer",
                        @"WASettings, WADebugViewController and DebugMenuProvider",
                        @"gearshape",
                        @[@"WASettingsNavigationController", @"WASettingsViewController",
                          @"WANewSettingsViewController", @"WASettingsTableViewController",
                          @"WADebugViewController", @"_TtC15WADebugMenuMain17DebugMenuProvider",
                          @"WACustomBehaviorsTableView"],
                        @[@"WASettings", @"WANewSettings", @"WADebugViewController",
                          @"DebugMenuProvider", @"WACustomBehaviors", @"WADebugMenu", @"WADeveloper"],
                        @[], @[], YES, YES, YES, YES),

        WAGRMakeSurface(kWAGRSurfaceEmployee, @"Developer Native Gates",
                        @"Validated native Developer gates; no Apple/System classes",
                        @"person.badge.key",
                        @[@"_TtC15WADebugMenuMain17DebugMenuProvider", @"WAContext", @"WAContextMain",
                          @"WADebugViewController", @"WAServerProperties", @"WAABProperties"],
                        @[@"DebugMenuProvider", @"WADebugViewController", @"WAServerProperties", @"WAContext",
                          @"Employee", @"Dogfood", @"Internal", @"DebugMenu", @"Developer"],
                        @[], @[], YES, YES, YES, YES),
    ];
}

+ (NSArray<WAGRSurfaceSpec *> *)featureBundles {
    return @[
        WAGRMakeSurface(@"bundle_general", @"Geral",
                        @"Feature gates reais do WhatsApp/SharedModules",
                        @"gearshape",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain", @"WAContext", @"WAFeatureControlGateKeeper", @"MobileConfigGating"],
                        @[@"WAABProperties", @"ABProperties", @"WAContextMain", @"WAContext", @"FeatureControlGateKeeper", @"MobileConfigGating", @"GateKeeper", @"Gating"],
                        @[@"feature", @"enabled", @"gate", @"keeper", @"eligible", @"is"],
                        @[], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_developer", @"Developer Nativo",
                        @"DebugMenuProvider, WADebugViewController and WAContext",
                        @"chevron.left.forwardslash.chevron.right",
                        @[@"_TtC15WADebugMenuMain17DebugMenuProvider", @"WAContext", @"WAContextMain",
                          @"WADebugViewController", @"WAServerProperties", @"WAABProperties"],
                        @[@"DebugMenuProvider", @"WADebugViewController", @"WADebugMenu", @"WAContext", @"WAServerProperties"],
                        @[@"debug", @"developer", @"shortcut", @"provider", @"internal", @"employee", @"abprops"],
                        @[@"Debug / Internal", @"Settings Rows"], YES, YES, YES, NO),

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
                        @[@"WAAuraGating", @"WAABProperties", @"FOAWAABPropertiesImpl"],
                        @[@"Aura", @"Premium", @"Subscription", @"Benefit", @"Plus"],
                        @[@"aura", @"premium", @"subscription", @"benefit", @"plus"],
                        @[@"WA Plus / Aura", @"Premium / Business"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_status", @"Status",
                        @"Status, stickers, stamps and viewer gates",
                        @"checkmark.circle",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"],
                        @[@"Status", @"Sticker", @"Stamp", @"Viewer"],
                        @[@"status", @"sticker", @"stamp", @"viewer", @"story"],
                        @[@"Status", @"Status / Channels"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_channels", @"Channels",
                        @"Channels, newsletters and broadcast",
                        @"megaphone",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"],
                        @[@"Channel", @"Newsletter", @"Broadcast"],
                        @[@"channel", @"newsletter", @"broadcast"],
                        @[@"Status / Channels"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_calls", @"Calls",
                        @"Call, VOIP and voicemail gates",
                        @"phone",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"],
                        @[@"Call", @"Voip", @"VOIP", @"Voice"],
                        @[@"call", @"voip", @"voice", @"voicemail"],
                        @[@"Calls"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_messages", @"Mensagens",
                        @"Messaging, chat, composer, stickers, polls",
                        @"paperplane",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"],
                        @[@"Message", @"Chat", @"Composer", @"Sticker", @"Poll", @"Thread"],
                        @[@"message", @"chat", @"composer", @"sticker", @"poll", @"thread", @"inline"],
                        @[@"Messaging", @"Messages"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_ai", @"AI / Meta AI",
                        @"Meta AI, imagine, bots and incognito AI",
                        @"sparkles",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"],
                        @[@"AI", @"MetaAI", @"Imagine", @"Llama", @"Bot", @"Incognito"],
                        @[@"ai", @"metaai", @"imagine", @"llama", @"bot", @"incognito", @"hatch"],
                        @[@"AI / Meta AI"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_privacy", @"Privacy & Username",
                        @"Privacy, username, passkey and defense gates",
                        @"lock.shield",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"],
                        @[@"Privacy", @"Username", @"Passkey", @"Defense"],
                        @[@"privacy", @"username", @"passkey", @"defense", @"block", @"contact"],
                        @[@"Privacy / Username"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_business", @"Premium & Business",
                        @"Business, SMB, commerce and premium gates",
                        @"briefcase",
                        @[@"WAABProperties", @"FOAWAABPropertiesImpl", @"WAContextMain"],
                        @[@"Business", @"SMB", @"Commerce", @"Premium"],
                        @[@"business", @"smb", @"commerce", @"premium", @"paid"],
                        @[@"Premium / Business"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_settings", @"Settings Rows",
                        @"Settings rows and native developer/debug entries",
                        @"rectangle.grid.2x2",
                        @[@"WASettingsNavigationController", @"WASettingsViewController",
                          @"WANewSettingsViewController", @"WASettingsTableViewController",
                          @"WADebugViewController", @"_TtC15WADebugMenuMain17DebugMenuProvider",
                          @"WAContextMain", @"WAContext", @"WAFeatureControlGateKeeper"],
                        @[@"WASettings", @"WANewSettings", @"WADebugViewController",
                          @"DebugMenuProvider", @"WAFeatureControl", @"WAContext"],
                        @[@"settings", @"row", @"cell", @"menu", @"developer", @"debug", @"internal", @"abprops"],
                        @[@"Settings Rows", @"Debug / Internal"], YES, YES, YES, NO),

        WAGRMakeSurface(@"bundle_internal", @"Developer / Dogfood / Internal",
                        @"Employee, dogfood, debug menu, internal gates",
                        @"person.badge.key",
                        @[@"WAABProperties", @"WAServerProperties", @"WAContextMain", @"WAContext",
                          @"_TtC15WADebugMenuMain17DebugMenuProvider", @"WASettingsViewController"],
                        @[@"Employee", @"Dogfood", @"Internal", @"DebugMenu", @"Developer", @"WAServerProperties", @"WAContext"],
                        @[@"employee", @"dogfood", @"internal", @"debug", @"developer", @"tester", @"shortcut"],
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
    if ([s containsString:@"liquid"] || [s containsString:@"glass"] || [s containsString:@"wds"]) return @"Liquid Glass";
    if ([s containsString:@"debugmenu"] || [s containsString:@"debug menu"] ||
        [s containsString:@"developer"] || [s containsString:@"debug"] ||
        [s containsString:@"internal"] || [s containsString:@"dogfood"] ||
        [s containsString:@"employee"] || [s containsString:@"testflight"] ||
        [s containsString:@"abprops"] || [s containsString:@"shortcut"]) return @"Debug / Internal";
    if ([s containsString:@"settings"] || [s containsString:@"row"] ||
        [s containsString:@"cell"] || [s containsString:@"menu"]) return @"Settings Rows";
    if ([s containsString:@"ai_"] || [s hasPrefix:@"ai"] || [s containsString:@"metaai"] ||
        [s containsString:@"imagine"] || [s containsString:@"hatch"] ||
        [s containsString:@"llama"] || [s containsString:@"bot"] ||
        [s containsString:@"incognito"]) return @"AI / Meta AI";
    if ([s containsString:@"account"] || [s containsString:@"multi"]) return @"Multi Account";
    if ([s containsString:@"privacy"] || [s containsString:@"username"] ||
        [s containsString:@"passkey"] || [s containsString:@"defense"] ||
        [s containsString:@"block"] || [s containsString:@"contact"]) return @"Privacy / Username";
    if ([s containsString:@"business"] || [s containsString:@"smb"] ||
        [s containsString:@"commerce"] || [s containsString:@"paid"]) return @"Premium / Business";
    if ([s containsString:@"call"] || [s containsString:@"voip"] || [s containsString:@"voice"]) return @"Calls";
    if ([s containsString:@"message"] || [s containsString:@"chat"] ||
        [s containsString:@"composer"] || [s containsString:@"thread"] ||
        [s containsString:@"poll"]) return @"Messaging";
    if ([s containsString:@"status"] || [s containsString:@"sticker"] ||
        [s containsString:@"stamp"] || [s containsString:@"viewer"] ||
        [s containsString:@"story"]) return @"Status";
    if ([s containsString:@"channel"] || [s containsString:@"newsletter"] || [s containsString:@"broadcast"]) return @"Status / Channels";
    return @"Other";
}

static BOOL WAGRReturnIsBool(const char *ret) {
    return ret && (ret[0] == 'B' || ret[0] == 'c');
}

static BOOL WAGRTokenMatch(NSArray<NSString *> *tokens, NSString *haystack) {
    if (!tokens.count) return YES;
    NSString *lo = haystack.lowercaseString ?: @"";
    for (NSString *t in tokens) if (t.length && [lo containsString:t.lowercaseString]) return YES;
    return NO;
}

static BOOL WAGRCategoryAllowed(WAGRSurfaceSpec *spec, NSString *cat) {
    if (!spec.categoryAllowList.count) return YES;
    for (NSString *c in spec.categoryAllowList) if ([c caseInsensitiveCompare:cat] == NSOrderedSame) return YES;
    return NO;
}

static void WAGRAddEntry(NSMutableArray *out, NSMutableSet *seen, WAGRSurfaceSpec *spec,
                         Class cls, BOOL meta, NSString *selector, BOOL property, NSString *returnType) {
    if (!selector.length || [selector containsString:@":"]) return;
    NSString *cname = NSStringFromClass(cls);
    NSString *display = WAGRCleanDisplayName(selector);
    NSString *cat = WAGRCategoryForSelector([NSString stringWithFormat:@"%@ %@ %@", cname, selector, display]);
    NSString *hay = [NSString stringWithFormat:@"%@ %@ %@", cname, selector, cat];
    if (!WAGRTokenMatch(spec.selectorTokens, hay)) return;
    if (!WAGRCategoryAllowed(spec, cat)) return;

    NSString *uid = [NSString stringWithFormat:@"%@.%d.%@", cname, meta, selector];
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

static void WAGRCollectAllClassesForSpec(WAGRSurfaceSpec *spec, NSMutableArray *classesToScan) {
    unsigned int total = 0;
    Class *all = objc_copyClassList(&total);
    if (!all) return;
    for (unsigned int i = 0; i < total; i++) {
        Class cls = all[i];
        if (WAGRClassMatchesSpecImage(cls, spec) && ![classesToScan containsObject:cls]) {
            [classesToScan addObject:cls];
        }
    }
    free(all);
}

@implementation WAGRScanner
+ (NSArray<WAGREntry *> *)scanSurface:(WAGRSurfaceSpec *)spec {
    if (!spec) return @[];
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableArray *classesToScan = [NSMutableArray array];

    if (WAGRSpecIsRawImageBrowser(spec)) {
        WAGRCollectAllClassesForSpec(spec, classesToScan);
    } else {
        for (NSString *n in spec.classNames) {
            Class c = NSClassFromString(n);
            if (c && WAGRClassMatchesSpecImage(c, spec) && ![classesToScan containsObject:c]) [classesToScan addObject:c];
        }

        if (spec.classNameFragments.count) {
            unsigned int total = 0;
            Class *all = objc_copyClassList(&total);
            if (all) {
                for (unsigned int i = 0; i < total; i++) {
                    Class cls = all[i];
                    if (!WAGRClassMatchesSpecImage(cls, spec)) continue;
                    NSString *n = NSStringFromClass(cls);
                    for (NSString *frag in spec.classNameFragments) {
                        if (frag.length && [n rangeOfString:frag options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            if (![classesToScan containsObject:cls]) [classesToScan addObject:cls];
                            break;
                        }
                    }
                }
                free(all);
            }
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
                    if (!WAGRMethodMatchesSpecImage(m, spec)) continue;
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
                if (!WAGRMethodMatchesSpecImage(ms[i], spec)) continue;
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
