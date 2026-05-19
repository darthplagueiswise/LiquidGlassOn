// Tweak.x — entry point. Zero Logos hooks here.
// WAGRSurfaceListVC used as WAGramMenuVC via typedef alias.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "Menu/WAGRSurfaceListVC.h"
#import "WAGramPrefix.h"

extern NSUInteger WAGRReinstallPersistedHooks(void);
extern void WAGRDogfoodEnsureHooksInstalled(void);
extern void WAGRLGPrefsDidChange(void);

static const char *kLP = "wagr.lp.ok";
static IMP orig_vda = NULL;
static BOOL (*orig_debugMenuAllowed)(id,SEL) = NULL;
static BOOL gSettingsHooked = NO;

static BOOL WAGRNativeDebugAllowed(void) {
    return WAGRPref(kWAGRDebugMenuNative)||WAGRPref(kWAGRInternalMaster)||
           WAGRPref(kWAGREmployeeMaster)||WAGRPref(kWAGRDebugMode);
}
static void WAGRPresent(UIViewController *from) {
    if(!from)return;
    dispatch_async(dispatch_get_main_queue(),^{
        UIViewController*p=from;while(p.presentedViewController)p=p.presentedViewController;
        WAGRSurfaceListVC*menu=[[WAGRSurfaceListVC alloc]init];
        UINavigationController*nav=[[UINavigationController alloc]initWithRootViewController:menu];
        nav.modalPresentationStyle=UIModalPresentationFormSheet;
        if(@available(iOS 15.0,*)){
            UISheetPresentationController*sh=nav.sheetPresentationController;
            sh.prefersGrabberVisible=YES;
            sh.detents=@[UISheetPresentationControllerDetent.largeDetent];
        }
        [p presentViewController:nav animated:YES completion:nil];
    });
}

static UITableView *findTV(UIView *root){
    if(!root)return nil;
    if([root isKindOfClass:UITableView.class])return(UITableView*)root;
    NSMutableArray*q=[NSMutableArray arrayWithObject:root];NSUInteger i=0;
    while(i<q.count){UIView*v=q[i++];if([v isKindOfClass:UITableView.class])return(UITableView*)v;
        for(UIView*s in v.subviews)if(s&&q.count<2048)[q addObject:s];}return nil;
}
static NSString *cellText(UITableViewCell*c){
    NSMutableArray*p=[NSMutableArray array];
    void(^add)(id)=^(id o){if([o isKindOfClass:NSString.class]&&[o length])[p addObject:[o lowercaseString]];};
    add(c.reuseIdentifier);add(c.accessibilityIdentifier);add(c.accessibilityLabel);add(c.textLabel.text);add(c.detailTextLabel.text);
    return[p componentsJoinedByString:@" "];
}
static BOOL isTrigger(UITableViewCell*c){
    NSString*s=cellText(c);
    return [s containsString:@"help"]||[s containsString:@"ajuda"]||
           [s containsString:@"developer"]||[s containsString:@"desenvolvedor"];
}
static UIViewController *vcForView(UIView*v){UIResponder*r=v;while(r){if([r isKindOfClass:UIViewController.class])return(UIViewController*)r;r=r.nextResponder;}return nil;}

@interface WAGRLP:NSObject+(instancetype)shared;-(void)lp:(UILongPressGestureRecognizer*)g;@end
@implementation WAGRLP
+(instancetype)shared{static WAGRLP*s;static dispatch_once_t o;dispatch_once(&o,^{ s = [self new]; }); return s;}
-(void)lp:(UILongPressGestureRecognizer*)g{
    if(g.state!=UIGestureRecognizerStateBegan)return;
    UITableView*tv=(UITableView*)g.view;if(![tv isKindOfClass:UITableView.class])return;
    NSIndexPath*ip=[tv indexPathForRowAtPoint:[g locationInView:tv]];if(!ip)return;
    UITableViewCell*c=[tv cellForRowAtIndexPath:ip];if(!isTrigger(c))return;
    WAGRPresent(vcForView(tv));
}@end

static void attachLP(UITableView*tv){
    if(!tv)return;
    if([objc_getAssociatedObject(tv,kLP)boolValue])return;
    UILongPressGestureRecognizer*lp=[[UILongPressGestureRecognizer alloc]
        initWithTarget:[WAGRLP shared] action:@selector(lp:)];
    lp.minimumPressDuration=0.65;lp.cancelsTouchesInView=NO;
    objc_setAssociatedObject(tv,kLP,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tv addGestureRecognizer:lp];
}
static void hookVDA(id self,SEL c,BOOL a){
    if(orig_vda)((void(*)(id,SEL,BOOL))orig_vda)(self,c,a);
    if(![self isKindOfClass:UIViewController.class])return;
    attachLP(findTV(((UIViewController*)self).view));
    if(WAGRNativeDebugAllowed())[findTV(((UIViewController*)self).view) reloadData];
}
static BOOL hookDebug(id self,SEL c){
    if(WAGRNativeDebugAllowed())return YES;
    return orig_debugMenuAllowed?orig_debugMenuAllowed(self,c):NO;
}

static void installSettingsHooks(void){
    if(gSettingsHooked)return;
    NSArray*names=@[@"WASettingsViewController",@"WASettingsTableViewController",
                    @"WANewSettingsViewController",@"WASettingsNavTableViewController",
                    @"WASettingsNavigationController"];
    SEL dbgSel=NSSelectorFromString(@"isDebugMenuAllowed");
    for(NSString*n in names){
        Class cls=NSClassFromString(n);if(!cls)continue;
        if(!orig_vda){Method m=class_getInstanceMethod(cls,@selector(viewDidAppear:));
            if(m){MSHookMessageEx(cls,@selector(viewDidAppear:),(IMP)hookVDA,&orig_vda);}}
        if(!orig_debugMenuAllowed){
            Method m=class_getInstanceMethod(cls,dbgSel);
            if(m){MSHookMessageEx(cls,dbgSel,(IMP)hookDebug,(IMP*)&orig_debugMenuAllowed);}
            else{m=class_getClassMethod(cls,dbgSel);
                if(m){MSHookMessageEx(object_getClass(cls),dbgSel,(IMP)hookDebug,(IMP*)&orig_debugMenuAllowed);}}
        }
        if(orig_vda&&orig_debugMenuAllowed){gSettingsHooked=YES;break;}
    }
}

void WAGRDebugMenuEnsureHooksInstalled(void){installSettingsHooks();}
NSString *WAGRDebugMenuDiagnosticText(void){
    return [NSString stringWithFormat:@"nativeDebug=%@\nhooks=%@\nrouter=%@",
        WAGRNativeDebugAllowed()?@"ON":@"OFF",gSettingsHooked?@"YES":@"NO",
        WAGRHookRouterDiagnostic()];
}

static void startup(void){
    @autoreleasepool{
        WAGRLGPrefsDidChange();
        installSettingsHooks();
        WAGRReinstallPersistedHooks();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            installSettingsHooks(); WAGRDogfoodEnsureHooksInstalled(); WAGRReinstallPersistedHooks();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(3.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            installSettingsHooks(); WAGRDogfoodEnsureHooksInstalled();
        });
    }
}

%ctor { startup(); }
