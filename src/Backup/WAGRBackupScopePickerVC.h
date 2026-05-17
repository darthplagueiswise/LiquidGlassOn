// WAGRBackupScopePickerVC.h — Two-row scope picker for backup import.

#pragma once
#import <UIKit/UIKit.h>
#import "WAGRBackup.h"

@interface WAGRBackupScopePickerVC : UITableViewController
- (instancetype)initWithWAABCount:(NSUInteger)waabCount
                     contextCount:(NSUInteger)contextCount
                       onContinue:(void (^)(WAGRBackupScope scope))onContinue;
@end
