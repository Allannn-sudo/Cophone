#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "NotesWriter.h"
@interface NSObject (CheckNotes)
- (NSString *)rootDirectory;
- (NSManagedObjectModel *)managedObjectModel;
+ (NSArray *)scheduledLocalNotificationsForBundleIdentifier:(NSString *)identifier;
+ (void)scheduleLocalNotification:(UILocalNotification *)notification bundleIdentifier:(NSString *)identifier waitUntilDone:(BOOL)wait;
@end
int main(int argc,char **argv) {@autoreleasepool {
    NSString *mode=argc>1?[NSString stringWithUTF8String:argv[1]]:@"--metadata";
    if([mode isEqual:@"--notification-symbols"]) {
        NSData *binary=[NSData dataWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/SpringBoard"];
        const unsigned char *bytes=binary.bytes;NSUInteger start=0,printed=0;
        for(NSUInteger i=0;i<binary.length && printed<100;i++) {
            if(bytes[i]>=32 && bytes[i]<=126)continue;
            if(i-start>=8 && i-start<300) {
                NSString *s=[[NSString alloc] initWithBytes:bytes+start length:i-start encoding:NSASCIIStringEncoding];
                NSString *lower=s.lowercaseString;
                if(([s hasPrefix:@"com.apple."] && ([lower rangeOfString:@"notif"].location!=NSNotFound || [lower rangeOfString:@"springboard"].location!=NSNotFound)) || ([lower rangeOfString:@"localnotif"].location!=NSNotFound && [lower rangeOfString:@"entitle"].location!=NSNotFound)) {puts(s.UTF8String);printed++;}
            }
            start=i+1;
        }
        printf("SYMBOL_SCAN_BYTES %lu\n",(unsigned long)binary.length);return 0;
    }
    if([mode isEqual:@"--notification-inspect"]) {
        dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
        Class cls=NSClassFromString(@"SBSLocalNotificationClient");
        printf("NOW %.3f\n",[[NSDate date] timeIntervalSince1970]);
        if([cls respondsToSelector:@selector(scheduledLocalNotificationsForBundleIdentifier:)]) {
            NSArray *pending=[cls scheduledLocalNotificationsForBundleIdentifier:@"ai.whaletech.cophone.classic"];
            printf("OWN_PENDING %lu\n",(unsigned long)pending.count);
            for(UILocalNotification *n in pending)printf("OWN_FIRE %.3f BODY %s\n",n.fireDate.timeIntervalSince1970,n.alertBody.UTF8String);
        }
        NSDictionary *settings=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/BulletinBoard/SectionInfo.plist"];
        id own=settings[@"ai.whaletech.cophone.classic"];
        printf("OWN_SECTION_TYPE %s\n",own?class_getName([own class]):"absent");
        if([own isKindOfClass:[NSDictionary class]])printf("OWN_SECTION %s\n",[own description].UTF8String);
        return 0;
    }
    if([mode isEqual:@"--write-test"]) {
        NSError *error=nil;
        NSDictionary *receipt=WriteReviewNote(@"26B92A43-B817-4F48-AEF4-04D0C0F04000",@"CoPhone 写入验证\n这是一条兼容性测试备忘录，由 CoPhone 的 iOS 6 内部 Notes 接口创建。\n它不包含浏览历史或其他备忘录内容。\n如果看到这条记录，说明本机备忘录写入链路已跑通。",&error);
        NSData *json=[NSJSONSerialization dataWithJSONObject:receipt ?: @{@"error":error.localizedDescription ?: @"unknown"} options:NSJSONWritingPrettyPrinted error:NULL];
        puts([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);return receipt?0:1;
    }
    if([mode isEqual:@"--notification-test"] || [mode isEqual:@"--notification-delayed-test"]) {
        void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
        CFStringRef (*front)(void)=dlsym(sbs,"SBSCopyFrontmostApplicationDisplayIdentifier");
        mach_port_t (*port)(void)=dlsym(sbs,"SBSSpringBoardServerPort");
        void (*lock)(mach_port_t,BOOL *,BOOL *)=dlsym(sbs,"SBGetScreenLockStatus");
        BOOL locked=YES,passcode=YES;if(port && lock)lock(port(),&locked,&passcode);
        NSString *current=front?CFBridgingRelease(front()):@"unknown";
        if(locked || (current.length && ![current isEqual:@"com.apple.springboard"])) {puts("NOT_ON_DESKTOP_SKIP");return 2;}
        if([mode isEqual:@"--notification-delayed-test"]) {
            void *security=dlopen("/System/Library/Frameworks/Security.framework/Security",RTLD_NOW);
            CFTypeRef (*taskCreate)(CFAllocatorRef)=dlsym(security,"SecTaskCreateFromSelf");
            CFTypeRef (*entitlement)(CFTypeRef,CFStringRef,CFErrorRef *)=dlsym(security,"SecTaskCopyValueForEntitlement");
            CFTypeRef task=taskCreate?taskCreate(NULL):NULL;
            CFTypeRef value=task && entitlement?entitlement(task,CFSTR("com.apple.localnotification.schedulingproxy"),NULL):NULL;
            NSString *description=value?CFBridgingRelease(CFCopyDescription(value)):@"unavailable";
            printf("SELF_PROXY_ENTITLEMENT %s\n",description.UTF8String);
            if(value)CFRelease(value);if(task)CFRelease(task);
            Class cls=NSClassFromString(@"SBSLocalNotificationClient");
            UILocalNotification *n=[[UILocalNotification alloc] init];n.fireDate=[NSDate dateWithTimeIntervalSinceNow:8];
            n.alertBody=@"CoPhone 通知测试：系统备忘录写入已验证。";n.alertAction=@"查看";n.applicationIconBadgeNumber=1;
            [cls scheduleLocalNotification:n bundleIdentifier:@"ai.whaletech.cophone.classic" waitUntilDone:YES];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
            printf("DELAYED_OWN_PENDING %lu\n",(unsigned long)[cls scheduledLocalNotificationsForBundleIdentifier:@"ai.whaletech.cophone.classic"].count);fflush(stdout);
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:10]];return 0;
        }
        NSError *error=nil;BOOL okay=SendReviewNotification(&error);puts(okay?"NOTIFICATION_SUBMITTED":error.localizedDescription.UTF8String);return okay?0:1;
    }
    dlopen("/System/Library/PrivateFrameworks/Notes.framework/Notes",RTLD_NOW);
    id context=[[NSClassFromString(@"NoteContext") alloc] init];
    printf("HOME %s ROOT %s\n",NSHomeDirectory().UTF8String,[context rootDirectory].UTF8String);
    for(NSEntityDescription *entity in [context managedObjectModel].entities)
        printf("ENTITY %s %s\n",entity.name.UTF8String,[entity.propertiesByName.allKeys.description UTF8String]);
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:@"/Applications/MobileNotes.app/Info.plist"];
    printf("NOTES_URL_SCHEMES %s\n",[[info objectForKey:@"CFBundleURLTypes"] description].UTF8String);
 }return 0;}
