#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>
#import "ReviewSession.h"
#import "NotesWriter.h"
#import "../results/ResultLink.h"
#import "../results/ResultBadge.h"
#import "NotePresentation.h"
#import "ContentReader.h"
#import "PhoneAI.h"
#import "../src/TaskInbox.h"
#import "../src/LocalHistory.h"
#import "../live/ExecutionState.h"
#import "../menu/MenuIPC.h"
#import "../oldbili/OldbiliAgent.h"
#import "../voice/VoiceWorker.h"
#import <spawn.h>
#import <sys/wait.h>
#import <sys/file.h>
#import <fcntl.h>
extern char **environ;

static NSString *const OwnID=@"ai.whaletech.cophone.classic";
static NSTimeInterval now(void){return [[NSDate date] timeIntervalSince1970];}
static NSDictionary *readJSON(NSString *path) {
    NSData *data=[NSData dataWithContentsOfFile:path];
    if(!data || data.length>1024*1024)return nil;
    id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];return [value isKindOfClass:[NSDictionary class]]?value:nil;
}
static void writeJSON(NSDictionary *data,NSString *path) {
    NSData *json=[NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:NULL];
    [json writeToFile:path atomically:YES];
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];
}
static NSString *findDocuments(void) {
    NSFileManager *fm=[NSFileManager defaultManager];NSString *base=@"/var/mobile/Applications";
    for(NSString *container in [fm contentsOfDirectoryAtPath:base error:NULL]) {
        NSString *folder=[base stringByAppendingPathComponent:container];
        NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[folder stringByAppendingPathComponent:@"CoPhone.app/Info.plist"]];
        if([[info objectForKey:@"CFBundleIdentifier"] isEqual:OwnID])return [folder stringByAppendingPathComponent:@"Documents"];

    }
    return nil;
}
@interface ReviewService : NSObject
@property(nonatomic,strong) ReviewSession *session;
@property(nonatomic,strong) PhoneAIWorker *phoneAI;
@property(nonatomic,strong) CophoneOldbiliAgent *oldbiliAgent;
@property(nonatomic,strong) CophoneVoiceWorker *voiceWorker;
@property(nonatomic,strong) NSString *oldbiliProgressID;
@property(nonatomic,strong) NSString *documents;
@property(nonatomic,strong) NSString *commandID;
@property(nonatomic,strong) NSMutableDictionary *state;
@property(nonatomic) NSTimeInterval searchedAt;
@property(nonatomic) NSTimeInterval historyAt;
@property(nonatomic) NSTimeInterval publishedAt;
@property(nonatomic) NSTimeInterval executionAt;
@property(nonatomic) void *sbs;
@property(nonatomic,strong) NSDictionary *applicationNames;
@property(nonatomic,strong) NSArray *videoCaches;
@property(nonatomic) NSTimeInterval namesScannedAt;
@property(nonatomic,strong) CophoneMenuServer *menuServer;
@property(nonatomic) pid_t photoPID;
@property(nonatomic) NSTimeInterval photoStartedAt;
@end
@implementation ReviewService
- (NSString *)frontLocked:(BOOL *)locked {
    mach_port_t (*port)(void)=dlsym(self.sbs,"SBSSpringBoardServerPort");
    void (*lock)(mach_port_t,BOOL *,BOOL *)=dlsym(self.sbs,"SBGetScreenLockStatus");
    CFStringRef (*front)(void)=dlsym(self.sbs,"SBSCopyFrontmostApplicationDisplayIdentifier");
    *locked=YES;BOOL passcode=YES;
    if(!port || !lock || !front)return nil;
    mach_port_t server=port();if(!server)return nil;
    lock(server,locked,&passcode);
    return CFBridgingRelease(front());
}
- (NSString *)name:(NSString *)identifier {
    if([identifier isEqual:@"com.apple.mobilesafari"])return @"Safari";
    if([@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:identifier])return @"oldbili";
    CFStringRef (*name)(CFStringRef)=dlsym(self.sbs,"SBSCopyLocalizedApplicationNameForDisplayIdentifier");
    NSString *systemName=name?CFBridgingRelease(name((__bridge CFStringRef)identifier)):nil;
    NSString *resolved=ReviewAppDisplayName(identifier,systemName,nil,nil);
    if(![resolved isEqual:identifier])return resolved;
    if(!self.applicationNames || ((!self.applicationNames[identifier] || [self.applicationNames[identifier] isEqual:identifier]) && now()-self.namesScannedAt>60)) {
        NSMutableDictionary *names=[NSMutableDictionary dictionary];
        NSFileManager *fm=[NSFileManager defaultManager];
        // Only installed bundle metadata; never inspect another app's Documents.
        for(NSString *base in @[@"/Applications",@"/var/mobile/Applications"]) {
            for(NSString *item in [fm contentsOfDirectoryAtPath:base error:NULL]) {
                NSString *folder=[base stringByAppendingPathComponent:item];
                NSArray *candidates=[item hasSuffix:@".app"]?@[folder]:nil;
                if(!candidates) {
                    NSMutableArray *apps=[NSMutableArray array];
                    for(NSString *child in [fm contentsOfDirectoryAtPath:folder error:NULL])
                        if([child hasSuffix:@".app"])[apps addObject:[folder stringByAppendingPathComponent:child]];
                    candidates=apps;
                }
                for(NSString *path in candidates) {
                    NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
                    NSString *bundle=info[@"CFBundleIdentifier"];
                    if(![bundle isKindOfClass:[NSString class]] || !bundle.length)continue;
                    NSDictionary *localized=[NSBundle bundleWithPath:path].localizedInfoDictionary;
                    names[bundle]=ReviewAppDisplayName(bundle,nil,localized,info);
                }
            }
        }
        self.applicationNames=names;self.namesScannedAt=now();
    }
    return ReviewAppDisplayName(identifier,self.applicationNames[identifier],nil,nil);
}
- (NSArray *)findVideoCaches {
    NSMutableArray *paths=[NSMutableArray array];NSFileManager *fm=[NSFileManager defaultManager];
    NSString *base=@"/var/mobile/Applications";
    for(NSString *container in [fm contentsOfDirectoryAtPath:base error:NULL]) {
        NSString *folder=[base stringByAppendingPathComponent:container];
        for(NSString *app in [fm contentsOfDirectoryAtPath:folder error:NULL])if([app hasSuffix:@".app"]) {
            NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[[folder stringByAppendingPathComponent:app] stringByAppendingPathComponent:@"Info.plist"]];
            NSString *bundle=info[@"CFBundleIdentifier"];
            if([@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:bundle]) {
                NSString *path=[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Caches/%@/Cache.db",bundle]];
                if([fm fileExistsAtPath:path])[paths addObject:path];
            }
        }
    }
    return paths;
}
- (void)readContent:(NSTimeInterval)time {
    [self.session readHistory:[self history] at:time];
    NSString *tabsPath=@"/var/mobile/Library/Safari/SuspendState.plist";
    NSDate *modified=[[[NSFileManager defaultManager] attributesOfItemAtPath:tabsPath error:NULL] objectForKey:NSFileModificationDate];
    [self.session readTabState:[NSDictionary dictionaryWithContentsOfFile:tabsPath] modifiedAt:modified.timeIntervalSince1970 at:time];
    [self.session readVideos:ReviewCachedVideos(self.videoCaches) at:time];
    [self.session enrichPagesFromCache:@"/var/mobile/Library/Caches/com.apple.mobilesafari/Cache.db"];
}
- (NSDictionary *)history {return [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Safari/History.plist"] ?: @{};}
- (void)publishTaskProgress:(NSDictionary *)request {
    NSString *identifier=request[@"id"];
    if(!identifier.length)return;
    NSString *path=[self.documents stringByAppendingPathComponent:@"agent-progress.json"];
    if([readJSON(path)[@"id"] isEqual:identifier])return;
    // Persist before scheduling: restart must not duplicate an acceptance notice.
    writeJSON(@{@"id":identifier,@"attempted":@YES},path);
    BOOL image=[request[@"action"] isEqual:@"illustrate"];NSError *error=nil;
    BOOL sent=SendTaskProgressNotification(image?@"图片正在整理中…完成后会保存到 cophone 相簿。":@"摘要正在整理中…完成后会写入系统备忘录。",&error);
    writeJSON(@{@"id":identifier,@"attempted":@YES,@"submitted":@(sent),@"scheduledAt":@(now())},path);
}
- (void)stopOfflineTask {
    NSDictionary *request=readJSON([self.documents stringByAppendingPathComponent:@"agent-request.json"]);
    if(!request[@"id"])return;
    NSString *path=[self.documents stringByAppendingPathComponent:@"agent-receipt.json"];
    int fd=open([[self.documents stringByAppendingPathComponent:@"agent-photo.lock"] fileSystemRepresentation],O_CREAT|O_RDWR,0600);
    if(fd<0)return;
    if(flock(fd,LOCK_EX|LOCK_NB)!=0){close(fd);return;}
    NSDictionary *receipt=readJSON(path);
    BOOL terminal=[receipt[@"id"] isEqual:request[@"id"]] && [@[@"completed",@"failed",@"uncertain",@"cancelled"] containsObject:receipt[@"status"]];
    if(!terminal) {
        NSMutableDictionary *next=[receipt[@"id"] isEqual:request[@"id"]]?[receipt mutableCopy]:[NSMutableDictionary dictionary];
        next[@"id"]=request[@"id"];next[@"action"]=request[@"action"];next[@"status"]=@"cancelled";
        next[@"error"]=@"cophone 已下线，停止本机任务。已提交的云端任务可能继续执行或计费；未自动重新提交。";
        [next removeObjectForKey:@"verified"];writeJSON(next,path);
    }
    flock(fd,LOCK_UN);close(fd);
}
- (void)agentTick {
    NSDictionary *request=readJSON([self.documents stringByAppendingPathComponent:@"agent-request.json"]);
    NSString *identifier=request[@"id"],*action=request[@"action"];
    if(![identifier isKindOfClass:[NSString class]] || ![[[NSUUID alloc] initWithUUIDString:identifier].UUIDString isEqual:identifier] || ![@[@"summarize",@"illustrate"] containsObject:action])return;
    NSString *receiptPath=[self.documents stringByAppendingPathComponent:@"agent-receipt.json"];
    NSDictionary *receipt=readJSON(receiptPath),*result=readJSON([self.documents stringByAppendingPathComponent:@"agent-result.json"]);
    BOOL ownReceipt=[receipt[@"id"] isEqual:identifier];
    BOOL terminal=ownReceipt && [@[@"completed",@"failed",@"uncertain",@"cancelled"] containsObject:receipt[@"status"]];
    BOOL locked=YES;NSString *front=[self frontLocked:&locked];
    if(!CophoneTaskSessionActive(self.documents,request)){[self stopOfflineTask];return;}
    if(!self.phoneAI)self.phoneAI=[PhoneAIWorker new];
    NSString *taskDocuments=self.documents;NSDictionary *taskRequest=request;
    self.phoneAI.shouldContinue=^{return CophoneTaskSessionActive(taskDocuments,taskRequest);};
    [self.phoneAI tickDocuments:self.documents unlocked:!locked];
    BOOL desktop=!locked && (!front.length || [front isEqual:@"com.apple.springboard"]);
    BOOL safariMenu=[request[@"source"] isEqual:@"safari-menu"];
    if(self.photoPID){int status=0;if(waitpid(self.photoPID,&status,WNOHANG)==self.photoPID)self.photoPID=0;}
    if(safariMenu && !locked && !terminal && [action isEqual:@"illustrate"] && [result[@"id"] isEqual:identifier] && [result[@"status"] isEqual:@"result_ready"] && !self.photoPID && now()-self.photoStartedAt>3) {
        NSString *binary=[[self.documents stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"CoPhone.app/CoPhone"];
        NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[[binary stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Info.plist"]];
        if([info[@"CFBundleVersion"] integerValue]<13)return;
        char *args[]={(char *)binary.fileSystemRepresentation,"--photo-worker",NULL};pid_t child=0;
        if(posix_spawn(&child,binary.fileSystemRepresentation,NULL,NULL,args,environ)==0)self.photoPID=child;self.photoStartedAt=now();
    }
    if(safariMenu && !locked && !terminal) {
        [self publishTaskProgress:request];
    }
    if(!terminal && [result[@"id"] isEqual:identifier]) {
        if([@[@"failed",@"uncertain"] containsObject:result[@"status"]]) {
            receipt=@{@"id":identifier,@"action":action,@"status":result[@"status"],@"error":ReviewCompactText(result[@"error"],200)};writeJSON(receipt,receiptPath);
        } else if([action isEqual:@"summarize"] && [result[@"status"] isEqual:@"result_ready"] && (desktop || (safariMenu && !locked))) {
            NSString *text=ReviewCompactText(result[@"text"],2000); // Model output is data, never an executable command.
            if(!text.length)return;
            if([result[@"text"] length]>2000)return;
            NSString *title=CophoneNoteTitle(result[@"text"],CophoneNoteTitle(request[@"snippet"],@"本次摘录的核心要点"));
            NSString *body=[NSString stringWithFormat:@"%@\n\n%@\n\n摘录摘要 · cophone\n由 DeepSeek 整理。背景补充来自模型常识，未经联网核验。",title,CophoneNoteWithoutHeading(result[@"text"],title)];
            NSError *error=nil;NSDictionary *note=WriteNamedNote(identifier,body,title,&error);
            receipt=note?@{@"id":identifier,@"action":action,@"status":@"completed",@"verified":@YES,@"note":note}:@{@"id":identifier,@"action":action,@"status":@"failed",@"error":error.localizedDescription ?: @"摘要写入未确认"};
            writeJSON(receipt,receiptPath);
        }
    }
    if([receipt[@"id"] isEqual:identifier] && [receipt[@"status"] isEqual:@"completed"] && [receipt[@"verified"] boolValue] && !receipt[@"notificationAttempted"] && (desktop || (safariMenu && !locked))) {
        NSError *error=nil;BOOL photo=[action isEqual:@"illustrate"];
        NSString *resultURL=photo?CophonePhotoResultURL(receipt[@"assetURL"]):receipt[@"note"][@"resultURL"];
        BOOL sent=SendTaskResultNotification(photo?@"配图已保存，点击查看这张图片。":@"摘要已写入备忘录，点击查看这篇摘要。",photo?@"open-photos":@"open-notes",resultURL,&error);
        NSMutableDictionary *updated=[receipt mutableCopy];updated[@"notificationAttempted"]=@YES;updated[@"notificationSubmitted"]=@(sent);
        if(!sent)updated[@"notificationError"]=error.localizedDescription ?: @"通知未确认";
        writeJSON(updated,receiptPath);
    }
    if(safariMenu && !locked && [receipt[@"id"] isEqual:identifier] && [@[@"failed",@"uncertain"] containsObject:receipt[@"status"]] && !receipt[@"notificationAttempted"]) {
        NSError *error=nil;BOOL sent=SendTaskNotification(@"整理未完成，请到 cophone 的记录页查看原因。未自动重复提交。",@"show-result",&error);
        NSMutableDictionary *updated=[receipt mutableCopy];updated[@"notificationAttempted"]=@YES;updated[@"notificationSubmitted"]=@(sent);writeJSON(updated,receiptPath);
    }
}
- (void)publish {
    NSMutableDictionary *data=self.session?[[self.session snapshot] mutableCopy]:self.state;
    for(NSString *key in @[@"receipt",@"error",@"notificationSubmitted",@"notificationPending",@"command",@"agentOnline"])
        if([self.state objectForKey:key])[data setObject:[self.state objectForKey:key] forKey:key];
    [data setObject:@"0.4.0" forKey:@"version"];[data setObject:@(now()) forKey:@"heartbeat"];
    [data setObject:@"0.4.0-24" forKey:@"serviceVersion"];
    [data setObject:@"CoPhoneReviewService" forKey:@"service"];
    if(self.documents)writeJSON(data,[self.documents stringByAppendingPathComponent:@"review-state.json"]);
    self.publishedAt=now();
}
- (void)tick:(NSTimer *)timer {
    @autoreleasepool {
        NSTimeInterval time=now();
        if((!self.documents || ![[NSFileManager defaultManager] fileExistsAtPath:self.documents]) && time-self.searchedAt>3) {
            NSString *found=findDocuments();self.searchedAt=time;
            if(![found isEqual:self.documents]) {
                self.documents=found;self.session=nil;
                NSDictionary *old=found?readJSON([found stringByAppendingPathComponent:@"review-state.json"]):nil;
                self.state=old?[old mutableCopy]:[@{@"status":@"idle"} mutableCopy];self.commandID=[old objectForKey:@"command"];
                if([@[@"recording",@"awaiting_leave",@"finishing"] containsObject:[self.state objectForKey:@"status"]]) {
                    [self.state setObject:@"paused" forKey:@"status"];
                    [self.state setObject:@"后台服务重新启动，已停止旧轮次；没有继续采集或自动重放。" forKey:@"error"];
                }
            }
        }
        if(!self.documents)return;
        if(time-self.executionAt>=1){NSDictionary *snapshot=readJSON([self.documents stringByAppendingPathComponent:@"review-state.json"]) ?: @{};CophoneExportExecution(self.documents,snapshot,self.session?[self.session noteText]:nil);self.executionAt=time;}
        if([self.state[@"historyCleared"] boolValue] && (readJSON([self.documents stringByAppendingPathComponent:@"agent-request.json"])[@"id"] || readJSON([self.documents stringByAppendingPathComponent:@"oldbili-state.json"])[@"id"] || readJSON([self.documents stringByAppendingPathComponent:@"voice-state.json"])[@"id"]))[self.state removeObjectForKey:@"historyCleared"];
        if(!self.menuServer) {
            self.menuServer=[CophoneMenuServer new];__weak ReviewService *weakSelf=self;
            self.menuServer.handler=^NSDictionary *(NSString *path,NSDictionary *body) {
                ReviewService *owner=weakSelf;NSString *documents=owner.documents;
                BOOL ready=CophoneMenuEnabled(documents);
                if([path isEqual:@"/v1/status"]) {
                    NSDictionary *permission=readJSON([documents stringByAppendingPathComponent:@"photo-permission.json"]);
                    NSDictionary *voice=readJSON([documents stringByAppendingPathComponent:@"voice-settings.json"]);
                    return @{@"voiceEnabled":@(!voice[@"enabled"] || [voice[@"enabled"] boolValue]),@"enabled":@(ready),@"agentOnline":@(CophoneAppSession(documents)!=nil),@"appSession":CophoneAppSession(documents) ?: @"",@"photosReady":@([permission[@"authorized"] boolValue]),@"version":@"0.1.1"};
                }
                NSError *error=nil;BOOL accepted=ready && CophoneEnqueue(documents,body[@"snippet"],body[@"action"],@"safari-menu",&error);
                if(accepted)[owner publishTaskProgress:readJSON([documents stringByAppendingPathComponent:@"agent-request.json"])];
                return accepted?@{@"accepted":@YES}:@{@"accepted":@NO,@"error":error.localizedDescription ?: @"请先打开 cophone 并启动，确认菜单已开启。"};
            };
            if(![self.menuServer start])self.menuServer=nil;
        }
        if(!self.voiceWorker)self.voiceWorker=[CophoneVoiceWorker new];
        BOOL voiceLocked=YES;NSString *badgeFront=[self frontLocked:&voiceLocked];CophoneClearViewedResultBadge(badgeFront,!voiceLocked);[self.voiceWorker tick:self.documents unlocked:!voiceLocked];
        BOOL online=CophoneAppSession(self.documents)!=nil;self.state[@"agentOnline"]=@(online);
        if(!online) {
            [self stopOfflineTask];
            if(self.photoPID){int status=0;if(waitpid(self.photoPID,&status,WNOHANG)==self.photoPID)self.photoPID=0;}
            if(self.session && [@[@"awaiting_leave",@"recording",@"finishing"] containsObject:self.session.status]) {
                self.session.status=@"paused";self.session.readyToCommit=NO;
                self.state[@"error"]=@"cophone 已退出，本轮已暂停；重新打开后点启动开始新一轮。";
            }
            if(time-self.publishedAt>=1)[self publish];
            return;
        }
        [self agentTick];
        if(!self.oldbiliAgent)self.oldbiliAgent=[CophoneOldbiliAgent new];
        BOOL oldbiliLocked=YES;[self frontLocked:&oldbiliLocked];
        [self.oldbiliAgent tick:self.documents unlocked:!oldbiliLocked];
        NSDictionary *videoTask=readJSON([self.documents stringByAppendingPathComponent:@"oldbili-state.json"]);
        if(!oldbiliLocked && [@[@"queued",@"planning",@"operating",@"saving"] containsObject:videoTask[@"status"]] && ![self.oldbiliProgressID isEqual:videoTask[@"id"]]) {
            BOOL locked=YES;NSString *front=[self frontLocked:&locked];
            if(!locked && ![front isEqual:OwnID]){self.oldbiliProgressID=videoTask[@"id"];SendTaskProgressNotification(@"正在查找并比较视频，完成后会通知你。",NULL);}
        }
        NSDictionary *command=readJSON([self.documents stringByAppendingPathComponent:@"review-control.json"]);
        NSString *identifier=[command objectForKey:@"id"];
        id issued=[command objectForKey:@"issuedAt"],action=[command objectForKey:@"action"];
        if(![issued isKindOfClass:[NSNumber class]] || ![action isKindOfClass:[NSString class]]
            || ![@[@"start",@"cancel",@"open-notes",@"clear-history"] containsObject:action])identifier=nil;
        if([identifier isKindOfClass:[NSString class]] && identifier.length && ![identifier isEqual:self.commandID]) {
            self.commandID=identifier;[self.state setObject:identifier forKey:@"command"];
            BOOL locked=YES;NSString *front=[self frontLocked:&locked];
            if(locked || ![front isEqual:OwnID] || fabs(time-[[command objectForKey:@"issuedAt"] doubleValue])>15) {
                if(!self.session || [action isEqual:@"start"]) {
                    self.session=nil;self.state=[@{@"command":identifier} mutableCopy];
                    [self.state setObject:@"failed" forKey:@"status"];
                    [self.state setObject:@"请在 CoPhone 前台重新点开始，并等到服务确认后再按 Home。" forKey:@"error"];
                }
            } else if([action isEqual:@"clear-history"]) {
                NSError *error=nil;
                if(self.phoneAI.busy || self.oldbiliAgent.busy || self.voiceWorker.busy || self.photoPID || CophoneLocalTasksActive(self.documents)){self.state[@"error"]=@"任务仍在运行，未清除记录。请先结束任务后重试。";}
                else if(CophoneClearLocalHistory(self.documents,&error)){self.session=nil;self.state=[@{@"status":@"idle",@"command":identifier,@"historyCleared":@YES,@"visits":@[],@"pages":@[],@"videos":@[],@"logs":@[]} mutableCopy];self.oldbiliProgressID=nil;}
                else self.state[@"error"]=@"部分记录未能清除，请检查存储权限后重试。";
            } else if([[command objectForKey:@"action"] isEqual:@"start"]) {
                self.state=[@{@"command":identifier} mutableCopy];
                self.session=[[ReviewSession alloc] initWithID:identifier at:time history:[self history]];
                self.videoCaches=[self findVideoCaches];[self.session setInitialVideos:ReviewCachedVideos(self.videoCaches)];
                self.historyAt=time;
            } else if([[command objectForKey:@"action"] isEqual:@"open-notes"]) {
                int (*launch)(CFStringRef,BOOL)=dlsym(self.sbs,"SBSLaunchApplicationWithIdentifier");
                int result=launch?launch(CFSTR("com.apple.mobilenotes"),NO):-1;
                if(result!=0)[self.state setObject:@"无法直接打开系统备忘录，请按 Home 手动打开。" forKey:@"error"];
            } else if([[command objectForKey:@"action"] isEqual:@"cancel"]) {
                self.session=nil;self.state=[@{@"status":@"cancelled",@"command":identifier,@"logs":@[],@"visits":@[],@"pages":@[]} mutableCopy];
            }
            [self publish];
        }
        if(self.session && [@[@"awaiting_leave",@"recording"] containsObject:self.session.status]) {
            BOOL locked=YES;NSString *front=[self frontLocked:&locked];
            [self.session observe:front name:front.length?[self name:front]:nil locked:locked at:time];
            if(time-self.historyAt>=2 && !locked) {
                [self readContent:time];self.historyAt=time;
            }
        }
        if(self.session.readyToCommit) {
            self.session.readyToCommit=NO;
            // Re-check after debounce. If the user opens an App, defer all committing work.
            BOOL locked=YES;NSString *front=[self frontLocked:&locked];
            if(locked || (front.length && ![front isEqual:@"com.apple.springboard"])) {
                self.session.status=@"recording";self.session.desktopSince=0;[self publish];return;
            }
            [self readContent:time];[self publish];
            NSError *error=nil;NSDictionary *receipt=WriteReviewNote(self.session.sessionID,[self.session noteText],&error);
            if(!receipt) {
                self.session.status=@"failed";[self.state setObject:error.localizedDescription ?: @"备忘录写入未确认" forKey:@"error"];
                [self.session log:@"未确认系统备忘录写入，不发送完成通知" at:now()];
            } else {
                self.session.status=@"completed";[self.state setObject:receipt forKey:@"receipt"];
                [self.session log:@"系统备忘录已保存，独立回读正文一致" at:now()];
                [self.state setObject:@YES forKey:@"notificationPending"];

            }
            [self publish];
        }
        if([[self.state objectForKey:@"notificationPending"] boolValue]) {
            BOOL locked=YES;NSString *front=[self frontLocked:&locked];
            if(!locked && (!front.length || [front isEqual:@"com.apple.springboard"])) {
                NSError *error=nil;BOOL sent=SendTaskResultNotification(@"目视官记录完毕，点击查看本轮记录。",@"open-notes",self.state[@"receipt"][@"resultURL"],&error);
                [self.state setObject:@NO forKey:@"notificationPending"];
                [self.state setObject:@(sent) forKey:@"notificationSubmitted"];
                if(!sent)[self.state setObject:error.localizedDescription ?: @"通知未提交" forKey:@"error"];
                [self.session log:sent?@"完成通知已提交给系统；请打开备忘录查看":@"备忘录已保存，通知接口未确认" at:now()];
                [self publish];
            }
        }
        BOOL active=self.session && [@[@"awaiting_leave",@"recording",@"finishing"] containsObject:self.session.status];
        if(time-self.publishedAt>=(active?1:3))[self publish];
    }
}
@end
int main(int argc,char **argv) {
 if(argc==2 && [[NSString stringWithUTF8String:argv[1]] isEqual:@"--photo-probe"]) {@autoreleasepool {
    NSString *documents=findDocuments();NSString *app=[[documents stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"CoPhone.app"];
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Info.plist"]];
    if([info[@"CFBundleVersion"] integerValue]<13){puts("PHOTO_HELPER_UPDATE_REQUIRED");return 2;}
    NSString *binary=[app stringByAppendingPathComponent:@"CoPhone"];char *args[]={(char *)binary.fileSystemRepresentation,"--photo-probe",NULL};execv(binary.fileSystemRepresentation,args);return 3;
 }}
 if(argc==2 && [[NSString stringWithUTF8String:argv[1]] isEqual:@"--configure-ai"]) {@autoreleasepool {
    NSString *documents=findDocuments();if(!documents)return 2;
    NSData *input=[[NSFileHandle fileHandleWithStandardInput] readDataOfLength:16385];if(!input.length || input.length>16384)return 3;
    id incoming=[NSJSONSerialization JSONObjectWithData:input options:0 error:NULL];if(![incoming isKindOfClass:[NSDictionary class]])return 4;
    NSSet *allowed=[NSSet setWithArray:@[@"transport",@"DEEPSEEK_API_KEY",@"DASHSCOPE_API_KEY",@"DEEPSEEK_MODEL",@"DASHSCOPE_IMAGE_MODEL"]];
    for(NSString *key in incoming)if(![allowed containsObject:key] || ![incoming[key] isKindOfClass:[NSString class]] || [incoming[key] rangeOfString:[key hasSuffix:@"_API_KEY"]?@"^[!-~]{10,4096}$":@"^[A-Za-z0-9_.-]{1,128}$" options:NSRegularExpressionSearch].location==NSNotFound)return 5;
    NSString *folder=[[documents stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
    NSString *path=[folder stringByAppendingPathComponent:@"ai-config.json"];
    NSMutableDictionary *config=[readJSON(path) mutableCopy] ?: [NSMutableDictionary dictionary];[config addEntriesFromDictionary:incoming];config[@"transport"]=@"phone";
    writeJSON(config,path);[[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication,NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];
    if(![readJSON(path) isEqual:config])return 6;
    writeJSON(@{@"transport":@"phone",@"version":@"0.6.0"},[documents stringByAppendingPathComponent:@"agent-transport.json"]);
    puts("COPHONE_PHONE_AI_CONFIGURED");return 0;
 }}
 @autoreleasepool {
    ReviewService *service=[[ReviewService alloc] init];
    service.sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
    if(!service.sbs)return 2;
    [NSTimer scheduledTimerWithTimeInterval:0.75 target:service selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] run];
 }
 return 0;
}
