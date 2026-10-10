#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <notify.h>
#import "RoutePolicy.h"
#import "../results/ResultLink.h"
// iOS 6's local-notification action ultimately ignores BBAction.launchBundleID
// and calls SBUserAgent with the bulletin. Route at that actual dispatch point.
@interface NSObject(CophoneNotificationABI)
- (NSString *)sectionID;
- (NSDictionary *)context;
- (BOOL)canLaunchFromBulletinWithURL:(id)url bundleID:(NSString *)bundle;
- (BOOL)launchFromBulletinWithURL:(id)url bundleID:(NSString *)bundle allowUnlock:(BOOL)unlock animate:(BOOL)animate launchOrigin:(int)origin;
@end
static BOOL (*originalLaunch)(id,SEL,id,int);
static NSString *contextUserInfoKey;
static BOOL installed;
static int statusToken,clickToken,resultToken;
static uint64_t matched,rewritten,exactResults;
static BOOL signature(Class cls,NSString *name,const char *encoding){Method m=class_getInstanceMethod(cls,NSSelectorFromString(name));return m && [[NSString stringWithUTF8String:method_getTypeEncoding(m)] isEqual:[NSString stringWithUTF8String:encoding]];}
static BOOL launchBulletin(id agent,SEL cmd,id bulletin,int origin){
 NSString *target=nil;NSURL *resultURL=nil;
 @try {NSDictionary *context=[bulletin context];if([context isKindOfClass:NSDictionary.class]){NSDictionary *info=context[contextUserInfoKey];target=CophoneNotificationDestination([bulletin sectionID],info);if(target)resultURL=CophoneValidatedResultURL(info[@"CoPhoneResultURL"],target);}}@catch(NSException *e){target=nil;}
 if(!target)return originalLaunch(agent,cmd,bulletin,origin);
 notify_set_state(statusToken,1|(++matched<<1));
 // Preserve the system's source/origin and unlock handling; do not set pending
 // local-notification data on Notes/Photos or deliver cophone userInfo to them.
 // These are local SBUserAgent methods, never synchronous SBS RPC to ourselves.
 if([agent canLaunchFromBulletinWithURL:resultURL bundleID:target] && [agent launchFromBulletinWithURL:resultURL bundleID:target allowUnlock:YES animate:YES launchOrigin:origin]){
  notify_set_state(clickToken,1|(++rewritten<<1));if(resultURL)notify_set_state(resultToken,1|(++exactResults<<1));return YES;
 }
 // A rejected/deleted result link must not regress to flashing cophone.
 if(resultURL && [agent canLaunchFromBulletinWithURL:nil bundleID:target] && [agent launchFromBulletinWithURL:nil bundleID:target allowUnlock:YES animate:YES launchOrigin:origin]){notify_set_state(clickToken,1|(++rewritten<<1));return YES;}
 return originalLaunch(agent,cmd,bulletin,origin);
}
static void install(void){
 if(installed)return;
 Class agent=NSClassFromString(@"SBUserAgent"),bulletin=NSClassFromString(@"BBBulletin");
 if(!signature(agent,@"launchFromPushOrLocalBulletin:origin:","c16@0:4@8i12") || !signature(agent,@"canLaunchFromBulletinWithURL:bundleID:","c16@0:4@8@12") || !signature(agent,@"launchFromBulletinWithURL:bundleID:allowUnlock:animate:launchOrigin:","c28@0:4@8@12c16c20i24") || !signature(bulletin,@"sectionID","@8@0:4") || !signature(bulletin,@"context","@8@0:4"))return;
 NSString *__unsafe_unretained *key=(NSString *__unsafe_unretained *)dlsym(RTLD_DEFAULT,"kBBBulletinContextUserInfoKey");
 void (*hook)(Class,SEL,IMP,IMP *)=dlsym(RTLD_DEFAULT,"MSHookMessageEx");if(!key || ![*key isKindOfClass:NSString.class] || !hook)return;
 contextUserInfoKey=*key;hook(agent,NSSelectorFromString(@"launchFromPushOrLocalBulletin:origin:"),(IMP)launchBulletin,(IMP *)&originalLaunch);
 installed=originalLaunch!=NULL;if(installed){notify_set_state(statusToken,1);notify_set_state(clickToken,1);notify_set_state(resultToken,1);}
}
@interface CophoneRouteLoader:NSObject
@property(nonatomic) NSUInteger attempts;
- (void)tick:(NSTimer *)timer;
@end
@implementation CophoneRouteLoader
- (void)tick:(NSTimer *)timer {install();if(installed || ++self.attempts>=40)[timer invalidate];}
@end
__attribute__((constructor)) static void initializeRoute(void){@autoreleasepool{
 if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"])return;
 notify_register_check("ai.whaletech.cophone.notification-route",&statusToken);notify_register_check("ai.whaletech.cophone.notification-click",&clickToken);
 notify_register_check("ai.whaletech.cophone.notification-result-route",&resultToken);
 dispatch_async(dispatch_get_main_queue(),^{install();if(!installed){CophoneRouteLoader *loader=[CophoneRouteLoader new];[NSTimer scheduledTimerWithTimeInterval:0.5 target:loader selector:@selector(tick:) userInfo:nil repeats:YES];}});
}}
