// WAGramMenuVC.h — WAGram v6 header
#pragma once
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
void      WAGRWAABEnsureHooksInstalled(void);
NSString *WAGRWAABDiagnosticText(void);
NSString *WAGRABObsLog(void);
void      WAGRABObsClear(void);
void      WAGRDogfoodEnsureHooksInstalled(void);
NSString *WAGRDogfoodDiagnosticText(void);
void      WAInstallKeychainPatchIfNeeded(void);
NSString *WAKeychainAccessGroupDiagnostic(void);
void      WAGRLGPrefsDidChange(void);
NSString *WAGRLGDiagnosticText(void);
void      WAGRDebugMenuEnsureHooksInstalled(void);
NSString *WAGRDebugMenuDiagnosticText(void);
void      WAGRAuraEnsureHooksInstalled(void);
void      WAGRAuraActivateAllFlags(void);
void      WAGRAuraDeactivateAllFlags(void);
BOOL      WAGRPushAuraThemesVC(UIViewController *from);
BOOL      WAGRPushAuraIconsVC(UIViewController *from);
BOOL      WAGRPushAuraRingtonesVC(UIViewController *from);
NSString *WAGRAuraDiagnostic(void);
#ifdef __cplusplus
}
#endif

typedef NS_ENUM(NSInteger, WAGramRowStyle) {
    WAGramRowStyleSwitch,
    WAGramRowStyleButton,
    WAGramRowStyleNavigation,
    WAGramRowStyleWAABFlag,
};
@interface WAGramRow : NSObject
@property (nonatomic, copy)   NSString        *title;
@property (nonatomic, copy)   NSString        *subtitle;
@property (nonatomic, copy)   NSString        *prefsKey;
@property (nonatomic, copy)   NSString        *waabKey;
@property (nonatomic, assign) WAGramRowStyle   style;
@property (nonatomic, copy)   void (^action)(BOOL);
@property (nonatomic, strong) UIViewController *navTarget;
+ (instancetype)switchWithTitle:(NSString *)t subtitle:(NSString *)s key:(NSString *)k action:(void(^)(BOOL))a;
+ (instancetype)waabWithTitle:(NSString *)t key:(NSString *)k;
+ (instancetype)buttonWithTitle:(NSString *)t action:(void(^)(BOOL))a;
+ (instancetype)navWithTitle:(NSString *)t subtitle:(NSString *)s target:(UIViewController *)vc;
@end
@interface WAGramSectionDef : NSObject
@property (nonatomic, copy)   NSString         *header;
@property (nonatomic, copy)   NSString         *footer;
@property (nonatomic, strong) NSArray<WAGramRow *> *rows;
+ (instancetype)sectionWithHeader:(NSString *)h footer:(NSString *)f rows:(NSArray<WAGramRow *> *)rows;
@end
@interface WAGramMenuVC : UITableViewController
@end
@interface WAGramSubMenuVC : UITableViewController
- (instancetype)initWithSections:(NSArray<WAGramSectionDef *> *)s title:(NSString *)t;
@end
@interface WAGRABFlagBrowserVC : UITableViewController <UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags;
+ (NSArray<NSString *> *)runtimeFlags;
@end
@interface WAGRRuntimeMethodBrowserVC : UITableViewController <UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
+ (NSArray<NSString *> *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens;
@end
