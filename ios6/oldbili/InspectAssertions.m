#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
int main(){@autoreleasepool {
 dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",RTLD_NOW);
 dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
 NSMutableArray *out=[NSMutableArray array];for(NSString *name in @[@"BKSProcessAssertion",@"BKProcessAssertion",@"BKSProcess",@"BKProcess",@"BKSProcessAssertionState"]){Class cls=NSClassFromString(name);if(!cls)continue;NSMutableArray *methods=[NSMutableArray array];for(int kind=0;kind<2;kind++){unsigned count=0;Method *ms=class_copyMethodList(kind?object_getClass(cls):cls,&count);for(unsigned i=0;i<count;i++){NSString *sel=NSStringFromSelector(method_getName(ms[i]));[methods addObject:@{@"selector":sel,@"encoding":[NSString stringWithUTF8String:method_getTypeEncoding(ms[i])],@"classMethod":@(kind)}];}free(ms);}[out addObject:@{@"class":name,@"methods":methods}];}
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
