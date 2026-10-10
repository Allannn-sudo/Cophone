#import <Foundation/Foundation.h>
static NSString *const CophoneRouteScopeKey=@"ai.whaletech.cophone.notification-click.target";
static inline NSString *CophoneScopedLaunchTarget(id bundle,id scoped){
 if(![bundle isEqual:@"ai.whaletech.cophone.classic"])return bundle;
 return [@[@"com.apple.mobilenotes",@"com.apple.mobileslideshow"] containsObject:scoped]?scoped:bundle;
}
static inline id CophonePushRouteScope(NSString *target){
 NSMutableDictionary *thread=NSThread.currentThread.threadDictionary;id previous=thread[CophoneRouteScopeKey];
 if(target)thread[CophoneRouteScopeKey]=target;else [thread removeObjectForKey:CophoneRouteScopeKey];return previous;
}
static inline void CophonePopRouteScope(id previous){
 NSMutableDictionary *thread=NSThread.currentThread.threadDictionary;
 if(previous)thread[CophoneRouteScopeKey]=previous;else [thread removeObjectForKey:CophoneRouteScopeKey];
}
