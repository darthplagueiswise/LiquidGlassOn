#pragma once
#import <UIKit/UIKit.h>

@interface WAGRRuntimeMethodBrowserVC : UITableViewController
+ (BOOL)methodNameLooksFeatureLike:(NSString *)name;
+ (NSArray *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens;
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
@end
