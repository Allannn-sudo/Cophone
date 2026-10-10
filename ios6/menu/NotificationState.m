#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../review/NotesWriter.h"
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
int main(int argc,char **argv){@autoreleasepool {
    if(argc>1 && [[NSString stringWithUTF8String:argv[1]] isEqual:@"--banner-test"]){NSError *error=nil;BOOL sent=SendTaskProgressNotification(@"通知测试：正在整理提示，不会调用 AI。",&error);printf("OWN_TEST_NOTIFICATION submitted=%d\n",sent);return sent?0:1;}
    dlopen("/System/Library/PrivateFrameworks/BulletinBoard.framework/BulletinBoard",RTLD_NOW);
    dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
    printf("UI_LOCAL_CLASS available=%d\n",NSClassFromString(@"UILocalNotification")!=nil);
    NSDictionary *settings=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/BulletinBoard/SectionInfo.plist"];
    printf("SETTINGS_ROOT count=%lu archive=%d\n",(unsigned long)settings.count,settings[@"$archiver"]!=nil);
    if(settings[@"$archiver"]){@try {settings=[NSKeyedUnarchiver unarchiveObjectWithFile:@"/var/mobile/Library/BulletinBoard/SectionInfo.plist"];} @catch(NSException *e){settings=nil;}}
    for(id key in settings)if([key isKindOfClass:NSString.class] && [key rangeOfString:@"cophone" options:NSCaseInsensitiveSearch].location!=NSNotFound)printf("OWN_RELATED_SECTION key=%s type=%s\n",[key UTF8String],class_getName([settings[key] class]));
    printf("SETTINGS_DECODED type=%s\n",settings?class_getName([settings class]):"absent");
    id own=[settings isKindOfClass:NSDictionary.class]?settings[@"ai.whaletech.cophone.classic"]:nil;
    if(!own && [settings isKindOfClass:NSDictionary.class])for(id v in settings.allValues)if([v isKindOfClass:NSDictionary.class] && v[@"ai.whaletech.cophone.classic"])own=v[@"ai.whaletech.cophone.classic"];
    printf("OWN_NOTIFICATION_SETTINGS type=%s\n",own?class_getName([own class]):"absent");
    if([own isKindOfClass:NSData.class]){@try {own=[NSKeyedUnarchiver unarchiveObjectWithData:own];} @catch(NSException *e){own=nil;}}
    printf("OWN_NOTIFICATION_DECODED type=%s\n",own?class_getName([own class]):"absent");
    for(NSString *key in @[@"alertType",@"allowsNotifications",@"pushSettings",@"notificationTypes",@"enabled",@"enabledForAlerts",@"showsInNotificationCenter",@"showsInLockScreen",@"suppressesAlerts",@"showsMessagePreview"]){
      @try {id v=[own valueForKey:key];if([v isKindOfClass:NSNumber.class])printf("OWN_SETTING %s=%s\n",key.UTF8String,[v description].UTF8String);} @catch(NSException *e){}
    }
    (void)[UILocalNotification new];
    Class cls=NSClassFromString(@"SBSLocalNotificationClient");printf("NOTIFICATION_CLIENT available=%d\n",cls!=nil);unsigned int count=0;Method *methods=class_copyMethodList(object_getClass(cls),&count);
    for(unsigned int i=0;i<count;i++){NSString *name=NSStringFromSelector(method_getName(methods[i]));if([name.lowercaseString rangeOfString:@"type"].location!=NSNotFound || [name.lowercaseString rangeOfString:@"present"].location!=NSNotFound)printf("NOTIFICATION_METHOD %s %s\n",name.UTF8String,method_getTypeEncoding(methods[i]));}free(methods);
    CFStringRef (*front)(void)=dlsym(RTLD_DEFAULT,"SBSCopyFrontmostApplicationDisplayIdentifier");NSString *f=front?CFBridgingRelease(front()):nil;printf("FOREGROUND safari=%d cophone=%d desktop=%d\n",[f isEqual:@"com.apple.mobilesafari"],[f isEqual:@"ai.whaletech.cophone.classic"],[f isEqual:@"com.apple.springboard"]);
}return 0;}
