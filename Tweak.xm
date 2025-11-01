#import <UIKit/UIKit.h>
%hook UIApplication
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    NSLog(@"[EnableLiquidGlass] CI hello from tweak.");
}
%end
