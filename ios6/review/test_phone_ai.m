#import <Foundation/Foundation.h>
#import "PhoneAI.h"
#define CHECK(x) do {if(!(x)){fprintf(stderr,"FAIL phone AI line %d: %s\n",__LINE__,#x);return 1;}}while(0)
static void put(NSDictionary *v,NSString *p){[[NSJSONSerialization dataWithJSONObject:v options:0 error:NULL] writeToFile:p atomically:YES];}
static NSDictionary *get(NSString *p){NSData *d=[NSData dataWithContentsOfFile:p];return d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:@{};}
static BOOL offlineProtocolStarted,offlineProtocolStopped;
@interface OfflineProtocol:NSURLProtocol @end
@implementation OfflineProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {return [request.URL.scheme isEqual:@"cophone-lifecycle-test"];}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {return request;}
- (void)startLoading {offlineProtocolStarted=YES; /* Remain pending; never open a socket. */}
- (void)stopLoading {offlineProtocolStopped=YES;}
@end
@interface OfflineSwitch:NSObject
@property(nonatomic) BOOL online;
- (void)goOffline:(NSTimer *)timer;
@end
@implementation OfflineSwitch
- (void)goOffline:(NSTimer *)timer {self.online=NO;}
@end
@interface MockAI:PhoneAIEngine
@property NSUInteger posts;
@property NSUInteger gets;
@property BOOL fail;
@property(strong) NSDictionary *response;
@property(strong) NSDictionary *lastPayload;
@end
@implementation MockAI
- (NSData *)fetch:(NSURL *)url key:(NSString *)key payload:(NSDictionary *)payload asynchronous:(BOOL)asynchronous limit:(NSUInteger)limit error:(NSError **)error {
 if(payload){self.posts++;self.lastPayload=payload;}else self.gets++;
 if(self.fail){if(error)*error=[NSError errorWithDomain:@"test" code:1 userInfo:@{NSLocalizedDescriptionKey:@"网络未确认"}];return nil;}
 return [NSJSONSerialization dataWithJSONObject:self.response ?: @{} options:0 error:NULL];
}
@end
int main(){@autoreleasepool {
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];NSString *documents=[root stringByAppendingPathComponent:@"Documents"];
 [[NSFileManager defaultManager] createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:nil error:NULL];
 NSString *requestPath=[documents stringByAppendingPathComponent:@"agent-request.json"],*resultPath=[documents stringByAppendingPathComponent:@"agent-result.json"];
 NSMutableDictionary *request=[@{@"id":[NSUUID UUID].UUIDString,@"action":@"summarize",@"snippet":@"测试资料：手机独立处理",@"issuedAt":@([NSDate date].timeIntervalSince1970)} mutableCopy];put(request,requestPath);
 MockAI *engine=[MockAI new];engine.response=@{@"choices":@[@{@"message":@{@"content":@"短标题\n• 要点"}}]};
 [engine processRequest:request documents:documents config:@{}];CHECK(engine.posts==0);CHECK([get(resultPath)[@"status"] isEqual:@"waiting_config"]);
 NSDictionary *config=@{@"DEEPSEEK_API_KEY":@"test.key-not-real",@"DASHSCOPE_API_KEY":@"test.key-not-real"};
 NSString *app=[root stringByAppendingPathComponent:@"CoPhone.app"];[[NSFileManager defaultManager] createDirectoryAtPath:app withIntermediateDirectories:YES attributes:nil error:NULL];
 [@{@"CophoneRequireManualAPI":@YES} writeToFile:[app stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==0);CHECK([get(resultPath)[@"status"] isEqual:@"waiting_config"]);
 [@{@"CophoneRequireManualAPI":@NO} writeToFile:[app stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==1);CHECK([get(resultPath)[@"status"] isEqual:@"result_ready"]);CHECK([engine.lastPayload[@"thinking"][@"type"] isEqual:@"disabled"]);
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==1);
 NSString *serialized=[get(resultPath) description];CHECK([serialized rangeOfString:@"test.key-not-real"].location==NSNotFound);CHECK([serialized rangeOfString:@"手机独立处理"].location==NSNotFound);
 // A failed paid submission is never repeated by restart or a later tick.
 request[@"id"]=[NSUUID UUID].UUIDString;put(request,requestPath);engine.fail=YES;
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==2);CHECK([get(resultPath)[@"status"] isEqual:@"uncertain"]);
 engine.fail=NO;[engine processRequest:request documents:documents config:config];CHECK(engine.posts==2);
 // Async task ID is persisted and the next tick uses GET, not another POST.
 request[@"id"]=[NSUUID UUID].UUIDString;request[@"action"]=@"illustrate";put(request,requestPath);engine.response=@{@"output":@{@"task_id":@"task-12345678"}};
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==3);CHECK([get(resultPath)[@"status"] isEqual:@"running"]);
 engine.response=@{@"output":@{@"task_status":@"RUNNING"}};
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==3);CHECK(engine.gets==1);
 // Process death after a POST marker is ambiguous, even before task ID receipt.
 NSString *journal=[root stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Application Support/cophone/jobs/%@.json",request[@"id"]]];
 NSMutableDictionary *interrupted=[get(journal) mutableCopy];interrupted[@"status"]=@"submitting";[interrupted removeObjectForKey:@"taskID"];put(interrupted,journal);
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==3);CHECK([get(resultPath)[@"status"] isEqual:@"uncertain"]);
 // An unsupported model must fail before sending a billable request.
 request[@"id"]=[NSUUID UUID].UUIDString;put(request,requestPath);NSMutableDictionary *bad=[config mutableCopy];bad[@"DASHSCOPE_IMAGE_MODEL"]=@"unsupported";
 [engine processRequest:request documents:documents config:bad];CHECK(engine.posts==3);CHECK([get(resultPath)[@"status"] isEqual:@"failed"]);
 // Changing a UUID's contents cannot turn an existing job into a second submission.
 request[@"snippet"]=@"changed";put(request,requestPath);[engine processRequest:request documents:documents config:config];CHECK(engine.posts==3);
 // Offline guards reject work before a billable POST or network connection.
 request[@"id"]=[NSUUID UUID].UUIDString;put(request,requestPath);engine.shouldContinue=^{return NO;};
 [engine processRequest:request documents:documents config:config];CHECK(engine.posts==3);
 PhoneAIEngine *offline=[PhoneAIEngine new];offline.shouldContinue=^{return NO;};NSError *offlineError=nil;
 CHECK(![offline fetch:[NSURL URLWithString:@"https://api.deepseek.com/chat/completions"] key:@"test.key-not-real" payload:@{} asynchronous:NO limit:100 error:&offlineError]);CHECK(offlineError.code==7);
 // Exercise cancellation of a real pending NSURLConnection, without network/API calls.
 [NSURLProtocol registerClass:OfflineProtocol.class];OfflineSwitch *lifecycle=[OfflineSwitch new];lifecycle.online=YES;
 offline.shouldContinue=^{return lifecycle.online;};offlineError=nil;
 [NSTimer scheduledTimerWithTimeInterval:0.1 target:lifecycle selector:@selector(goOffline:) userInfo:nil repeats:NO];
 NSDate *cancelStarted=[NSDate date];
 CHECK(![offline fetch:[NSURL URLWithString:@"cophone-lifecycle-test://pending"] key:nil payload:nil asynchronous:NO limit:100 error:&offlineError]);
 CHECK(offlineError.code==7);CHECK(offlineProtocolStarted);
 NSDate *stopDeadline=[NSDate dateWithTimeIntervalSinceNow:0.5];while(!offlineProtocolStopped && stopDeadline.timeIntervalSinceNow>0)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];CHECK(offlineProtocolStopped);CHECK(-cancelStarted.timeIntervalSinceNow<2);
 [NSURLProtocol unregisterClass:OfflineProtocol.class];
 [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];puts("PASS phone AI: local configuration / real result state / no duplicate paid POST / persisted GET polling / private result fields / model rejection / immutable request / offline request guard / in-flight connection cancellation");
}return 0;}
