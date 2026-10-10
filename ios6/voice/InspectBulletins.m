// Read-only runtime API metadata. Does not publish, intercept or open anything.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
int main(){@autoreleasepool {
 dlopen("/System/Library/PrivateFrameworks/BulletinBoard.framework/BulletinBoard",RTLD_NOW);
 dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 NSMutableArray *out=[NSMutableArray array];
 for(NSString *name in @[@"BBAction",@"BBBulletin",@"BBBulletinRequest",@"BBLocalNotificationContext",@"BBResponse",@"BBServer",@"BBObserver",@"BBLocalDataProvider",@"SBSLocalNotificationClient",@"SBSLocalNotificationServer"]){
  Class c=NSClassFromString(name);if(!c)continue;NSMutableArray *methods=[NSMutableArray array];
  for(int kind=0;kind<2;kind++){unsigned count=0;Method *ms=class_copyMethodList(kind?object_getClass(c):c,&count);
   for(unsigned i=0;i<count;i++)[methods addObject:@{@"selector":NSStringFromSelector(method_getName(ms[i])),@"encoding":[NSString stringWithUTF8String:method_getTypeEncoding(ms[i])],@"classMethod":@(kind)}];free(ms);
  }[out addObject:@{@"class":name,@"methods":methods}];
 }
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
