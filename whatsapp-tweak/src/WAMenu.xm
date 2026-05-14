#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook WAHelpAndFeedbackViewController  // Adjust class name if needed (use class-dump)

- (void)viewDidLoad {
    %orig;
    
    // Long press on the view or specific cell to open our menu (like RyukGram-Fork/dev2)
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(wa_showRyukMenu:)];
    longPress.minimumPressDuration = 1.5;
    [self.view addGestureRecognizer:longPress];
}

%new
- (void)wa_showRyukMenu:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"RyukGram WA Menu"
                                                                  message:@"LiquidGlass + Dogfood + Debug\nBase: RyukGram-Fork/dev2"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Liquid Glass submenu
    [menu addAction:[UIAlertAction actionWithTitle:@"💧 Liquid Glass (toggle)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self wa_toggleLiquidGlass];
    }]];
    
    // Feature Flags (observer)
    [menu addAction:[UIAlertAction actionWithTitle:@"🔬 Feature Flags / ABProps Observer" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self wa_toggleABPropsObserver];
    }]];
    
    // Dogfood Employee
    [menu addAction:[UIAlertAction actionWithTitle:@"🐶 Dogfood Employee (toggle)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self wa_toggleDogfood];
    }]];
    
    // Keychain Diagnostic
    [menu addAction:[UIAlertAction actionWithTitle:@"🔑 Keychain Diagnostic" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        extern void WAShowKeychainDiagnostic(void);
        WAShowKeychainDiagnostic();
    }]];
    
    // Debug Mode placeholder
    [menu addAction:[UIAlertAction actionWithTitle:@"🛠 Debug Mode (coming soon)" style:UIAlertActionStyleDefault handler:nil]];
    
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:menu animated:YES completion:nil];
}

%new
- (void)wa_toggleLiquidGlass {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"] ?: [NSMutableDictionary new];
    BOOL current = [prefs[@"wa_liquid_glass_enabled"] boolValue];
    prefs[@"wa_liquid_glass_enabled"] = @(!current);
    [prefs writeToFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist" atomically:YES];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.darthplagueiswise.waliquidglassryuk/prefsChanged"), NULL, NULL, YES);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Liquid Glass"
                                                                   message:current ? @"Desativado" : @"Ativado (reinicie o app)"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%new
- (void)wa_toggleABPropsObserver {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"] ?: [NSMutableDictionary new];
    BOOL current = [prefs[@"wa_abprops_observer_enabled"] boolValue];
    prefs[@"wa_abprops_observer_enabled"] = @(!current);
    [prefs writeToFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist" atomically:YES];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.darthplagueiswise.waliquidglassryuk/prefsChanged"), NULL, NULL, YES);
}

%new
- (void)wa_toggleDogfood {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"] ?: [NSMutableDictionary new];
    BOOL current = [prefs[@"wa_employee_master"] boolValue];
    prefs[@"wa_employee_master"] = @(!current);
    [prefs writeToFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist" atomically:YES];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.darthplagueiswise.waliquidglassryuk/prefsChanged"), NULL, NULL, YES);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dogfood Employee"
                                                                   message:current ? @"Desativado" : @"Ativado - Employee gates ON"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end