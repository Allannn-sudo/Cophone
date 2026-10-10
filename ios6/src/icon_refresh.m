#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <notify.h>

// Optional installer utility, never used by the demo's task execution.
// Check availability at runtime because these private methods vary by iOS.
@interface NSObject (CoPhoneIconRefresh)
+ (id)defaultWorkspace;
- (BOOL)invalidateIconCache:(NSString *)identifier;
@end

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSString *identifier=@"ai.whaletech.cophone.legacy";
        for(NSString *file in @[@"Icon.png",@"Icon@2x.png",@"Icon-Small.png",@"Icon-Small@2x.png"]) {
            UIImage *image=[UIImage imageWithContentsOfFile:[@"/Applications/CoPhone.app" stringByAppendingPathComponent:file]];
            printf("%s decode=%s points=%.0fx%.0f scale=%.0f\n",[file UTF8String],
                image ? "ok" : "failed",(double)image.size.width,(double)image.size.height,(double)image.scale);
            if(!image)return 4;
        }
        Class cls=NSClassFromString(@"LSApplicationWorkspace");
        if(!cls || ![cls respondsToSelector:@selector(defaultWorkspace)]) {
            puts("COPHONE_ICON_REFRESH_UNAVAILABLE: workspace");return 2;
        }
        id workspace=[cls defaultWorkspace];
        if(![workspace respondsToSelector:@selector(invalidateIconCache:)]) {
            puts("COPHONE_ICON_REFRESH_UNAVAILABLE: invalidateIconCache");return 2;
        }
        if(argc!=2 || ![[NSString stringWithUTF8String:argv[1]] isEqualToString:@"--refresh"]) {
            puts("COPHONE_ICON_REFRESH_AVAILABLE");return 0;
        }
        if(![workspace invalidateIconCache:identifier]) {
            puts("COPHONE_ICON_REFRESH_REJECTED");return 3;
        }
        notify_post("com.apple.mobile.application_installed");
        puts("COPHONE_ICON_REFRESH_REQUESTED");
        return 0;
    }
}
