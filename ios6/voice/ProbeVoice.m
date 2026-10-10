// Read only: excludes keys, audio, recognized text and other App data.
#import <Foundation/Foundation.h>
#import <notify.h>
#import "../menu/MenuIPC.h"
#import "../src/TaskInbox.h"
static NSDictionary *oldbiliState(void){NSFileManager *fm=NSFileManager.defaultManager;NSString *base=@"/var/mobile/Applications";for(NSString *d in [fm contentsOfDirectoryAtPath:base error:NULL]){NSString *folder=[base stringByAppendingPathComponent:d];for(NSString *app in [fm contentsOfDirectoryAtPath:folder error:NULL])if([app hasSuffix:@".app"]){NSDictionary *i=[NSDictionary dictionaryWithContentsOfFile:[[folder stringByAppendingPathComponent:app] stringByAppendingPathComponent:@"Info.plist"]];if([i[@"CFBundleIdentifier"] isEqual:@"net.iosipa.oldbili"])return CophoneTaskJSON([folder stringByAppendingPathComponent:@"Library/Caches/cophone-agent/state.json"]);}}return @{};}
int main(){@autoreleasepool {
 NSString *doc=CophoneDocuments();NSDictionary *s=CophoneMenuRequest(@"/v1/status",nil),*r=CophoneTaskJSON([doc stringByAppendingPathComponent:@"voice-state.json"]);
 NSString *folder=[[doc stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone/voice"];
 NSDictionary *cancel=CophoneTaskJSON([folder stringByAppendingPathComponent:@"cancel.json"]),*request=CophoneTaskJSON([folder stringByAppendingPathComponent:@"request.json"]);
 NSDictionary *task=CophoneTaskJSON([doc stringByAppendingPathComponent:@"oldbili-state.json"]);
 unsigned wav=0;for(NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:NULL])if([f hasSuffix:@".wav"])wav++;
 int token=0;uint64_t flags=0;if(notify_register_check("ai.whaletech.cophone.voice.flags",&token)==NOTIFY_STATUS_OK){notify_get_state(token,&flags);notify_cancel(token);}
 NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[[doc stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"CoPhone.app/Info.plist"]];
 NSDictionary *bridge=oldbiliState();NSDictionary *v=@{@"adapterAge":@(NSDate.date.timeIntervalSince1970-[bridge[@"heartbeat"] doubleValue]),@"adapterActive":bridge[@"active"] ?: @NO,@"adapterStatus":bridge[@"status"] ?: @"",@"backgroundRemaining":bridge[@"backgroundRemaining"] ?: @0,@"oldbiliStatus":task[@"status"] ?: @"",@"oldbiliVerified":task[@"verified"] ?: @NO,@"oldbiliTaskID":task[@"id"] ?: @"",@"voiceTaskID":r[@"taskID"] ?: @"",@"traceCount":@([task[@"trace"] count]),@"notificationSubmitted":task[@"notificationSubmitted"] ?: @NO,@"oldbiliError":task[@"error"] ?: @"",@"appVersion":info[@"CFBundleShortVersionString"] ?: @"",@"agentOnline":s[@"agentOnline"] ?: @NO,@"voiceEnabled":s[@"voiceEnabled"] ?: @NO,@"hookFlags":@(flags),@"status":r[@"status"] ?: @"",@"error":r[@"error"] ?: @"",@"transcriptLength":@([r[@"transcript"] length]),@"goalLength":@([r[@"goal"] length]),@"hasCancelledRecording":@([cancel[@"id"] length]>0),@"hasASRRequest":@([request[@"id"] length]>0),@"pendingAudioFiles":@(wav)};
 NSData *data=[NSJSONSerialization dataWithJSONObject:v options:NSJSONWritingPrettyPrinted error:NULL];puts([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
