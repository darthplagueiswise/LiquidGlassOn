// WAGRBackup.h — Export/Import of WAGram overrides via clipboard JSON.
// Inspired by Ryukgram-Fork's SCISettingsBackup; adapted for wagr.waab.* / wagr.context.* keys.

#pragma once
#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSInteger, WAGRBackupScope) {
    WAGRBackupScopeWAAB    = 1 << 0,
    WAGRBackupScopeContext = 1 << 1,
    WAGRBackupScopeAll     = WAGRBackupScopeWAAB | WAGRBackupScopeContext,
};

@interface WAGRBackup : NSObject

+ (NSDictionary *)snapshotForScope:(WAGRBackupScope)scope;
+ (NSData *)exportJSONForScope:(WAGRBackupScope)scope;
+ (BOOL)applyImport:(NSDictionary *)root scope:(WAGRBackupScope)scope error:(NSError **)err;

+ (NSUInteger)countForScope:(WAGRBackupScope)scope;

+ (void)presentExportFromVC:(UIViewController *)host;
+ (void)presentImportFromVC:(UIViewController *)host;

@end
