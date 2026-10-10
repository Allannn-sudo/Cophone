#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreTelephony/CTCallCenter.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <notify.h>
#import "VoiceProtocol.h"
#import "VoiceAvailability.h"
#import "../menu/MenuIPC.h"
#import "../src/TaskInbox.h"
static NSString *folder(void){
 NSString *doc=[NSBundle.mainBundle.bundleIdentifier isEqual:@"ai.whaletech.cophone.classic"]?[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0]:CophoneDocuments();
 return doc.length?[[doc stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone/voice"]:nil;
}
static BOOL (*originalHeld)(id,SEL);
static void (*originalPreheat)(id,SEL,id);
static int flagsToken;
static NSString *file(NSString *name){return [folder() stringByAppendingPathComponent:name];}
static BOOL unlocked(void){
 // A synchronous SBS call on SpringBoard's main thread can call back into that
 // same thread and freeze the desktop. Fail closed even if a caller regresses.
 if(NSThread.isMainThread)return NO;
 static void *sbs;static dispatch_once_t once;
 dispatch_once(&once,^{sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_LAZY);});
 if(!sbs)return NO;
 mach_port_t (*port)(void)=dlsym(sbs,"SBSSpringBoardServerPort");
 void (*get)(mach_port_t,BOOL *,BOOL *)=dlsym(sbs,"SBGetScreenLockStatus");
 BOOL locked=YES,passcode=YES;if(port && get)get(port(),&locked,&passcode);return !locked;
}
@interface CophoneHomeVoice:NSObject<UIAlertViewDelegate,AVAudioRecorderDelegate>
@property(nonatomic,strong) AVAudioRecorder *recorder;
@property(nonatomic,strong) CTCallCenter *calls;
@property(nonatomic,strong) UIAlertView *alert,*nextAlert;
@property(nonatomic,strong) NSString *session,*identifier,*phase,*context,*oldCategory,*recordSession,*recognizedGoal;
@property(nonatomic) AVAudioSessionCategoryOptions oldOptions;
@property(nonatomic) NSTimeInterval readyAt,startedAt;
@property(nonatomic) BOOL checking,recording,hooked,systemHook,pendingBegin,ownsAudio,beginAfterDismiss;
@property(nonatomic) BOOL sampledUnlocked,sampledNoCall;
- (BOOL)available;
- (void)begin;
- (void)tick;
@end
static CophoneHomeVoice *voice;
@implementation CophoneHomeVoice
- (BOOL)available{return CophoneVoiceSnapshotReady(self.hooked,self.session.length>0,self.sampledUnlocked,self.sampledNoCall,self.readyAt,NSProcessInfo.processInfo.systemUptime);}
- (void)present:(UIAlertView *)a {
 if(self.alert){self.nextAlert=a;[self.alert dismissWithClickedButtonIndex:self.alert.cancelButtonIndex animated:YES];return;}
 self.alert=a;[a show];
}
- (void)alertView:(UIAlertView *)a didDismissWithButtonIndex:(NSInteger)i {
 if(a!=self.alert)return;self.alert=nil;
 UIAlertView *next=self.nextAlert;self.nextAlert=nil;BOOL again=self.beginAfterDismiss;self.beginAfterDismiss=NO;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(self.alert)return;if(next)[self present:next];else if(again)[self begin];});
}
- (void)message:(NSString *)text {UIAlertView *a=[[UIAlertView alloc] initWithTitle:@"cophone" message:text delegate:self cancelButtonTitle:@"知道了" otherButtonTitles:nil];a.tag=2100;[self present:a];}
- (void)restoreAudio {
 if(!self.oldCategory)return;AVAudioSession *s=[NSClassFromString(@"AVAudioSession") sharedInstance];if(self.ownsAudio)[s setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:NULL];if(self.oldCategory)[s setCategory:self.oldCategory withOptions:self.oldOptions error:NULL];self.oldCategory=nil;self.ownsAudio=NO;
}
- (void)cancel {
 if(self.identifier)CophoneWriteTaskJSON(@{@"id":self.identifier},file(@"cancel.json"));self.phase=@"idle";self.recording=NO;[self.recorder stop];self.recorder=nil;[self restoreAudio];
 if(self.identifier)[NSFileManager.defaultManager removeItemAtPath:file([self.identifier stringByAppendingString:@".wav"]) error:NULL];
 self.nextAlert=nil;self.beginAfterDismiss=NO;[self.alert dismissWithClickedButtonIndex:self.alert.cancelButtonIndex animated:YES];self.context=nil;self.recognizedGoal=nil;
}
- (void)begin {
 if(![self available])return;
 if(self.recording){[self finish];return;}if(self.alert)return;
 self.recordSession=self.session;self.identifier=NSUUID.UUID.UUIDString;self.phase=@"recording";self.startedAt=NSDate.date.timeIntervalSince1970;
 [NSFileManager.defaultManager createDirectoryAtPath:folder() withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
 AVAudioSession *s=[NSClassFromString(@"AVAudioSession") sharedInstance];self.oldCategory=s.category;self.oldOptions=s.categoryOptions;NSError *error=nil;
 if(![s setCategory:AVAudioSessionCategoryRecord error:&error] || ![s setActive:YES error:&error]){[self restoreAudio];self.phase=@"idle";[self message:@"麦克风暂时不可用，请结束通话或稍后重试。"];return;}
 self.ownsAudio=YES;NSDictionary *settings=@{AVFormatIDKey:@(kAudioFormatLinearPCM),AVSampleRateKey:@16000,AVNumberOfChannelsKey:@1,AVLinearPCMBitDepthKey:@16,AVLinearPCMIsBigEndianKey:@NO,AVLinearPCMIsFloatKey:@NO};
 self.recorder=[[NSClassFromString(@"AVAudioRecorder") alloc] initWithURL:[NSURL fileURLWithPath:file([self.identifier stringByAppendingString:@".wav"])] settings:settings error:&error];self.recorder.delegate=self;
 if(!self.recorder || ![self.recorder prepareToRecord] || ![self.recorder recordForDuration:15]){[self cancel];[self message:@"没有启动录音，请稍后重试。"];return;}
 [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:self.recorder.url.path error:NULL];self.recording=YES;
 UIAlertView *a=[[UIAlertView alloc] initWithTitle:@"cophone · 正在听" message:@"说出视频主题和要求。\n最多15秒，说完后发送千问识别。" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"说完了",nil];a.tag=2101;[self present:a];
}
- (void)finish {
 if(!self.recording)return;self.recording=NO;[self.recorder stop];self.recorder=nil;[self restoreAudio];
 if(![self available]){[self cancel];return;}
 BOOL ok=CophoneWriteTaskJSON(@{@"id":self.identifier,@"appSession":self.session,@"issuedAt":@(NSDate.date.timeIntervalSince1970),@"consent":@YES,@"context":self.context ?: @""},file(@"request.json"));
 if(!ok){[self cancel];[self message:@"录音请求未保存，请稍后重试。"];return;}
 self.phase=@"processing";self.startedAt=NSDate.date.timeIntervalSince1970;UIAlertView *a=[[UIAlertView alloc] initWithTitle:@"cophone" message:@"正在识别你的任务…" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:nil];a.tag=2102;[self present:a];
}
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {if(!self.recording)return;if(flag)[self finish];else {[self cancel];[self message:@"录音被中断，未提交任务。"];}}
- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder {[self cancel];}
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {[self cancel];[self message:@"录音没有保存，未开始任务。"];}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
 if(i==a.cancelButtonIndex){[self cancel];return;}
 if(a.tag==2101){[self finish];return;}
 if(a.tag!=2103)return;
 NSString *goal=[self.recognizedGoal stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(i==1){self.beginAfterDismiss=YES;return;}
 if(!goal.length || goal.length>500 || CophoneVoiceVague(goal)){[self message:@"还需要视频主题，请再次长按 Home，说出想看的内容。"];self.context=nil;self.phase=@"idle";return;}
 if(![self available]){[self cancel];return;}
 CophoneWriteTaskJSON(@{@"id":self.identifier,@"appSession":self.session,@"goal":goal,@"consent":@YES,@"issuedAt":@(NSDate.date.timeIntervalSince1970)},file(@"submit.json"));self.phase=@"submitting";self.startedAt=NSDate.date.timeIntervalSince1970;
}
- (void)tick {
 if(!self.checking){self.checking=YES;dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{@autoreleasepool {
  NSDictionary *s=CophoneMenuRequest(@"/v1/status",nil);
  BOOL online=[s[@"agentOnline"] boolValue] && [s[@"voiceEnabled"] boolValue] && [s[@"appSession"] isKindOfClass:NSString.class] && [s[@"appSession"] length]>0;
  BOOL screenUnlocked=NO,noCall=NO;
  if(online){screenUnlocked=unlocked();if(!self.calls)self.calls=[NSClassFromString(@"CTCallCenter") new];noCall=self.calls && self.calls.currentCalls.count==0;}
  NSTimeInterval sampledAt=NSProcessInfo.processInfo.systemUptime;
  dispatch_async(dispatch_get_main_queue(),^{
   self.checking=NO;self.sampledUnlocked=screenUnlocked;self.sampledNoCall=noCall;
   if(online){self.session=s[@"appSession"];self.readyAt=sampledAt;if(self.pendingBegin){self.pendingBegin=NO;[self begin];}}
   else {self.session=nil;self.readyAt=0;if(self.pendingBegin){self.pendingBegin=NO;[self message:@"语音服务未就绪或已关闭，请检查设置及配套后台服务。"];}}
  });
 }});}
 BOOL active=[self available];if(self.systemHook)notify_set_state(flagsToken,1|(self.hooked?2:0)|(active?4:0)|(self.recording?8:0)|([self.phase isEqual:@"processing"]?16:0));
 if((!active || (self.recordSession && ![self.recordSession isEqual:self.session])) && (self.alert || self.recording || [self.phase isEqual:@"submitting"])){[self cancel];return;}
 if(self.recording && NSDate.date.timeIntervalSince1970-self.startedAt>16){[self finish];return;}
 if(![@[@"processing",@"submitting"] containsObject:self.phase])return;
 if(NSDate.date.timeIntervalSince1970-self.startedAt>85){[self cancel];[self message:@"本次语音请求超时，未自动重复提交。"];return;}
 NSDictionary *r=CophoneTaskJSON(file(@"result.json"));if(![r[@"id"] isEqual:self.identifier])return;
 NSString *status=r[@"status"];
 if([self.phase isEqual:@"processing"] && [@[@"ready",@"clarify"] containsObject:status]) {
  self.phase=@"confirm";
  NSString *text=r[@"transcript"] ?: @"";self.context=self.context.length?[NSString stringWithFormat:@"%@；%@",self.context,text]:text;if(self.context.length>500)self.context=[self.context substringToIndex:500];
  BOOL ready=[status isEqual:@"ready"];self.recognizedGoal=ready?r[@"goal"]:nil;
  NSString *preview=text.length>140?[[text substringToIndex:140] stringByAppendingString:@"…"]:text;
  NSString *message=ready?[NSString stringWithFormat:@"%@\n\n确认后后台执行，结果写入备忘录。",self.recognizedGoal]:[NSString stringWithFormat:@"听到：%@\n\n%@",preview,r[@"question"] ?: @"请补充视频主题。"];
  UIAlertView *a=[[UIAlertView alloc] initWithTitle:ready?@"cophone · 确认任务":@"cophone · 补充主题" message:message delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"继续说",nil];if(ready)[a addButtonWithTitle:@"开始"];a.tag=2103;[self present:a];
 } else if([self.phase isEqual:@"submitting"] && [status isEqual:@"submitted"]){self.phase=@"idle";self.context=nil;if(!self.systemHook)[self message:@"视频任务已开始。按 Home 继续使用手机，完成后会通知你。"];}
 else if([@[@"failed",@"uncertain",@"cancelled",@"unsupported"] containsObject:status]){NSString *message=r[@"error"] ?: r[@"question"] ?: @"本轮语音已停止。";[self cancel];[self message:message];}
}
@end
static BOOL homeHeld(id owner,SEL cmd){if([voice available]){[voice begin];return YES;}return originalHeld(owner,cmd);}
static void preheat(id owner,SEL cmd,id date){if(![voice available])originalPreheat(owner,cmd,date);}
__attribute__((constructor)) static void initializeVoice(void){@autoreleasepool {
 if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"])return;
 dispatch_async(dispatch_get_main_queue(),^{
  voice=[CophoneHomeVoice new];voice.systemHook=YES;voice.phase=@"idle";notify_register_check("ai.whaletech.cophone.voice.flags",&flagsToken);
  Class cls=NSClassFromString(@"SBVoiceControlController");Method held=class_getInstanceMethod(cls,NSSelectorFromString(@"handleHomeButtonHeld")),warm=class_getInstanceMethod(cls,NSSelectorFromString(@"preheatForMenuButtonWithFireDate:"));
  void (*hook)(Class,SEL,IMP,IMP *)=dlsym(RTLD_DEFAULT,"MSHookMessageEx");
  if(hook && held && warm && [[NSString stringWithUTF8String:method_getTypeEncoding(held)] isEqual:@"c8@0:4"] && [[NSString stringWithUTF8String:method_getTypeEncoding(warm)] isEqual:@"v12@0:4@8"]){hook(cls,method_getName(held),(IMP)homeHeld,(IMP *)&originalHeld);hook(cls,method_getName(warm),(IMP)preheat,(IMP *)&originalPreheat);voice.hooked=YES;}
  [NSTimer scheduledTimerWithTimeInterval:0.75 target:voice selector:@selector(tick) userInfo:nil repeats:YES];[voice tick];
 });
}}

void CophoneStartVoiceUI(void){
 if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"ai.whaletech.cophone.classic"])return;
 if(!voice){voice=[CophoneHomeVoice new];voice.phase=@"idle";voice.hooked=YES;[NSTimer scheduledTimerWithTimeInterval:0.75 target:voice selector:@selector(tick) userInfo:nil repeats:YES];}
 if([voice available])[voice begin];else {voice.pendingBegin=YES;[voice tick];}
}
