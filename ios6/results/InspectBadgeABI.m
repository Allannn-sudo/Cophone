// Read-only native API code inspection. No badge updates or user-content access.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
static NSDictionary *code(void *pointer){if(!pointer)return @{};uintptr_t base=(uintptr_t)pointer & ~(uintptr_t)1;const unsigned char *p=(const unsigned char *)base;NSMutableString *hex=[NSMutableString string];for(NSUInteger i=0;i<256;i++)[hex appendFormat:@"%02x",p[i]];return @{@"address":@(base),@"thumb":@((uintptr_t)pointer&1),@"hex":hex};}
int main(){@autoreleasepool{void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);NSMutableDictionary *out=[NSMutableDictionary dictionary];for(NSString *name in @[@"SBSetApplicationBadgeNumber",@"SBSetApplicationBadgeString",@"SBSSpringBoardServerPort"]){void *p=dlsym(sbs,name.UTF8String);out[name]=code(p);}Method m=class_getInstanceMethod(UIApplication.class,@selector(setApplicationIconBadgeNumber:));if(m)out[@"UIApplicationSetter"]=code((void *)method_getImplementation(m));puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);}return 0;}
