#import <Foundation/Foundation.h>
#import "../src/TaskInbox.h"
#import "../src/AIConfiguration.h"
#import "../src/LocalHistory.h"
#import "../live/ExecutionState.h"
#define CHECK(x) do{if(!(x)){fprintf(stderr,"FAIL private state line %d\n",__LINE__);return 1;}}while(0)
int main(){@autoreleasepool{
 NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString],*doc=[root stringByAppendingPathComponent:@"Documents"],*app=[root stringByAppendingPathComponent:@"CoPhone.app"];
 NSFileManager *fm=NSFileManager.defaultManager;for(NSString *p in @[doc,app])[fm createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:NULL];
 NSDictionary *legacy=@{@"DEEPSEEK_API_KEY":@"test.key-not-real"};
 [@{@"CophoneRequireManualAPI":@YES} writeToFile:[app stringByAppendingPathComponent:@"Info.plist"] atomically:YES];CHECK(!CophoneConfiguredKey(doc,legacy,@"DEEPSEEK_API_KEY"));
 NSMutableDictionary *manual=[legacy mutableCopy];manual[@"DEEPSEEK_API_KEY_MANUAL"]=@YES;CHECK(CophoneConfiguredKey(doc,manual,@"DEEPSEEK_API_KEY"));
 [@{@"CophoneRequireManualAPI":@NO} writeToFile:[app stringByAppendingPathComponent:@"Info.plist"] atomically:YES];CHECK(CophoneConfiguredKey(doc,legacy,@"DEEPSEEK_API_KEY"));
 NSString *ident=NSUUID.UUID.UUIDString;CophoneWriteTaskJSON(@{@"id":ident,@"action":@"summarize",@"snippet":@"真实选文",@"issuedAt":@(NSDate.date.timeIntervalSince1970)},[doc stringByAppendingPathComponent:@"agent-request.json"]);
 CophoneWriteTaskJSON(@{@"id":@"other",@"text":@"不属于本轮的旧结果",@"status":@"result_ready"},[doc stringByAppendingPathComponent:@"agent-result.json"]);
 CophoneExportExecution(doc,@{},nil);NSDictionary *e=CophoneTaskJSON([doc stringByAppendingPathComponent:@"execution-state.json"]);CHECK([e[@"tasks"][0][@"output"] isEqual:@""]);CHECK(CophoneLocalTasksActive(doc));
 CophoneWriteTaskJSON(@{@"id":ident,@"status":@"completed",@"verified":@YES},[doc stringByAppendingPathComponent:@"agent-receipt.json"]);CHECK(!CophoneLocalTasksActive(doc));
 NSString *config=[root stringByAppendingPathComponent:@"Library/Application Support/cophone/ai-config.json"];[fm createDirectoryAtPath:config.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];CophoneWriteTaskJSON(legacy,config);CophoneWriteTaskJSON(@{@"enabled":@YES},[doc stringByAppendingPathComponent:@"menu-settings.json"]);
 CHECK(CophoneClearLocalHistory(doc,NULL));CHECK([fm fileExistsAtPath:config]);CHECK([fm fileExistsAtPath:[doc stringByAppendingPathComponent:@"menu-settings.json"]]);CHECK(![fm fileExistsAtPath:[doc stringByAppendingPathComponent:@"agent-request.json"]]);CHECK(![fm fileExistsAtPath:[doc stringByAppendingPathComponent:@"execution-state.json"]]);
 [fm removeItemAtPath:root error:NULL];puts("PASS personal/shipping API policy, stale-result isolation, active-task guard, scoped history cleanup and preserved credentials/settings");
}return 0;}
