// WAGramDogfoodGateToggles.xm
// Converts the Dogfood direct selector rows from info buttons to real toggles.

#import <UIKit/UIKit.h>
#import <substrate.h>
#import "WAGramMenuVC.h"
#import "../WAGramPrefix.h"

static WAGramRow *WGDGateSwitch(NSString *key, NSString *title, NSString *subtitle) {
    return [WAGramRow switchWithTitle:title subtitle:subtitle key:key action:^(__unused BOOL on) {
        WAGRDogfoodEnsureHooksInstalled();
    }];
}

static WAGramSectionDef *WGDDirectGateSection(void) {
    return [WAGramSectionDef sectionWithHeader:@"Dogfood Direct Gates"
                                        footer:@"Direct Objective-C selector hooks. Hooks are installed at startup and each toggle controls the return value: the first three return YES when ON; graphQLEmployeeC1Disabled returns NO when ON. Master Employee/Internal/Debug still forces all four."
                                          rows:@[
        WGDGateSwitch(kWAGRDogfoodGateMetaEmployee,
                      @"isMetaEmployeeOrInternalTester",
                      @"Direct hook · ON returns YES"),
        WGDGateSwitch(kWAGRDogfoodGateMetaEmployeeSnake,
                      @"is_meta_employee_or_internal_tester",
                      @"Direct hook · ON returns YES"),
        WGDGateSwitch(kWAGRDogfoodGateInternalUser,
                      @"isInternalUser",
                      @"Direct hook · ON returns YES"),
        WGDGateSwitch(kWAGRDogfoodGateGraphQLEmpC1,
                      @"graphQLEmployeeC1Disabled",
                      @"Direct hook · ON returns NO, enabling Employee C1")
    ]];
}

static id (*orig_WGDSubInit)(id, SEL, NSArray<WAGramSectionDef *> *, NSString *) = NULL;
static id hook_WGDSubInit(id self, SEL _cmd, NSArray<WAGramSectionDef *> *sections, NSString *title) {
    if ([title isEqualToString:@"Dogfood / Employee"] && sections.count > 0) {
        NSMutableArray<WAGramSectionDef *> *patched = [sections mutableCopy];
        patched[0] = WGDDirectGateSection();
        sections = patched;
    }
    return orig_WGDSubInit ? orig_WGDSubInit(self, _cmd, sections, title) : self;
}

__attribute__((constructor))
static void WGDGateTogglesInit(void) {
    Class cls = NSClassFromString(@"WAGramSubMenuVC");
    if (cls) {
        MSHookMessageEx(cls,
                        @selector(initWithSections:title:),
                        (IMP)hook_WGDSubInit,
                        (IMP *)&orig_WGDSubInit);
    }
}
