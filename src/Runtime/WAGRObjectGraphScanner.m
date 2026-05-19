#import "WAGRObjectGraphScanner.h"
#import <objc/runtime.h>

@implementation WAGRObjectGraphNode @end

@implementation WAGRObjectGraphScanner

+ (NSArray<WAGRObjectGraphNode *> *)scanSettingsContextGraph {
    NSMutableArray<WAGRObjectGraphNode *> *out = [NSMutableArray array];

    NSArray<NSString *> *roots = @[
        @"WASettingsNavigationController",
        @"WASettingsViewController",
        @"WANewSettingsViewController",
        @"WAContextMain"
    ];

    NSArray<NSString *> *interesting = @[
        @"userContext", @"_userContext",
        @"featureControlGateKeeper",
        @"usernameGatingService",
        @"aiIncognitoManager",
        @"settings", @"debug", @"developer", @"gate", @"gating"
    ];

    for (NSString *className in roots) {
        Class cls = NSClassFromString(className);
        if (!cls) continue;

        unsigned int ivc = 0;
        Ivar *ivars = class_copyIvarList(cls, &ivc);
        if (ivars) {
            for (unsigned int i = 0; i < ivc; i++) {
                const char *n = ivar_getName(ivars[i]);
                if (!n) continue;
                NSString *name = @(n);
                NSString *lo = name.lowercaseString;
                BOOL keep = NO;
                for (NSString *tok in interesting) {
                    if ([lo containsString:tok.lowercaseString]) { keep = YES; break; }
                }
                if (!keep) continue;

                WAGRObjectGraphNode *node = [WAGRObjectGraphNode new];
                node.ownerClass = className;
                node.name = name;
                node.valueClass = @(ivar_getTypeEncoding(ivars[i]) ?: "");
                node.address = @"runtime";
                [out addObject:node];
            }
            free(ivars);
        }

        unsigned int pc = 0;
        objc_property_t *props = class_copyPropertyList(cls, &pc);
        if (props) {
            for (unsigned int i = 0; i < pc; i++) {
                const char *n = property_getName(props[i]);
                if (!n) continue;
                NSString *name = @(n);
                NSString *lo = name.lowercaseString;
                BOOL keep = NO;
                for (NSString *tok in interesting) {
                    if ([lo containsString:tok.lowercaseString]) { keep = YES; break; }
                }
                if (!keep) continue;

                WAGRObjectGraphNode *node = [WAGRObjectGraphNode new];
                node.ownerClass = className;
                node.name = name;
                node.valueClass = @(property_getAttributes(props[i]) ?: "");
                node.address = @"property";
                [out addObject:node];
            }
            free(props);
        }
    }

    return out;
}

@end
