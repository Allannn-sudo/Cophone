#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "../menu/MenuIPC.h"
// Explicit interface verified on net.iosipa.oldbili 2.0.6. Never invoke selectors
// supplied by the model, share a navigation controller, or make a visible window.
@interface CophoneSearchController:UIViewController
@property(nonatomic,strong) NSString *searchKeyword;
@property(nonatomic,strong) UISearchBar *searchBar;
@property(nonatomic,strong) NSArray *searchEnd;
@property(nonatomic,strong) UITableView *searchTableToEnd;
@property(nonatomic,strong) UIActivityIndicatorView *activityIndicator;
- (void)searchForKeyword;
@end
static NSDictionary *readJSON(NSString *p){NSData *d=[NSData dataWithContentsOfFile:p];if(!d.length || d.length>128*1024)return @{};id v=[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];return [v isKindOfClass:NSDictionary.class]?v:@{};}
static BOOL writeJSON(NSDictionary *v,NSString *p){NSData *d=[NSJSONSerialization dataWithJSONObject:v options:0 error:NULL];if(!d || d.length>128*1024)return NO;BOOL ok=[d writeToFile:p atomically:YES];if(ok)[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:p error:NULL];return ok;}
static NSString *text(id v,NSUInteger n){if([v isKindOfClass:NSNumber.class])v=[v stringValue];if(![v isKindOfClass:NSString.class])return @"";v=[v stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if([v length]>n)v=[v substringWithRange:[v rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,n)]];return v;}
static BOOL methodIs(Class cls,NSString *name,NSString *encoding){Method m=class_getInstanceMethod(cls,NSSelectorFromString(name));return m && [[NSString stringWithUTF8String:method_getTypeEncoding(m)] isEqual:encoding];}
@interface CophoneOldbiliAdapter:NSObject
@property(nonatomic,strong) NSString *folder,*session,*commandID,*status,*error,*query,*appSession;
@property(nonatomic,strong) NSArray *selected;
@property(nonatomic,strong) CophoneSearchController *search;
@property(nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property(nonatomic) NSTimeInterval onlineAt,startedAt;
@property(nonatomic) BOOL checkingOnline;
@property(nonatomic) NSUInteger frameSequence;
@property(nonatomic) NSTimeInterval capturedAt;
@property(nonatomic,strong) NSString *renderedCommand;
@end
@implementation CophoneOldbiliAdapter
- (NSString *)path:(NSString *)name{return [self.folder stringByAppendingPathComponent:name];}
- (void)refreshOnline {
 if(self.checkingOnline)return;self.checkingOnline=YES;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSDictionary *s=CophoneMenuRequest(@"/v1/status",nil);dispatch_async(dispatch_get_main_queue(),^{self.checkingOnline=NO;if([s[@"agentOnline"] boolValue] && [s[@"appSession"] isKindOfClass:NSString.class]){self.onlineAt=NSDate.date.timeIntervalSince1970;self.appSession=s[@"appSession"];}else {self.onlineAt=0;self.appSession=nil;}});});
}
- (void)background {
 [self refreshOnline];if(NSDate.date.timeIntervalSince1970-self.onlineAt>3)return;if(self.backgroundTask!=UIBackgroundTaskInvalid)return;
 self.backgroundTask=[UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{self.status=@"expired";self.error=@"oldbili 的本轮后台时间已用完，请重新打开后继续。";self.search=nil;[self publish];[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}];
}
- (void)active {if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}[self refreshOnline];[self publish];}
- (NSArray *)results {
 NSMutableArray *rows=[NSMutableArray array];id array=self.search.searchEnd;
 if(![array isKindOfClass:NSArray.class])return rows;
 for(id item in array){if(rows.count>=10)break;if(![item isKindOfClass:NSDictionary.class])continue;
  NSString *bvid=text(item[@"bvid"],32);if(self.selected && ![self.selected containsObject:bvid])continue;NSString *title=text(item[@"title"],180);if(!title.length || [bvid rangeOfString:@"^BV[A-Za-z0-9]{4,30}$" options:NSRegularExpressionSearch].location==NSNotFound)continue;
  title=[title stringByReplacingOccurrencesOfString:@"<[^>]+>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0,title.length)];
  [rows addObject:@{@"videoID":bvid,@"title":title,@"author":text(item[@"author"],80),@"duration":text(item[@"duration"],30),@"play":text(item[@"play"],30),@"description":text(item[@"description"],self.selected?1200:350)}];
 }return rows;
}
- (BOOL)popupVisible {
 NSMutableArray *todo=[NSMutableArray array];for(UIWindow *w in UIApplication.sharedApplication.windows)if(!w.hidden)[todo addObject:w];NSUInteger count=0;while(todo.count && count++<256){UIView *v=[todo lastObject];[todo removeLastObject];if([v isKindOfClass:UIAlertView.class] && [(UIAlertView *)v isVisible])return YES;for(UIView *child in v.subviews)if(!child.hidden)[todo addObject:child];}return NO;
}
- (void)captureFrame {
 // Render only our detached controller, never UIApplication windows/front screen.
 if(NSDate.date.timeIntervalSince1970-self.capturedAt<0.8)return;
 self.capturedAt=NSDate.date.timeIntervalSince1970;
 if(!self.search || self.search.view.window || UIApplication.sharedApplication.applicationState!=UIApplicationStateBackground || NSDate.date.timeIntervalSince1970-self.onlineAt>3)return;
 @try {
  UIView *view=self.search.view;view.frame=CGRectMake(0,0,320,460);[view setNeedsLayout];[view layoutIfNeeded];
  UITableView *table=nil;
  if(methodIs(self.search.class,@"searchTableToEnd",@"@8@0:4"))table=self.search.searchTableToEnd;
  if(table && ![self.renderedCommand isEqual:self.commandID]) {
   [table reloadData];[table layoutIfNeeded];
   if(self.selected.count) {NSArray *raw=self.search.searchEnd;NSUInteger index=0;for(id row in raw){if([row isKindOfClass:NSDictionary.class] && [self.selected containsObject:row[@"bvid"]] && table.numberOfSections>0 && index<(NSUInteger)[table numberOfRowsInSection:0]){[table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];break;}index++;}}
   self.renderedCommand=self.commandID;
  }
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(320,460),YES,1);
  CGContextRef context=UIGraphicsGetCurrentContext();if(!context){UIGraphicsEndImageContext();return;}
  [[UIColor whiteColor] setFill];UIRectFill(CGRectMake(0,0,320,460));[view.layer renderInContext:context];
  UIImage *image=UIGraphicsGetImageFromCurrentImageContext();NSData *png=UIImagePNGRepresentation(image);UIGraphicsEndImageContext();
  if(png.length && png.length<512*1024 && [png writeToFile:[self path:@"frame.png"] atomically:YES]) {
   [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:[self path:@"frame.png"] error:NULL];
   writeJSON(@{@"sequence":@(++self.frameSequence),@"capturedAt":@(NSDate.date.timeIntervalSince1970),@"command":self.commandID ?: @"",@"query":self.query ?: @"",@"status":self.status ?: @"",@"controller":NSStringFromClass(self.search.class),@"bundle":NSBundle.mainBundle.bundleIdentifier,@"source":@"UIView.layer.renderInContext",@"detached":@(view.window==nil),@"width":@320,@"height":@460,@"selected":self.selected ?: @[],@"resultCount":@([self results].count)},[self path:@"frame.json"]);
  }
 }@catch(NSException *e){/* Missing frame never changes execution or claims success. */}
}
- (void)publish {
 UIApplication *app=UIApplication.sharedApplication;NSArray *rows=[self results];
 if([self.status isEqual:@"loading"] && rows.count)self.status=@"results";
 if([self.status isEqual:@"loading"] && NSDate.date.timeIntervalSince1970-self.startedAt>25){self.status=@"timeout";self.error=@"真实搜索页面在 25 秒内未返回可识别结果。";}
 NSMutableDictionary *v=[@{@"protocol":@2,@"bundle":NSBundle.mainBundle.bundleIdentifier,@"version":NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"",@"session":self.session,@"heartbeat":@(NSDate.date.timeIntervalSince1970),@"active":@(app.applicationState==UIApplicationStateActive),@"backgroundRemaining":@(MAX(0,MIN(180,app.backgroundTimeRemaining))),@"status":self.status ?: @"ready",@"command":self.commandID ?: @"",@"query":self.query ?: @"",@"results":rows,@"controller":self.search?NSStringFromClass(self.search.class):@"",@"loading":@(self.search.activityIndicator.isAnimating),@"popup":@([self popupVisible])} mutableCopy];
 if(self.error)v[@"error"]=self.error;
 // Shape metadata helps diagnose an incompatible App update; never dump raw rows.
 id raw=self.search.searchEnd;if([raw isKindOfClass:NSArray.class] && [raw count]){id first=raw[0];v[@"resultClass"]=NSStringFromClass([first class]);if([first isKindOfClass:NSDictionary.class]){NSMutableArray *keys=[NSMutableArray array];for(id key in first)if([key isKindOfClass:NSString.class] && [key rangeOfString:@"^[A-Za-z_][A-Za-z0-9_]{0,39}$" options:NSRegularExpressionSearch].location!=NSNotFound)[keys addObject:key];v[@"resultKeys"]=keys;}}
 writeJSON(v,[self path:@"state.json"]);
 [self captureFrame];
}
- (void)tick {
 [self refreshOnline];NSDictionary *c=readJSON([self path:@"command.json"]);NSTimeInterval now=NSDate.date.timeIntervalSince1970;
 NSString *identifier=c[@"id"];BOOL valid=[identifier isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:identifier] && [c[@"session"] isEqual:self.session] && [c[@"issuedAt"] isKindOfClass:NSNumber.class] && fabs(now-[c[@"issuedAt"] doubleValue])<30;
 if(valid && ![identifier isEqual:self.commandID] && UIApplication.sharedApplication.applicationState==UIApplicationStateBackground && now-self.onlineAt<3 && [c[@"appSession"] isEqual:self.appSession]) {
  self.commandID=identifier;self.error=nil;
  if([c[@"action"] isEqual:@"release"] && c.count==5){self.search=nil;self.selected=nil;self.status=@"released";[self publish];if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}}
  else if([self popupVisible]){self.status=@"blocked_popup";self.error=@"oldbili 有待处理弹窗，未自动确认；请先手动处理后重新交办。";}
  else if([c[@"action"] isEqual:@"read"]) {
   id ids=c[@"ids"];NSMutableSet *available=[NSMutableSet set];self.selected=nil;for(NSDictionary *r in [self results])[available addObject:r[@"videoID"]];
   if(c.count==6 && [ids isKindOfClass:NSArray.class] && [ids count]>=2 && [ids count]<=3 && [NSSet setWithArray:ids].count==[ids count] && [[NSSet setWithArray:ids] isSubsetOfSet:available]) {self.selected=ids;self.status=@"inspected";}else {self.status=@"rejected";self.error=@"候选已经变化或不在真实搜索结果中，未继续读取。";}
  }
  else if(c.count!=6 || ![c[@"action"] isEqual:@"search"] || ![c[@"query"] isKindOfClass:NSString.class] || ![c[@"query"] length] || [c[@"query"] length]>80){self.status=@"rejected";self.error=@"搜索命令格式不受支持。";}
  else {
   Class cls=NSClassFromString(@"SearchViewController");
   if(!methodIs(cls,@"searchForKeyword",@"v8@0:4") || !methodIs(cls,@"setSearchKeyword:",@"v12@0:4@8") || !methodIs(cls,@"searchEnd",@"@8@0:4")){self.status=@"unsupported";self.error=@"oldbili 接口签名不匹配，未执行操作。";}
   else {@try {
    self.selected=nil;self.search=[cls new];(void)self.search.view;self.query=c[@"query"];self.search.searchKeyword=self.query;self.search.searchBar.text=self.query;
    self.startedAt=now;self.status=@"loading";[self.search searchForKeyword];
   }@catch(NSException *e){self.status=@"failed";self.error=@"真实 App 搜索接口未能执行；未切换前台。";self.search=nil;}}
  }
 }
 if(now-self.onlineAt>3 && self.search){self.search=nil;self.status=@"offline";self.error=@"cophone 已下线，停止后续 App 操作。";[self publish];if(self.backgroundTask!=UIBackgroundTaskInvalid){[UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}}
 [self publish];
}
- (void)start {
 self.session=NSUUID.UUID.UUIDString;self.status=@"ready";self.backgroundTask=UIBackgroundTaskInvalid;
 self.folder=[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) objectAtIndex:0] stringByAppendingPathComponent:@"Caches/cophone-agent"];
 [NSFileManager.defaultManager createDirectoryAtPath:self.folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(active) name:UIApplicationDidBecomeActiveNotification object:nil];
 [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];[self refreshOnline];[self publish];
}
@end
static CophoneOldbiliAdapter *adapter;
__attribute__((constructor)) static void startAdapter(void){@autoreleasepool {
 if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"net.iosipa.oldbili"] || ![NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] isEqual:@"2.0.6"])return;
 dispatch_async(dispatch_get_main_queue(),^{adapter=[CophoneOldbiliAdapter new];[adapter start];});
}}
