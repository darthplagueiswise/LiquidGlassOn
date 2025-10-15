#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL LG_isEnabled(id self, SEL _cmd) {
    return YES;
}

__attribute__((constructor))
static void lg_boot(void) {
    @autoreleasepool {
        // 1) Semeia a override nos possíveis suites (WhatsApp normal e Business)
        NSArray<NSString *> *suites = @[@"group.net.whatsapp.WhatsApp.shared",
                                        @"group.net.whatsapp.WhatsApp.private",
                                        @"group.net.whatsapp.WhatsAppSMB.shared",
                                        @"group.net.whatsapp.WhatsAppSMB.private"];
        for (NSString *suite in suites) {
            NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:suite];
            if (ud) {
                [ud setBool:YES forKey:@"WAOverrideLiquidGlassEnabled"];
                [ud synchronize];
            }
        }
        // fallback: domínio padrão também
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WAOverrideLiquidGlassEnabled"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // 2) Swizzle suave: +[WDSLiquidGlass isEnabled] -> sempre YES
        Class cls = objc_getClass("WDSLiquidGlass");
        if (cls) {
            SEL sel = sel_registerName("isEnabled");
            Method m = class_getClassMethod(cls, sel);
            if (m) {
                IMP newImp = (IMP)LG_isEnabled;
                method_setImplementation(m, newImp);
            }
        }
    }
}
