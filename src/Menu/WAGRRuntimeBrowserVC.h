#pragma once
#import <UIKit/UIKit.h>

// WAGRRuntimeBrowserVC — on-demand runtime BOOL method scanner.
// Scans WAABProperties (and other target classes) ONLY when the VC is opened —
// never at startup. Observer mode activates logging without overriding values.
// Shares the exact same wagr.waab.<flag> = "on"/"off" override storage as WAGramMenuVC.

@interface WAGRRuntimeBrowserVC : UITableViewController
// Target class names to scan. Defaults to WAABProperties + subclasses.
@property (nonatomic, copy) NSArray<NSString *> *targetClassNames;
// Title prefix for navigation
@property (nonatomic, copy) NSString *browserTitle;
// Whether to automatically start scanning when view appears
@property (nonatomic, assign) BOOL autoScanOnAppear;
+ (instancetype)browserForWAABProperties;
+ (instancetype)browserForAuraGating;
+ (instancetype)browserForContextGates;
@end
