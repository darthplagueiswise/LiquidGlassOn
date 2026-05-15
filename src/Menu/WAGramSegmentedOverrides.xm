#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "WAGramMenuVC.h"
#import "../WAGramPrefix.h"

static NSInteger WGSegGet(NSString *key) { return key.length ? [NSUserDefaults.standardUserDefaults integerForKey:WAGRWAABKeyMode(key)] : 0; }
static void WGSegSet(NSString *key, NSInteger mode) {
    if (!key.length) return;
    if (mode <= 0) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:WAGRWAABKeyMode(key)];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:mode forKey:WAGRWAABKeyMode(key)];
        [NSUserDefaults.standardUserDefaults setBool:(mode == 2) forKey:key];
    }
    [NSUserDefaults.standardUserDefaults synchronize];
}

static const char *kWGSegKey = "wg.seg.key";
static const char *kWGSegVC = "wg.seg.vc";

@interface WGSegmentTarget : NSObject
+ (instancetype)shared;
- (void)changed:(UISegmentedControl *)seg;
@end
@implementation WGSegmentTarget
+ (instancetype)shared { static WGSegmentTarget *s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [self new]; }); return s; }
- (void)changed:(UISegmentedControl *)seg {
    NSString *key = objc_getAssociatedObject(seg, kWGSegKey);
    id vc = objc_getAssociatedObject(seg, kWGSegVC);
    WGSegSet(key, seg.selectedSegmentIndex);
    WAGRWAABEnsureHooksInstalled();
    WAGRDirectFlagsEnsureHooksInstalled();
    if ([key containsString:@"liquid_glass"] || [key containsString:@"status_viewer_redesign"]) WAGRLGPrefsDidChange();
    if ([key containsString:@"internal"] || [key containsString:@"dogfood"] || [key containsString:@"debug"]) WAGRDogfoodEnsureHooksInstalled();
    if ([vc isKindOfClass:UITableViewController.class]) [((UITableViewController *)vc).tableView reloadData];
}
@end

static UITableViewCell *(*origWGSubCell)(id, SEL, UITableView *, NSIndexPath *) = NULL;
static UITableViewCell *hookWGSubCell(id self, SEL _cmd, UITableView *tv, NSIndexPath *ip) {
    UITableViewCell *cell = origWGSubCell ? origWGSubCell(self, _cmd, tv, ip) : nil;
    if (cell) {
        cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        cell.textLabel.textColor = UIColor.labelColor;
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        tv.backgroundColor = UIColor.systemGroupedBackgroundColor;
    }
    @try {
        NSArray<WAGramSectionDef *> *sections = [self valueForKey:@"sections"];
        WAGramRow *row = sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
        if (row.style == WAGramRowStyleWAABFlag && row.waabKey.length) {
            UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"Auto", @"Off", @"On"]];
            seg.selectedSegmentIndex = WGSegGet(row.waabKey);
            objc_setAssociatedObject(seg, kWGSegKey, row.waabKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
            objc_setAssociatedObject(seg, kWGSegVC, self, OBJC_ASSOCIATION_ASSIGN);
            [seg addTarget:[WGSegmentTarget shared] action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = seg;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.detailTextLabel.numberOfLines = 2;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@", row.subtitle ?: @"", row.waabKey];
        }
    } @catch (__unused id ex) {}
    return cell;
}

static void (*origWGSubViewDidLoad)(id, SEL) = NULL;
static void hookWGSubViewDidLoad(id self, SEL _cmd) {
    if (origWGSubViewDidLoad) origWGSubViewDidLoad(self, _cmd);
    if ([self isKindOfClass:UITableViewController.class]) ((UITableViewController *)self).tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
}

__attribute__((constructor))
static void WGSegmentInit(void) {
    Class sub = NSClassFromString(@"WAGramSubMenuVC");
    if (sub) {
        MSHookMessageEx(sub, @selector(tableView:cellForRowAtIndexPath:), (IMP)hookWGSubCell, (IMP *)&origWGSubCell);
        MSHookMessageEx(sub, @selector(viewDidLoad), (IMP)hookWGSubViewDidLoad, (IMP *)&origWGSubViewDidLoad);
    }
}
