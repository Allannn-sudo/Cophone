// Explicit one-shot experiment. No foreground launch fallback, AI or UI input.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <unistd.h>
#import <objc/runtime.h>
@interface CophoneAssertion:NSObject
- (id)initWithBundleIdentifier:(NSString *)bundle flags:(unsigned)flags reason:(unsigned)reason name:(NSString *)name withHandler:(void(^)(BOOL))handler;
- (void)invalidate;
- (BOOL)valid;
@end
#import "../src/TaskInbox.h"
static NSDictionary *oldbiliState(void){NSFileManager *fm=NSFileManager.defaultManager;NSString *base=@"/var/mobile/Applications";for(NSString *d in [fm contentsOfDirectoryAtPath:base error:NULL]){NSString *folder=[base stringByAppendingPathComponent:d];for(NSString *app in [fm contentsOfDirectoryAtPath:folder error:NULL])if([app hasSuffix:@".app"]){NSDictionary *i=[NSDictionary dictionaryWithContentsOfFile:[[folder stringByAppendingPathComponent:app] stringByAppendingPathComponent:@"Info.plist"]];if([i[@"CFBundleIdentifier"] isEqual:@"net.iosipa.oldbili"])return CophoneTaskJSON([folder stringByAppendingPathComponent:@"Library/Caches/cophone-agent/state.json"]);}}return @{};}
int main(){@autoreleasepool {
 void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 CFStringRef (*front)(void)=dlsym(sbs,"SBSCopyFrontmostApplicationDisplayIdentifier");
 mach_port_t (*port)(void)=dlsym(sbs,"SBSSpringBoardServerPort");void (*lock)(mach_port_t,BOOL *,BOOL *)=dlsym(sbs,"SBGetScreenLockStatus");
 int (*launch)(CFStringRef,BOOL)=dlsym(sbs,"SBSLaunchApplicationWithIdentifier");
 BOOL locked=YES,passcode=YES;if(port && lock)lock(port(),&locked,&passcode);
 NSString *before=front?CFBridgingRelease(front()):nil;
 if(locked || ![before isEqual:@"com.apple.mobilesafari"] || !CophoneAppSession(CophoneDocuments()) || !launch){puts("PROBE_NOT_READY_NO_LAUNCH");return 2;}
 dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",RTLD_NOW);Class cls=NSClassFromString(@"BKSProcessAssertion");Method m=class_getInstanceMethod(cls,@selector(initWithBundleIdentifier:flags:reason:name:withHandler:));
 if(!m || ![[NSString stringWithUTF8String:method_getTypeEncoding(m)] isEqual:@"@28@0:4@8I12I16@20@?24"]){puts("NO_ASSERTION_ABI");return 3;}
 int code=launch(CFSTR("net.iosipa.oldbili"),YES);__block BOOL acquired=NO;
 CophoneAssertion *assertion=[[cls alloc] initWithBundleIdentifier:@"net.iosipa.oldbili" flags:1 reason:4 name:@"cophone 5-second background probe" withHandler:^(BOOL ok){acquired=ok;}];BOOL unchanged=YES;NSMutableSet *observed=[NSMutableSet set];
 for(unsigned i=0;i<50;i++){NSString *f=CFBridgingRelease(front());if(f)[observed addObject:f];if(![f isEqual:before])unchanged=NO;[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];}
 NSDictionary *bridge=oldbiliState();BOOL valid=assertion.valid;[assertion invalidate];NSDictionary *v=@{@"adapterAge":@(NSDate.date.timeIntervalSince1970-[bridge[@"heartbeat"] doubleValue]),@"adapterActive":bridge[@"active"] ?: @NO,@"adapterStatus":bridge[@"status"] ?: @"",@"assertionAcquired":@(acquired),@"assertionWasValid":@(valid),@"assertionReleased":@YES,@"suspendedArgument":@YES,@"returnCode":@(code),@"frontBefore":before,@"frontUnchanged":@(unchanged),@"frontObserved":observed.allObjects};
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:v options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
