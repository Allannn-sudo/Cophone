#import <UIKit/UIKit.h>
#import <objc/runtime.h>
static BOOL validName(NSString *s){return s.length<180 && [s rangeOfString:@"^[A-Za-z_][A-Za-z0-9_:]*$" options:NSRegularExpressionSearch].location!=NSNotFound;}
@interface CophoneOldbiliProbe:NSObject
- (void)inspect;
@end
@implementation CophoneOldbiliProbe
- (void)inspect {@autoreleasepool {
 NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
 if(![@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:bundle])return;
 NSMutableArray *classes=[NSMutableArray array];unsigned int total=0;Class *list=objc_copyClassList(&total);
 for(unsigned int i=0;i<total && classes.count<60;i++) {
  Class cls=list[i];const char *raw=class_getImageName(cls);NSString *image=raw?[NSString stringWithUTF8String:raw]:nil;
  if(![image hasPrefix:NSBundle.mainBundle.bundlePath])continue;
  NSString *name=NSStringFromClass(cls);BOOL wanted=NO;
  for(NSString *part in @[@"Search",@"Video",@"Detail",@"Favorite",@"UserCenter",@"APIClient",@"Login",@"AppDelegate",@"TabBar",@"Navigation",@"WbiSign"])if([name rangeOfString:part].location!=NSNotFound)wanted=YES;
  if(!wanted)continue;
  NSMutableArray *methods=[NSMutableArray array],*properties=[NSMutableArray array];
  for(int kind=0;kind<2;kind++) {
   unsigned int count=0;Method *rows=class_copyMethodList(kind?object_getClass(cls):cls,&count);
   for(unsigned int j=0;j<count && methods.count<140;j++) {
    NSString *selector=NSStringFromSelector(method_getName(rows[j]));NSString *encoding=[NSString stringWithUTF8String:method_getTypeEncoding(rows[j])];
    if(validName(selector) && encoding.length<180)[methods addObject:@{@"selector":selector,@"encoding":encoding,@"classMethod":@(kind==1)}];
   }free(rows);
  }
  unsigned int count=0;objc_property_t *props=class_copyPropertyList(cls,&count);
  for(unsigned int j=0;j<count && properties.count<100;j++){NSString *n=[NSString stringWithUTF8String:property_getName(props[j])];if(validName(n))[properties addObject:n];}free(props);
  [classes addObject:@{@"class":name,@"methods":methods,@"properties":properties}];
 }free(list);
 UIApplication *app=UIApplication.sharedApplication;NSMutableArray *roots=[NSMutableArray array];
 for(UIWindow *w in app.windows){UIViewController *c=w.rootViewController;if(c)[roots addObject:NSStringFromClass(c.class)];}
 NSDictionary *value=@{@"bundle":bundle,@"version":NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"unknown",@"active":@(app.applicationState==UIApplicationStateActive),@"roots":roots,@"classes":classes};
 NSData *json=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];if(json.length>256*1024)return;
 NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:@"cophone-oldbili-probe.json"];
 if([json writeToFile:path atomically:YES])[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];
}}
@end
static CophoneOldbiliProbe *probe;
__attribute__((constructor)) static void start(void){@autoreleasepool {
 if(![@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:NSBundle.mainBundle.bundleIdentifier])return;
 probe=[CophoneOldbiliProbe new];[NSNotificationCenter.defaultCenter addObserver:probe selector:@selector(inspect) name:UIApplicationDidBecomeActiveNotification object:nil];
 dispatch_async(dispatch_get_main_queue(),^{[probe performSelector:@selector(inspect) withObject:nil afterDelay:1];});
}}
