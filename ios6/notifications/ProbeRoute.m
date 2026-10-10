// Validate actual iOS 6 action mutation in this process, without publishing or launching.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "ScopedRoute.h"
@interface NSObject(CophoneProbeRoute)
+ (id)actionWithLaunchBundleID:(NSString *)bundle callblock:(id)block;
+ (id)launchActionWithBundleID:(NSString *)bundle callblock:(id)block;
- (NSString *)launchBundleID;
- (NSString *)bundleID;
- (void)setLaunchBundleID:(NSString *)bundle;
- (BOOL)canBypassPinLock;
- (id)defaultAction;
- (void)setDefaultAction:(id)action;
@end
int main(){@autoreleasepool {
 dlopen("/System/Library/PrivateFrameworks/BulletinBoard.framework/BulletinBoard",RTLD_NOW);
 dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 Class cls=NSClassFromString(@"BBAction"),bcls=NSClassFromString(@"BBBulletinRequest");if(!cls || !bcls)return 2;
 NSMutableDictionary *out=[NSMutableDictionary dictionary];
 NSMutableArray *methods=[NSMutableArray array];Class launch=NSClassFromString(@"BBLaunchAction");
 for(int kind=0;kind<2;kind++){unsigned n=0;Method *ms=class_copyMethodList(kind?object_getClass(launch):launch,&n);for(unsigned i=0;i<n;i++)[methods addObject:@{@"selector":NSStringFromSelector(method_getName(ms[i])),@"encoding":[NSString stringWithUTF8String:method_getTypeEncoding(ms[i])],@"classMethod":@(kind)}];free(ms);}out[@"launchActionMethods"]=methods;
 id previous=CophonePushRouteScope(@"com.apple.mobilenotes");id fresh=nil;
 @try{NSString *target=CophoneScopedLaunchTarget(@"ai.whaletech.cophone.classic",NSThread.currentThread.threadDictionary[CophoneRouteScopeKey]);fresh=[launch launchActionWithBundleID:target callblock:nil];}@finally{CophonePopRouteScope(previous);}
 out[@"freshLaunchTarget"]=fresh?[fresh bundleID]:@"";out[@"scopeCleared"]=@(!NSThread.currentThread.threadDictionary[CophoneRouteScopeKey]);
 for(NSString *name in @[@"launchBundleID",@"setLaunchBundleID:"]) {Method m=class_getInstanceMethod(cls,NSSelectorFromString(name));if(!m)return 3;out[name]=[NSString stringWithUTF8String:method_getTypeEncoding(m)];}
 id action=[cls actionWithLaunchBundleID:@"ai.whaletech.cophone.classic" callblock:nil];id bulletin=[bcls new];[bulletin setDefaultAction:action];BOOL lockBefore=[action canBypassPinLock];
 [action setLaunchBundleID:@"com.apple.mobilenotes"];
 out[@"sameAction"]=@([bulletin defaultAction]==action);out[@"bundleIDAfterChange"]=[action bundleID] ?: @"";out[@"notesTarget"]=@([[action launchBundleID] isEqual:@"com.apple.mobilenotes"]);
 [action setLaunchBundleID:@"com.apple.mobileslideshow"];out[@"photosTarget"]=@([[action launchBundleID] isEqual:@"com.apple.mobileslideshow"]);out[@"lockPolicyPreserved"]=@(lockBefore==[action canBypassPinLock]);
 NSString *__unsafe_unretained *key=(NSString *__unsafe_unretained *)dlsym(RTLD_DEFAULT,"SBSPushStoreUserInfoKey");out[@"userInfoKeyResolved"]=@(key && [*key isKindOfClass:NSString.class]);
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
 }return 0;}
