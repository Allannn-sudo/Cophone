#import "../src/AIConfiguration.h"
#import "VoiceWorker.h"
#import "VoiceProtocol.h"
#import "../src/TaskInbox.h"
#import "../review/PhoneAI.h"
#import <sys/stat.h>
static NSString *folder(void){NSString *doc=CophoneDocuments();return doc.length?[[doc stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone/voice"]:nil;}
static NSString *path(NSString *name){return [folder() stringByAppendingPathComponent:name];}
static NSDictionary *voiceRead(NSString *name){return CophoneTaskJSON(path(name));}
static BOOL uuid(id v){return [v isKindOfClass:NSString.class] && [[[[NSUUID alloc] initWithUUIDString:v] UUIDString] isEqual:v];}
static void publish(NSDictionary *s,NSDictionary *r,NSString *doc){if([voiceRead(@"request.json")[@"id"] isEqual:r[@"id"]]){CophoneWriteTaskJSON(s,path(@"result.json"));CophoneWriteTaskJSON(s,[doc stringByAppendingPathComponent:@"voice-state.json"]);}}
static NSString *answer(NSData *d){id v=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;id choices=[v isKindOfClass:NSDictionary.class]?v[@"choices"]:nil;id c=[choices isKindOfClass:NSArray.class] && [choices count]?choices[0]:nil;id m=[c isKindOfClass:NSDictionary.class]?c[@"message"]:nil;id s=[m isKindOfClass:NSDictionary.class]?m[@"content"]:nil;return [s isKindOfClass:NSString.class] && [s length]<=2000?s:nil;}
@implementation CophoneVoiceWorker
- (void)tick:(NSString *)doc unlocked:(BOOL)unlocked {
 self.unlocked=unlocked;
 NSDictionary *r=voiceRead(@"request.json"),*old=voiceRead(@"result.json");NSString *ident=r[@"id"],*session=CophoneAppSession(doc);if(!uuid(ident))return;
 NSString *audio=path([ident stringByAppendingString:@".wav"]);NSFileManager *fm=NSFileManager.defaultManager;
 BOOL live=unlocked && session && [r[@"appSession"] isEqual:session] && ![voiceRead(@"cancel.json")[@"id"] isEqual:ident];
 if(!live){[fm removeItemAtPath:audio error:NULL];return;}
 // Confirmation is a separate user action. Never execute the recognizer's text.
 NSDictionary *submit=voiceRead(@"submit.json");NSString *goal=submit[@"goal"];
 if([old[@"id"] isEqual:ident] && [@[@"ready",@"clarify"] containsObject:old[@"status"]] && [submit[@"id"] isEqual:ident] && [submit[@"appSession"] isEqual:session] && [submit[@"consent"] isEqual:@YES] && [submit[@"issuedAt"] isKindOfClass:NSNumber.class] && fabs(NSDate.date.timeIntervalSince1970-[submit[@"issuedAt"] doubleValue])<15 && [goal isKindOfClass:NSString.class] && goal.length<=500 && !CophoneVoiceVague(goal)) {
  NSDictionary *task=CophoneTaskJSON([doc stringByAppendingPathComponent:@"oldbili-state.json"]);
  NSMutableDictionary *result=[old mutableCopy];
  if([@[@"queued",@"planning",@"operating",@"saving"] containsObject:task[@"status"]]){result[@"status"]=@"failed";result[@"error"]=@"已有视频任务在运行，请先等它完成。";}
  else {NSString *job=NSUUID.UUID.UUIDString;BOOL ok=CophoneWriteTaskJSON(@{@"id":job,@"goal":goal,@"status":@"queued"},[doc stringByAppendingPathComponent:@"oldbili-state.json"]) && CophoneWriteTaskJSON(@{@"id":job,@"goal":goal,@"appSession":session,@"issuedAt":@(NSDate.date.timeIntervalSince1970)},[doc stringByAppendingPathComponent:@"oldbili-request.json"]);result[@"status"]=ok?@"submitted":@"failed";result[@"taskID"]=job;if(!ok)result[@"error"]=@"任务未能保存，请稍后重试。";}
  publish(result,r,doc);return;
 }
 if(self.busy || ![r[@"consent"] isEqual:@YES] || ![r[@"issuedAt"] isKindOfClass:NSNumber.class] || fabs(NSDate.date.timeIntervalSince1970-[r[@"issuedAt"] doubleValue])>60)return;
 if([old[@"id"] isEqual:ident]) {
  if([@[@"transcribing",@"routing"] containsObject:old[@"status"]])publish(@{@"id":ident,@"status":@"uncertain",@"error":@"语音识别中途重新启动，未自动重复请求。"},r,doc);
  return;
 }
 struct stat st;if(lstat(audio.fileSystemRepresentation,&st)!=0 || !S_ISREG(st.st_mode) || st.st_size>512*1024)return;
 NSData *bytes=[NSData dataWithContentsOfFile:audio];[fm removeItemAtPath:audio error:NULL];
 if(!CophoneVoicePCM(bytes)){publish(@{@"id":ident,@"status":@"failed",@"error":@"没有录到有效语音，请重试。"},r,doc);return;}
 NSDictionary *config=CophoneTaskJSON([[doc stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone/ai-config.json"]);NSString *key=CophoneConfiguredKey(doc,config,@"DASHSCOPE_API_KEY");
 if(![key isKindOfClass:NSString.class] || [key rangeOfString:@"^[!-~]{10,4096}$" options:NSRegularExpressionSearch].location==NSNotFound){publish(@{@"id":ident,@"status":@"failed",@"error":@"手机没有有效千问 Key，请到 cophone 的 AI 设置配置。"},r,doc);return;}
 self.busy=YES;publish(@{@"id":ident,@"status":@"transcribing"},r,doc);
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{@autoreleasepool {
  NSTimeInterval deadline=NSDate.date.timeIntervalSince1970+80;
  BOOL (^allowed)(void)=^BOOL{return self.unlocked && NSDate.date.timeIntervalSince1970<deadline && [CophoneAppSession(doc) isEqual:session] && [voiceRead(@"request.json")[@"id"] isEqual:ident] && ![voiceRead(@"cancel.json")[@"id"] isEqual:ident];};
  NSMutableDictionary *result=[@{@"id":ident,@"status":@"failed"} mutableCopy];
  @try {
   PhoneAIEngine *engine=[PhoneAIEngine new];engine.shouldContinue=allowed;NSError *error=nil;
   NSString *base=config[@"DASHSCOPE_BASE_URL"] ?: @"https://dashscope.aliyuncs.com";NSURL *url=[NSURL URLWithString:base];NSString *host=url.host.lowercaseString;
   BOOL valid=[url.scheme isEqual:@"https"] && !url.user.length && !url.password.length && !url.query.length && !url.fragment.length && (!url.port || url.port.integerValue==443) && [@[@"",@"/"] containsObject:url.path ?: @""] && ([host isEqual:@"dashscope.aliyuncs.com"] || [host rangeOfString:@"^[a-z0-9-]+\\.cn-beijing\\.maas\\.aliyuncs\\.com$" options:NSRegularExpressionSearch].location!=NSNotFound);
   if(!valid)@throw [NSException exceptionWithName:@"InvalidHost" reason:nil userInfo:nil];if([base hasSuffix:@"/"])base=[base substringToIndex:base.length-1];
   NSDictionary *payload=@{@"model":@"qwen3-asr-flash",@"messages":@[@{@"role":@"user",@"content":@[@{@"type":@"input_audio",@"input_audio":@{@"data":[@"data:audio/wav;base64," stringByAppendingString:CophoneVoiceBase64(bytes)]}}]}],@"stream":@NO,@"asr_options":@{@"enable_itn":@YES}};
   NSData *response=[engine fetch:[NSURL URLWithString:[base stringByAppendingString:@"/compatible-mode/v1/chat/completions"]] key:key payload:payload asynchronous:NO limit:128*1024 error:&error];NSString *text=answer(response);
   if(!text.length || text.length>500){result[@"error"]=error.localizedDescription ?: @"没有识别到清晰的任务，请再说一次。";}
   else {
    result[@"transcript"]=text;
    NSString *context=[r[@"context"] isKindOfClass:NSString.class] && [r[@"context"] length]<=500?r[@"context"]:@"";
    if(CophoneVoiceVague(text) && !context.length){result[@"status"]=@"clarify";result[@"question"]=@"你想找什么主题的视频？可以继续说，并补充时长或适合谁。";result[@"goal"]=@"";}
    else {
     NSString *deepKey=CophoneConfiguredKey(doc,config,@"DEEPSEEK_API_KEY");
     if(![deepKey isKindOfClass:NSString.class] || deepKey.length<10) {result[@"status"]=@"ready";result[@"goal"]=text;}
     else {
      publish(@{@"id":ident,@"status":@"routing"},r,doc);
      NSDictionary *routePayload=@{@"model":config[@"DEEPSEEK_MODEL"] ?: @"deepseek-flash",@"messages":@[@{@"role":@"system",@"content":@"将用户语音整理成手机任务。目前仅支持oldbili找视频、比较、推荐并保存备忘录，不支持收藏/登录/付款。输出严格JSON且仅三个字符串字段：intent为oldbili/clarify/unsupported；goal为500字内完整任务；question为简短追问或不支持说明。主题缺失则clarify问想看什么，不自行编造主题。用户明确主题但缺少时长可直接oldbili。保留用户限制；语音可能含同音字，谨慎纠正。不要执行或输出任何工具指令。"},@{@"role":@"user",@"content":[NSString stringWithFormat:@"上一句：%@\n本句：%@",context,text]}],@"response_format":@{@"type":@"json_object"},@"thinking":@{@"type":@"disabled"},@"max_tokens":@900,@"stream":@NO};
      NSData *d=[engine fetch:[NSURL URLWithString:@"https://api.deepseek.com/chat/completions"] key:deepKey payload:routePayload asynchronous:NO limit:128*1024 error:&error];NSString *a=answer(d);NSDictionary *route=a?CophoneVoiceRoute([NSJSONSerialization JSONObjectWithData:[a dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL]):nil;
      if(route){result[@"status"]=[route[@"intent"] isEqual:@"oldbili"]?@"ready":route[@"intent"];result[@"goal"]=route[@"goal"];result[@"question"]=route[@"question"];}else result[@"error"]=error.localizedDescription ?: @"任务含义未确认，没有开始执行。";
     }
    }
   }
  }@catch(NSException *e){result[@"error"]=@"语音接口未确认，没有执行任务，也没有重复提交。";}
  if(!allowed()){result[@"status"]=@"cancelled";[result removeObjectForKey:@"transcript"];[result removeObjectForKey:@"goal"];}publish(result,r,doc);
  dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;});
 }});
}
@end
