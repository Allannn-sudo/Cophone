#import "ResultBadge.h"
#import <dlfcn.h>
#import <mach/mach.h>
static NSString *const BadgeState=@"/var/mobile/Library/CoPhoneReview/result-badges.plist";
static BOOL setBadge(NSString *bundle,NSInteger count){
 if(![@[@"ai.whaletech.cophone.classic",@"com.apple.mobilenotes",@"com.apple.mobileslideshow"] containsObject:bundle] || (count!=0 && count!=1))return NO;
 // Native iOS6 MIG ABI inspected on-device: (server port, bounded C-string
 // bundle identifier, int badge). Only called outside SpringBoard, never in its
 // notification click hook. No alert/banner, notification registration or UI.
 static void *framework=NULL;if(!framework)framework=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 mach_port_t (*port)(void)=framework?dlsym(framework,"SBSSpringBoardServerPort"):NULL;
 kern_return_t (*set)(mach_port_t,const char *,int)=framework?dlsym(framework,"SBSetApplicationBadgeNumber"):NULL;
 return port && set && set(port(),bundle.UTF8String,(int)count)==KERN_SUCCESS;
}
static void save(NSDictionary *state){[state writeToFile:BadgeState atomically:YES];[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:BadgeState error:NULL];}
BOOL CophoneMarkResultBadge(NSString *action){
 NSString *target=[action isEqual:@"open-notes"]?@"com.apple.mobilenotes":([action isEqual:@"open-photos"]?@"com.apple.mobileslideshow":nil);if(!target)return NO;
 setBadge(@"ai.whaletech.cophone.classic",0);
 if(!setBadge(target,1))return NO;
 NSMutableDictionary *state=[[NSDictionary dictionaryWithContentsOfFile:BadgeState] mutableCopy] ?: [NSMutableDictionary dictionary];state[target]=@([NSDate.date timeIntervalSince1970]+2);save(state);return YES;
}
void CophoneClearViewedResultBadge(NSString *front,BOOL unlocked){
 if(!unlocked || ![@[@"com.apple.mobilenotes",@"com.apple.mobileslideshow"] containsObject:front])return;
 NSMutableDictionary *state=[[NSDictionary dictionaryWithContentsOfFile:BadgeState] mutableCopy];id deadline=state[front];
 if(![deadline isKindOfClass:NSNumber.class] || [deadline doubleValue]>[NSDate.date timeIntervalSince1970])return;
 if(setBadge(front,0)){[state removeObjectForKey:front];save(state);}
}
