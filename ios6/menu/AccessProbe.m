#import <Foundation/Foundation.h>
#import <notify.h>
__attribute__((constructor)) static void checkAccess(void) {@autoreleasepool {
    uint64_t flags=1;NSString *base=@"/var/mobile/Applications";NSFileManager *fm=[NSFileManager defaultManager];
    for(NSString *item in [fm contentsOfDirectoryAtPath:base error:NULL]) {
        NSString *folder=[base stringByAppendingPathComponent:item];NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[folder stringByAppendingPathComponent:@"CoPhone.app/Info.plist"]];
        if(![info[@"CFBundleIdentifier"] isEqual:@"ai.whaletech.cophone.classic"])continue;
        flags|=2;NSString *documents=[folder stringByAppendingPathComponent:@"Documents"];
        if([NSData dataWithContentsOfFile:[documents stringByAppendingPathComponent:@"review-state.json"]])flags|=4;
        NSString *path=[documents stringByAppendingPathComponent:@".menu-access-check"];
        if([@"cophone access test" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL]){flags|=8;[fm removeItemAtPath:path error:NULL];}
    }
    int token;notify_register_check("ai.whaletech.cophone.menu.access",&token);notify_set_state(token,flags);notify_post("ai.whaletech.cophone.menu.access");notify_cancel(token);
}}
