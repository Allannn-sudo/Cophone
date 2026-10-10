#import "AgentTasks.h"
#import "PhotoAlbum.h"
#import "TaskInbox.h"
#import "AIConfiguration.h"
#import "LocalHistory.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
static NSTimeInterval taskNow(void){return [NSDate date].timeIntervalSince1970;}
static NSDictionary *taskJSON(NSString *path) {
    NSData *data=[NSData dataWithContentsOfFile:path];if(!data || data.length>64*1024)return @{};
    id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];return [value isKindOfClass:[NSDictionary class]]?value:@{};
}
static NSString *digest(NSData *data) {
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,bytes);
    NSMutableString *s=[NSMutableString string];for(int i=0;i<sizeof(bytes);i++)[s appendFormat:@"%02x",bytes[i]];return s;
}
static NSString *pixels(CGImageRef image) {
    if(!image)return nil;size_t w=CGImageGetWidth(image),h=CGImageGetHeight(image);
    if(!w || !h || w>1600 || h>1600)return nil;
    NSMutableData *data=[NSMutableData dataWithLength:w*h*4];CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(data.mutableBytes,w,h,8,w*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);CGColorSpaceRelease(space);
    if(!context)return nil;CGContextDrawImage(context,CGRectMake(0,0,w,h),image);CGContextRelease(context);return digest(data);
}
@implementation AgentTasks
- (id)initWithDocuments:(NSString *)documents {
    if((self=[super init])){self.documents=documents;self.backgroundTask=UIBackgroundTaskInvalid;self.library=[[ALAssetsLibrary alloc] init];self.photoLock=-1;}return self;
}
- (void)releasePhotoLock {if(self.photoLock>=0){flock(self.photoLock,LOCK_UN);close(self.photoLock);self.photoLock=-1;}}
- (void)dealloc {[self releasePhotoLock];}
- (BOOL)ownsRequest:(NSDictionary *)request generation:(NSUInteger)generation {return (!self.headless || CophoneTaskSessionActive(self.documents,request)) && self.saving && generation==self.photoGeneration && [[[self read:@"agent-request.json"] objectForKey:@"id"] isEqual:request[@"id"]];}
- (NSDictionary *)read:(NSString *)name {return taskJSON([self.documents stringByAppendingPathComponent:name]);}
- (BOOL)write:(NSDictionary *)value name:(NSString *)name {
    NSString *path=[self.documents stringByAppendingPathComponent:name];NSData *data=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];
    BOOL ok=[data writeToFile:path atomically:YES];[[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];return ok;
}
- (BOOL)terminal:(NSDictionary *)receipt request:(NSDictionary *)request {
    return [receipt[@"id"] isEqual:request[@"id"]] && [@[@"completed",@"failed",@"uncertain",@"cancelled"] containsObject:receipt[@"status"]];
}
- (void)endBackground {
    if(self.backgroundTask!=UIBackgroundTaskInvalid){[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];self.backgroundTask=UIBackgroundTaskInvalid;}
}
- (void)keepRunning {
    if(self.headless)return;
    if(self.backgroundTask!=UIBackgroundTaskInvalid)return;
    self.backgroundTask=[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if(self.saving) {
            NSDictionary *receipt=[self read:@"agent-receipt.json"];
            if([receipt[@"status"] isEqual:@"saving_photo"] && !receipt[@"assetURL"]){NSMutableDictionary *next=[receipt mutableCopy];next[@"status"]=@"uncertain";next[@"error"]=@"相册保存时后台时间耗尽，结果未确认；未重复保存，请先核对相册。";[self write:next name:@"agent-receipt.json"];}
            self.photoGeneration++;self.saving=NO;[self releasePhotoLock];
        }[self endBackground];
    }];
}
- (void)resume {
    NSDictionary *request=[self read:@"agent-request.json"];
    if([request[@"action"] isEqual:@"illustrate"] && ![self terminal:[self read:@"agent-receipt.json"] request:request] && taskNow()-[request[@"issuedAt"] doubleValue]<86400)[self keepRunning];
}
- (void)cancelWaiting {
    NSDictionary *request=[self read:@"agent-request.json"];
    if(!request[@"id"] || [self terminal:[self read:@"agent-receipt.json"] request:request])return;
    if(self.saving){[[[UIAlertView alloc] initWithTitle:@"正在核对相册" message:@"已提交系统相册保存，请等待核对结果。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    int lock=open([[self.documents stringByAppendingPathComponent:@"agent-photo.lock"] fileSystemRepresentation],O_CREAT|O_RDWR,0600);
    if(lock<0 || flock(lock,LOCK_EX|LOCK_NB)!=0){if(lock>=0)close(lock);[[[UIAlertView alloc] initWithTitle:@"正在核对相册" message:@"Safari 正在保存与核对，请等待结果。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    if([self terminal:[self read:@"agent-receipt.json"] request:request] || ![[[self read:@"agent-request.json"] objectForKey:@"id"] isEqual:request[@"id"]]){flock(lock,LOCK_UN);close(lock);return;}
    [self write:@{@"id":request[@"id"],@"action":request[@"action"],@"status":@"cancelled",@"error":@"已停止等待和本机保存；已提交云端的请求可能仍会计费。"} name:@"agent-receipt.json"];[self endBackground];
    flock(lock,LOCK_UN);close(lock);
}
- (NSString *)configPath {
    NSString *folder=[[self.documents stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone"];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
    return [folder stringByAppendingPathComponent:@"ai-config.json"];
}
- (void)configureAI {
    NSDictionary *config=taskJSON([self configPath]);
    NSString *message=[NSString stringWithFormat:@"手机直接联网，无需电脑。\nDeepSeek：%@\n千问北京：%@\n密钥仅存于手机私有 Library，不在文件共享中显示。",[CophoneConfiguredKey(self.documents,config,@"DEEPSEEK_API_KEY") length]?@"已配置":@"未配置",[CophoneConfiguredKey(self.documents,config,@"DASHSCOPE_API_KEY") length]?@"已配置":@"未配置"];
    UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"AI 设置" message:message delegate:self cancelButtonTitle:@"完成" otherButtonTitles:@"配置 DeepSeek",@"配置千问",@"移除手机上的 API Key",nil];alert.tag=601;[alert show];
}
- (void)requestPhotoAccess {
    ALAuthorizationStatus status=[ALAssetsLibrary authorizationStatus];
    if(status==ALAuthorizationStatusAuthorized){[self write:@{@"authorized":@YES} name:@"photo-permission.json"];[[[UIAlertView alloc] initWithTitle:@"相册权限已允许" message:@"配图可保存到 cophone 相簿。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    if(status==ALAuthorizationStatusDenied || status==ALAuthorizationStatusRestricted){[self write:@{@"authorized":@NO} name:@"photo-permission.json"];[[[UIAlertView alloc] initWithTitle:@"需要相册权限" message:@"请到设置 → 隐私 → 照片，允许 cophone。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    __block BOOL resolved=NO;
    [self.library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group,BOOL *stop){if(resolved)return;resolved=YES;*stop=YES;[self write:@{@"authorized":@YES} name:@"photo-permission.json"];} failureBlock:^(NSError *error){[self write:@{@"authorized":@NO} name:@"photo-permission.json"];}];
}
- (void)chooseCopiedText {
    NSDictionary *request=[self read:@"agent-request.json"],*receipt=[self read:@"agent-receipt.json"];
    if(request[@"id"] && ![self terminal:receipt request:request] && taskNow()-[request[@"issuedAt"] doubleValue]<86400) {
        [[[UIAlertView alloc] initWithTitle:@"已有 AI 任务" message:@"请先等待当前任务完成。手机正在直接联网处理。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;
    }
    NSString *text=[UIPasteboard generalPasteboard].string;
    text=[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if(!text.length || text.length>2000){[[[UIAlertView alloc] initWithTitle:@"先复制一段文字" message:@"在 Safari 等应用中选择并复制 1–2000 字，然后回到 cophone。仅发送你在此确认的摘录。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    self.snippet=text;
    NSString *preview=text.length>180?[[text substringWithRange:[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,180)]] stringByAppendingString:@"…"]:text;
    [[[UIAlertView alloc] initWithTitle:@"用这段摘录做什么？" message:[NSString stringWithFormat:@"%@\n\n摘要发给 DeepSeek；配图发给阿里云千问。需在 AI 设置配置密钥及 API 额度，其他使用记录不会上传。",preview] delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"摘要 → 备忘录",@"配图 → 相册",nil] show];
}
- (void)submit:(NSString *)action {
    NSError *error=nil;
    if(![self submitSnippet:self.snippet action:action source:@"app" error:&error]){[[[UIAlertView alloc] initWithTitle:@"任务未提交" message:error.localizedDescription delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    self.snippet=nil;
    [[[UIAlertView alloc] initWithTitle:@"任务已排队" message:@"现在可以按 Home 继续使用手机。手机通过自己的 Wi-Fi 直接调用 API，无需电脑。真实保存并回读后才会通知完成。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];
}
- (BOOL)submitSnippet:(NSString *)snippet action:(NSString *)action source:(NSString *)source error:(NSError **)error {
    BOOL saved=CophoneEnqueue(self.documents,snippet,action,source,error);
    if(saved){[self keepRunning];[self tick];}return saved;
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if(alert.tag==601) {
        if(index==0)return;
        if(index==3){if(CophoneLocalTasksActive(self.documents)){[[[UIAlertView alloc] initWithTitle:@"任务仍在运行" message:@"请先结束任务，再移除 API Key。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}UIAlertView *a=[[UIAlertView alloc] initWithTitle:@"移除 API Key？" message:@"仅移除手机上的 AI 凭据。后续 AI 请求需要重新配置；已有备忘录和照片保留。正在执行的请求可能已计费，请先等任务结束。" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"移除",nil];a.tag=603;[a show];return;}
        self.settingProvider=index==1?@"DEEPSEEK_API_KEY":@"DASHSCOPE_API_KEY";
        UIAlertView *input=[[UIAlertView alloc] initWithTitle:index==1?@"DeepSeek API Key":@"千问北京 API Key" message:@"在此粘贴密钥，留空取消。不会显示旧密钥或写入日志。" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"保存到手机",nil];
        input.tag=602;input.alertViewStyle=UIAlertViewStyleSecureTextInput;[input textFieldAtIndex:0].autocorrectionType=UITextAutocorrectionTypeNo;[input textFieldAtIndex:0].autocapitalizationType=UITextAutocapitalizationTypeNone;[input show];return;
    }
    if(alert.tag==603){if(index!=0){[[NSFileManager defaultManager] removeItemAtPath:[self configPath] error:NULL];[self configureAI];}return;}
    if(alert.tag==602) {
        NSString *key=[[[alert textFieldAtIndex:0] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if(index==0 || !key.length){self.settingProvider=nil;return;}
        if([key rangeOfString:@"^[!-~]{10,4096}$" options:NSRegularExpressionSearch].location==NSNotFound){self.settingProvider=nil;[[[UIAlertView alloc] initWithTitle:@"密钥格式不正确" message:@"请粘贴完整 API Key，不要附带空格、换行或其他说明。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
        NSMutableDictionary *config=[taskJSON([self configPath]) mutableCopy] ?: [NSMutableDictionary dictionary];config[self.settingProvider]=key;config[[self.settingProvider stringByAppendingString:@"_MANUAL"]]=@YES;config[@"transport"]=@"phone";
        NSData *data=[NSJSONSerialization dataWithJSONObject:config options:0 error:NULL];BOOL saved=[data writeToFile:[self configPath] atomically:YES];
        [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600,NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:[self configPath] error:NULL];
        if(saved)[self write:@{@"transport":@"phone",@"version":@"0.6.0"} name:@"agent-transport.json"];
        self.settingProvider=nil;[[[UIAlertView alloc] initWithTitle:saved?@"已保存到手机":@"未保存" message:saved?@"可以直接用复制的文字开始 AI 任务，无需 USB 或电脑。":@"请检查剩余存储空间。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;
    }
    if(index==0){self.snippet=nil;return;}
    if(index==1){[self submit:@"summarize"];return;}
    ALAuthorizationStatus status=[ALAssetsLibrary authorizationStatus];
    if(status==ALAuthorizationStatusDenied || status==ALAuthorizationStatusRestricted) {
        [[[UIAlertView alloc] initWithTitle:@"需要相册权限" message:@"请在设置 → 隐私 → 照片中允许 cophone。尚未提交生图，不会计费。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;
    }
    if(status==ALAuthorizationStatusAuthorized){[self submit:@"illustrate"];return;}
    // Request permission while cophone is in front, before any paid submission/background work.
    __block BOOL resolved=NO;
    [self.library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group,BOOL *stop) {
        if(resolved)return;resolved=YES;*stop=YES;[self submit:@"illustrate"];
    } failureBlock:^(NSError *error) {
        self.snippet=nil;[[[UIAlertView alloc] initWithTitle:@"未获相册权限" message:@"没有提交生图任务。请在系统设置允许 cophone 访问照片。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];
    }];
}
- (void)fail:(NSString *)message request:(NSDictionary *)request uncertain:(BOOL)uncertain {
    [self write:@{@"id":request[@"id"],@"action":request[@"action"],@"status":uncertain?@"uncertain":@"failed",@"error":message} name:@"agent-receipt.json"];
    self.saving=NO;[self releasePhotoLock];[self endBackground];
}
- (void)verify:(NSURL *)url request:(NSDictionary *)request expected:(NSString *)expected {
    NSUInteger generation=self.photoGeneration;
    [self.library assetForURL:url resultBlock:^(ALAsset *asset) {
        if(![self ownsRequest:request generation:generation])return;
        NSString *actual=pixels(asset.defaultRepresentation.fullResolutionImage);
        if(!asset || !expected.length || ![actual isEqual:expected]){[self fail:@"相片已提交，但回读像素未匹配；不重复保存。请手动核对相册。" request:request uncertain:YES];return;}
        NSMutableDictionary *checkpoint=[[self read:@"agent-receipt.json"] mutableCopy];
        checkpoint[@"id"]=request[@"id"];checkpoint[@"action"]=@"illustrate";checkpoint[@"status"]=@"filing_album";
        checkpoint[@"assetURL"]=url.absoluteString;checkpoint[@"pixelSHA256"]=expected;
        [self write:checkpoint name:@"agent-receipt.json"];
        [PhotoAlbum fileAsset:asset library:self.library completion:^(BOOL verified) {
            if(![self ownsRequest:request generation:generation])return;
            NSMutableDictionary *saved=[checkpoint mutableCopy];
            saved[@"status"]=verified?@"completed":@"album_pending";
            if(verified){saved[@"verified"]=@YES;saved[@"albumVerified"]=@YES;saved[@"albumName"]=@"cophone";saved[@"verifiedAt"]=@(taskNow());[saved removeObjectForKey:@"error"];}
            else {saved[@"verified"]=@NO;saved[@"error"]=@"图片已在相机胶卷，相簿整理尚未确认。重新打开 cophone 会继续整理，不重新生图或保存副本。";self.albumRetryAt=taskNow()+30;}
            [self write:saved name:@"agent-receipt.json"];self.saving=NO;[self releasePhotoLock];[self endBackground];
        }];
    } failureBlock:^(NSError *error){if([self ownsRequest:request generation:generation])[self fail:@"相片保存后暂时无法回读；不自动重复保存。" request:request uncertain:YES];}];
}
- (void)tick {
    NSDictionary *request=[self read:@"agent-request.json"],*result=[self read:@"agent-result.json"],*receipt=[self read:@"agent-receipt.json"];
    if(![request[@"id"] isKindOfClass:[NSString class]])return;
    if(self.onlySafariTasks && ![request[@"source"] isEqual:@"safari-menu"])return;
    BOOL same=[receipt[@"id"] isEqual:request[@"id"]];
    BOOL migrate=same && [request[@"action"] isEqual:@"illustrate"] && [receipt[@"status"] isEqual:@"completed"] && ![receipt[@"albumVerified"] boolValue] && [receipt[@"assetURL"] isKindOfClass:[NSString class]];
    if(!migrate && [self terminal:receipt request:request]){[self endBackground];return;}
    if(![request[@"action"] isEqual:@"illustrate"] || self.saving)return;
    if(![result[@"id"] isEqual:request[@"id"]] || ![result[@"status"] isEqual:@"result_ready"])return;
    if(same && [receipt[@"status"] isEqual:@"album_pending"] && ([[UIApplication sharedApplication] applicationState]!=UIApplicationStateActive || taskNow()<self.albumRetryAt))return;
    int lock=open([[self.documents stringByAppendingPathComponent:@"agent-photo.lock"] fileSystemRepresentation],O_CREAT|O_RDWR,0600);
    if(lock<0 || flock(lock,LOCK_EX|LOCK_NB)!=0){if(lock>=0)close(lock);return;}
    // Re-read after acquiring the cross-process lock: the other saver may just have finished.
    receipt=[self read:@"agent-receipt.json"];
    if(![[[self read:@"agent-request.json"] objectForKey:@"id"] isEqual:request[@"id"]]){flock(lock,LOCK_UN);close(lock);return;}
    if([self terminal:receipt request:request] && !(migrate && ![receipt[@"albumVerified"] boolValue])){flock(lock,LOCK_UN);close(lock);return;}
    self.photoLock=lock;self.photoGeneration++;NSUInteger generation=self.photoGeneration;
    self.saving=YES;[self keepRunning];
    if(same && (migrate || [@[@"saving_photo",@"filing_album",@"album_pending"] containsObject:receipt[@"status"]])) {
        if([receipt[@"assetURL"] isKindOfClass:[NSString class]])[self verify:[NSURL URLWithString:receipt[@"assetURL"]] request:request expected:receipt[@"pixelSHA256"]];
        else [self fail:@"上次相册保存中断，未重复保存。请先核对相册。" request:request uncertain:YES];return;
    }
    NSString *filename=[@"agent-" stringByAppendingFormat:@"%@.png",request[@"id"]];
    if(![result[@"imageFile"] isEqual:filename]){[self fail:@"图片文件名不匹配。" request:request uncertain:NO];return;}
    NSString *path=[self.documents stringByAppendingPathComponent:filename];NSDictionary *attributes=[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    if([attributes[NSFileSize] unsignedLongLongValue]>10*1024*1024 || !attributes){[self fail:@"图片缺失或过大。" request:request uncertain:NO];return;}
    NSData *data=[NSData dataWithContentsOfFile:path];UIImage *image=[UIImage imageWithData:data];NSString *expected=pixels(image.CGImage);
    if(![digest(data) isEqual:result[@"sha256"]] || !expected.length){[self fail:@"图片完整性或尺寸检查失败。" request:request uncertain:NO];return;}
    if([ALAssetsLibrary authorizationStatus]!=ALAuthorizationStatusAuthorized){[self fail:@"相册权限未允许，图片保留在 cophone 中。" request:request uncertain:NO];return;}
    if(![self write:@{@"id":request[@"id"],@"action":@"illustrate",@"status":@"saving_photo",@"pixelSHA256":expected} name:@"agent-receipt.json"]){self.saving=NO;[self releasePhotoLock];return;}
    [self.library writeImageDataToSavedPhotosAlbum:data metadata:nil completionBlock:^(NSURL *url,NSError *error) {
        if(![self ownsRequest:request generation:generation])return;
        if(error || !url){[self fail:@"系统相册没有确认保存；请在 cophone 查看。" request:request uncertain:YES];return;}
        [self write:@{@"id":request[@"id"],@"action":@"illustrate",@"status":@"saving_photo",@"assetURL":url.absoluteString,@"pixelSHA256":expected} name:@"agent-receipt.json"];
        [self verify:url request:request expected:expected];
    }];
}
- (NSString *)statusText {
    NSDictionary *request=[self read:@"agent-request.json"],*result=[self read:@"agent-result.json"],*receipt=[self read:@"agent-receipt.json"];
    if(!request[@"id"])return @"AI 任务：先复制文字，再点“用复制的文字做任务”。\n摘要写入备忘录；配图保存相册。请先在“AI 设置”配置手机密钥。";
    if([receipt[@"id"] isEqual:request[@"id"]] && [receipt[@"status"] isEqual:@"album_pending"])return receipt[@"error"];
    if([self terminal:receipt request:request])return [receipt[@"status"] isEqual:@"completed"]?[NSString stringWithFormat:@"✓ %@已保存并回读确认。",[request[@"action"] isEqual:@"illustrate"]?([receipt[@"albumVerified"] boolValue]?@"配图（cophone 相簿）":@"配图（系统相册）"):@"摘要（系统备忘录）"]:[NSString stringWithFormat:@"任务未完成：%@",receipt[@"error"] ?: @"请查看手机 AI 设置"];
    if([result[@"id"] isEqual:request[@"id"]]) {NSDictionary *names=@{@"waiting_config":@"等待手机密钥配置",@"submitting":@"正在提交请求",@"running":@"千问正在生成图片",@"downloading":@"正在下载配图",@"result_ready":@"结果已到达，正在保存与核对"};return [NSString stringWithFormat:@"AI 任务：%@%@",names[result[@"status"]] ?: result[@"status"],result[@"error"]?[@"\n" stringByAppendingString:result[@"error"]]:@""];}
    return @"任务已排队，等待手机后台处理。请保持 Wi-Fi 联网。相册任务若等待过久，请重新打开 cophone 继续保存。";
}
@end
int CophoneRunPhotoWorker(BOOL probe) {@autoreleasepool {
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
    if(![bundle isEqual:@"ai.whaletech.cophone.classic"])return 10;
    ALAuthorizationStatus authorization=[ALAssetsLibrary authorizationStatus];
    if(probe){printf("PHOTO_HELPER bundle=cophone authorization=%ld authorized=%d\n",(long)authorization,authorization==ALAuthorizationStatusAuthorized);return 0;}
    NSString *documents=[[NSBundle.mainBundle.bundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Documents"];
    AgentTasks *tasks=[[AgentTasks alloc] initWithDocuments:documents];tasks.headless=YES;tasks.onlySafariTasks=YES;
    NSDictionary *request=[tasks read:@"agent-request.json"];
    if(![request[@"source"] isEqual:@"safari-menu"] || ![request[@"action"] isEqual:@"illustrate"])return 11;
    if(authorization!=ALAuthorizationStatusAuthorized){[tasks fail:@"请先在 cophone 的设置中允许相册权限；已生成图片保留，未绕过权限。" request:request uncertain:NO];return 12;}
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:90];
    while(deadline.timeIntervalSinceNow>0) {
        if(!CophoneTaskSessionActive(documents,request))return 15;
        [tasks tick];NSDictionary *receipt=[tasks read:@"agent-receipt.json"];
        if([tasks terminal:receipt request:request])return [receipt[@"verified"] boolValue]?0:13;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    }
    // Do not overwrite another saver: the lock holder owns its checkpoint.
    if(tasks.saving)[tasks fail:@"相册整理超时，未重复保存；请在 cophone 核对。" request:request uncertain:YES];return 14;
}}
