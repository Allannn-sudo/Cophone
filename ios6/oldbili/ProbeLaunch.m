// Explicit one-shot experiment. No foreground launch fallback, AI or UI input.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <unistd.h>
#import "../src/TaskInbox.h"
int main(){@autoreleasepool {
 void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 CFStringRef (*front)(void)=dlsym(sbs,"SBSCopyFrontmostApplicationDisplayIdentifier");
 mach_port_t (*port)(void)=dlsym(sbs,"SBSSpringBoardServerPort");void (*lock)(mach_port_t,BOOL *,BOOL *)=dlsym(sbs,"SBGetScreenLockStatus");
 int (*launch)(CFStringRef,BOOL)=dlsym(sbs,"SBSLaunchApplicationWithIdentifier");
 BOOL locked=YES,passcode=YES;if(port && lock)lock(port(),&locked,&passcode);
 NSString *before=front?CFBridgingRelease(front()):nil;
 if(locked || ![before isEqual:@"com.apple.mobilesafari"] || !CophoneAppSession(CophoneDocuments()) || !launch){puts("PROBE_NOT_READY_NO_LAUNCH");return 2;}
 int code=launch(CFSTR("net.iosipa.oldbili"),YES);BOOL unchanged=YES;NSMutableSet *observed=[NSMutableSet set];
 for(unsigned i=0;i<50;i++){NSString *f=CFBridgingRelease(front());if(f)[observed addObject:f];if(![f isEqual:before])unchanged=NO;[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];}
 NSDictionary *v=@{@"suspendedArgument":@YES,@"returnCode":@(code),@"frontBefore":before,@"frontUnchanged":@(unchanged),@"frontObserved":observed.allObjects};
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:v options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
