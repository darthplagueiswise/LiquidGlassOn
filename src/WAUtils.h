#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

BOOL WAEnabled(NSString *key);
void WASetEnabled(NSString *key, BOOL enabled);
void WARegisterDefaults(void);
void WAPresentAlert(UIViewController *presenter, NSString *title, NSString *message);
NSString *WAStringFromObject(id value);
Class WAFindClassByNameFragment(NSString *fragment);
NSArray<Class> *WAClassesMatchingFragments(NSArray<NSString *> *fragments, NSUInteger limit);
BOOL WAInstanceRespondsTo(Class cls, SEL sel);
BOOL WAClassRespondsTo(Class cls, SEL sel);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
