#import <Foundation/Foundation.h>
// nil foreground is the ordinary unlocked iOS6 home screen, not a failed API.
static inline NSString *CophoneBackgroundLaunchIssue(BOOL apiReady,BOOL locked,NSString *front){
 if(!apiReady)return @"本机后台启动接口未就绪，请稍后再试。";
 if(locked)return @"手机已锁定，请解锁后再交办。";
 if([front isEqual:@"net.iosipa.oldbili"])return @"你正在使用 oldbili，未改动其页面；请切到其他应用后交办。";
 return nil;
}
