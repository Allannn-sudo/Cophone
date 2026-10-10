#import "BackgroundLease.h"
#import "BackgroundLaunchPolicy.h"
#import <objc/runtime.h>
#import <dlfcn.h>
@interface CophoneAssertionAPI:NSObject
- (id)initWithBundleIdentifier:(NSString *)bundle flags:(unsigned)flags reason:(unsigned)reason name:(NSString *)name withHandler:(void(^)(BOOL))handler;
- (BOOL)valid;
- (void)invalidate;
@end
static BOOL method(Class c,SEL s,NSString *encoding){Method m=class_getInstanceMethod(c,s);return m && [[NSString stringWithUTF8String:method_getTypeEncoding(m)] isEqual:encoding];}
static id failure(NSError **error,NSString *text){if(error)*error=[NSError errorWithDomain:@"cophone.BackgroundLease" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];return nil;}
@implementation CophoneBackgroundLease
+ (instancetype)start:(NSError **)error {
 if(!NSThread.isMainThread)return failure(error,@"后台启动必须在服务主线程调度。");
 void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 if(!sbs)return failure(error,@"本机后台启动接口未就绪，请稍后再试。");
 mach_port_t (*port)(void)=dlsym(sbs,"SBSSpringBoardServerPort");void (*lock)(mach_port_t,BOOL *,BOOL *)=dlsym(sbs,"SBGetScreenLockStatus");
 CFStringRef (*front)(void)=dlsym(sbs,"SBSCopyFrontmostApplicationDisplayIdentifier");int (*launch)(CFStringRef,BOOL)=dlsym(sbs,"SBSLaunchApplicationWithIdentifier");
 mach_port_t server=port?port():0;
 BOOL locked=YES,passcode=YES;if(server && lock)lock(server,&locked,&passcode);NSString *current=front?CFBridgingRelease(front()):nil;
 NSString *issue=CophoneBackgroundLaunchIssue(server && lock && front && launch,locked,current);
 if(issue)return failure(error,issue);
 dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",RTLD_NOW);Class cls=NSClassFromString(@"BKSProcessAssertion");
 if(!method(cls,@selector(initWithBundleIdentifier:flags:reason:name:withHandler:),@"@28@0:4@8I12I16@20@?24") || !method(cls,@selector(valid),@"c8@0:4") || !method(cls,@selector(invalidate),@"v8@0:4"))return failure(error,@"本机后台许可接口不匹配，没有尝试前台打开。");
 int result=launch(CFSTR("net.iosipa.oldbili"),YES);if(result)return failure(error,[NSString stringWithFormat:@"oldbili 静默启动未确认（%d），没有切换前台。",result]);
 CophoneBackgroundLease *lease=[self new];__weak CophoneBackgroundLease *weak=lease;
 // Own, bounded FinishTask assertion. No audio/location mode or foreground priority.
 lease.assertion=[[cls alloc] initWithBundleIdentifier:@"net.iosipa.oldbili" flags:1 reason:4 name:@"cophone confirmed video task" withHandler:^(BOOL ok){weak.acquired=ok;}];
 if(!lease.assertion)return failure(error,@"未取得 oldbili 后台执行许可。");
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(135*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[lease invalidate];});
 return lease;
}
- (BOOL)valid{return self.acquired && [(CophoneAssertionAPI *)self.assertion valid];}
- (void)invalidate {[(CophoneAssertionAPI *)self.assertion invalidate];self.assertion=nil;self.acquired=NO;}
- (void)dealloc {[(CophoneAssertionAPI *)self.assertion invalidate];}
@end
