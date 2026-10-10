// Read only cophone's notification context structure; no message text or keys.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
@interface NSObject(CophoneBBProbe)
- (void)setDelegate:(id)delegate;
- (void)requestListBulletinsForSectionID:(NSString *)section;
- (void)invalidate;
- (NSString *)sectionID;
- (NSDictionary *)context;
- (id)defaultAction;
- (NSString *)launchBundleID;
@end
@interface ContextProbe:NSObject
@property(nonatomic,strong) NSMutableArray *results;
@end
@implementation ContextProbe
- (void)observe:(id)b {
 if(![[b sectionID] isEqual:@"ai.whaletech.cophone.classic"])return;
 NSDictionary *context=[b context];NSMutableDictionary *types=[NSMutableDictionary dictionary];
 if([context isKindOfClass:NSDictionary.class])for(id key in context){
  if(![key isKindOfClass:NSString.class])continue;id value=context[key];
  NSMutableDictionary *shape=[@{@"class":NSStringFromClass([value class])} mutableCopy];
  if([value isKindOfClass:NSDictionary.class])shape[@"keys"]=[value allKeys];
  if([value respondsToSelector:@selector(userInfo)]){id info=[value performSelector:@selector(userInfo)];if([info isKindOfClass:NSDictionary.class])shape[@"userInfoKeys"]=[info allKeys];}
  types[key]=shape;
 }
 id action=[b defaultAction];[self.results addObject:@{@"section":@"ai.whaletech.cophone.classic",@"context":types,@"launchBundleID":[action launchBundleID] ?: @""}];
}
- (void)observer:(id)o addBulletin:(id)b forFeed:(unsigned)feed{[self observe:b];}
- (void)observer:(id)o modifyBulletin:(id)b{[self observe:b];}
@end
int main(){@autoreleasepool {
 dlopen("/System/Library/PrivateFrameworks/BulletinBoard.framework/BulletinBoard",RTLD_NOW);
 Class cls=NSClassFromString(@"BBObserver");Method m=class_getInstanceMethod(cls,@selector(requestListBulletinsForSectionID:));
 if(!m || ![[NSString stringWithUTF8String:method_getTypeEncoding(m)] isEqual:@"v12@0:4@8"])return 2;
 ContextProbe *probe=[ContextProbe new];probe.results=[NSMutableArray array];id observer=[cls new];[observer setDelegate:probe];[observer requestListBulletinsForSectionID:@"ai.whaletech.cophone.classic"];
 NSDate *until=[NSDate dateWithTimeIntervalSinceNow:5];while(until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];[observer invalidate];
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:probe.results options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
