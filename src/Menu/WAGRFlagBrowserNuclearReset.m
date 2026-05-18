// WAGRFlagBrowserNuclearReset.m
// Implements the Reset TOTAL action for WAGRABFlagBrowserVC.
// This keeps WAGramMenuVC.m untouched and avoids UI-only/half-applied patches.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdlib.h>
#import "WAGramMenuVC.h"

static NSUInteger WAGRFlagBrowserNuclearResetAllUserDefaults(void) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSDictionary *before = [ud dictionaryRepresentation] ?: @{};
    NSUInteger removed = before.count;

    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (bundleID.length) [ud removePersistentDomainForName:bundleID];

    // Deliberately no prefix filter. This clears stale wagr.*, wa_*, aura_*,
    // ios_*, .mode, string on/off, boolean 1/0, and older malformed values that
    // are visible through standardUserDefaults.
    for (NSString *key in before.allKeys) {
        [ud removeObjectForKey:key];
    }

    [ud synchronize];

    if (bundleID.length) {
        CFPreferencesAppSynchronize((__bridge CFStringRef)bundleID);
    }
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);

    return removed;
}

@implementation WAGRABFlagBrowserVC (WAGRNuclearReset)

- (void)confirmNuclearReset {
    NSString *msg =
        @"Remove TODO o domínio NSUserDefaults do app, sem filtrar por prefixo. "
         "Isto limpa wagr.*, wa_*, aura_*, ios_*, valores antigos boolean/string/.mode "
         "e qualquer preferência do WhatsApp visível via NSUserDefaults. "
         "Não limpa Keychain, banco de dados, cache de servidor ou app group fora do standard defaults. "
         "O app fecha após limpar.";

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reset TOTAL NSUserDefaults?"
                                                               message:msg
                                                        preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"Limpar tudo e fechar"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(__unused id action) {
        NSUInteger removed = WAGRFlagBrowserNuclearResetAllUserDefaults();
        NSLog(@"[WAGram] nuclear NSUserDefaults reset from flag browser removed %lu visible keys",
              (unsigned long)removed);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            exit(0);
        });
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

    [self presentViewController:a animated:YES completion:nil];
}

@end
