// Read only. In iOS6 an unlocked home screen may have no foreground App ID.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
int main(){@autoreleasepool {
 void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 mach_port_t (*port)(void)=dlsym(sbs,"SBSSpringBoardServerPort");void (*lock)(mach_port_t,BOOL *,BOOL *)=dlsym(sbs,"SBGetScreenLockStatus");CFStringRef (*front)(void)=dlsym(sbs,"SBSCopyFrontmostApplicationDisplayIdentifier");
 BOOL locked=YES,passcode=YES;mach_port_t server=port?port():0;if(server && lock)lock(server,&locked,&passcode);
 NSString *current=front?CFBridgingRelease(front()):nil;
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:@{@"lockAPIReady":@(server && lock),@"frontAPIReady":@(front!=NULL),@"locked":@(locked),@"front":current ?: @"",@"frontWasNil":@(current==nil)} options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
