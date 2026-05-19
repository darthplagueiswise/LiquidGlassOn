#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static BOOL (*orig_isMetaEmployee)(id,SEL)=NULL;
static BOOL (*orig_isMetaEmployeeSnake)(id,SEL)=NULL;
static BOOL (*orig_isInternalUser)(id,SEL)=NULL;
static BOOL (*orig_graphQLEmpC1)(id,SEL)=NULL;
static BOOL _empInstalled=NO; static NSUInteger _empCount=0;

static BOOL WAGRDogfoodForce(NSString *gk){return WAGRPref(kWAGREmployeeMaster)||WAGRPref(gk);}

static BOOL h_isMetaEmployee(id self,SEL c){if(WAGRDogfoodForce(kWAGRDogfoodGateMetaEmployee))return YES;return orig_isMetaEmployee?orig_isMetaEmployee(self,c):NO;}
static BOOL h_isMetaEmployeeSnake(id self,SEL c){if(WAGRDogfoodForce(kWAGRDogfoodGateMetaEmployeeSnake))return YES;return orig_isMetaEmployeeSnake?orig_isMetaEmployeeSnake(self,c):NO;}
static BOOL h_isInternalUser(id self,SEL c){if(WAGRDogfoodForce(kWAGRDogfoodGateInternalUser))return YES;return orig_isInternalUser?orig_isInternalUser(self,c):NO;}
static BOOL h_graphQLEmpC1(id self,SEL c){if(WAGRDogfoodForce(kWAGRDogfoodGateGraphQLEmpC1))return NO;return orig_graphQLEmpC1?orig_graphQLEmpC1(self,c):YES;}

static void WAGRHookOnCls(Class cls,const char*s,IMP h,IMP*o){
    if(!cls||!s||!h||!o||*o)return;
    SEL sel=sel_registerName(s);
    for(int m=0;m<2;m++){
        Method mt=m?class_getClassMethod(cls,sel):class_getInstanceMethod(cls,sel);
        if(!mt)continue;
        Class tgt=m?object_getClass(cls):cls;
        MSHookMessageEx(tgt,sel,h,o);
        if(*o){_empCount++;return;}
    }
}
static void WAGREmpInstall(void){
    if(_empInstalled)return;
    NSArray*names=@[@"WAABProperties",@"WAUserContext",@"WAAccountInfo",@"WAAccountManager",
                    @"WADeviceInfo",@"WAUserPreferences",@"WAEmployeeGating",@"WADebugMenuMain",
                    @"WADebugViewController",@"WASettingsViewController"];
    for(NSString*n in names){Class c=NSClassFromString(n);if(!c)continue;
        WAGRHookOnCls(c,"isMetaEmployeeOrInternalTester",(IMP)h_isMetaEmployee,(IMP*)&orig_isMetaEmployee);
        WAGRHookOnCls(c,"is_meta_employee_or_internal_tester",(IMP)h_isMetaEmployeeSnake,(IMP*)&orig_isMetaEmployeeSnake);
        WAGRHookOnCls(c,"isInternalUser",(IMP)h_isInternalUser,(IMP*)&orig_isInternalUser);
        WAGRHookOnCls(c,"graphQLEmployeeC1Disabled",(IMP)h_graphQLEmpC1,(IMP*)&orig_graphQLEmpC1);
    }
    unsigned int total=0;Class*all=objc_copyClassList(&total);
    if(all){for(unsigned int i=0;i<total;i++){NSString*n=NSStringFromClass(all[i]);
        if(![n containsString:@"WA"]&&![n containsString:@"Debug"]&&![n containsString:@"Employee"])continue;
        WAGRHookOnCls(all[i],"isMetaEmployeeOrInternalTester",(IMP)h_isMetaEmployee,(IMP*)&orig_isMetaEmployee);
        WAGRHookOnCls(all[i],"is_meta_employee_or_internal_tester",(IMP)h_isMetaEmployeeSnake,(IMP*)&orig_isMetaEmployeeSnake);
        WAGRHookOnCls(all[i],"isInternalUser",(IMP)h_isInternalUser,(IMP*)&orig_isInternalUser);
        WAGRHookOnCls(all[i],"graphQLEmployeeC1Disabled",(IMP)h_graphQLEmpC1,(IMP*)&orig_graphQLEmpC1);
        if(orig_isMetaEmployee&&orig_isMetaEmployeeSnake&&orig_isInternalUser&&orig_graphQLEmpC1)break;
    }free(all);}
    _empInstalled=(orig_isMetaEmployee&&orig_isMetaEmployeeSnake&&orig_isInternalUser&&orig_graphQLEmpC1);
    NSLog(@"[WAGram][Emp] installed=%@ count=%lu",_empInstalled?@"YES":@"NO",(unsigned long)_empCount);
}
__attribute__((constructor)) static void WAGREmpCtor(void){@autoreleasepool{
    double d[]={0.2,1.0,3.0,6.0};
    for(int i=0;i<4;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(d[i]*NSEC_PER_SEC)),dispatch_get_main_queue(),^{WAGREmpInstall();});
}}
extern "C" void WAGRDogfoodEnsureHooksInstalled(void){WAGREmpInstall();}
extern "C" NSString *WAGRDogfoodDiagnosticText(void){
    return [NSString stringWithFormat:@"master=%@\nhooked=%lu\ninstMetaEmp=%@\ninstInternalUser=%@\ninstC1=%@",
        WAGRPref(kWAGREmployeeMaster)?@"ON":@"OFF",(unsigned long)_empCount,
        orig_isMetaEmployee?@"YES":@"NO",orig_isInternalUser?@"YES":@"NO",orig_graphQLEmpC1?@"YES":@"NO"];
}
