#import "TaskInbox.h"
#import "AIConfiguration.h"
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
NSDictionary *CophoneTaskJSON(NSString *path) {
    NSData *data=[NSData dataWithContentsOfFile:path];if(!data || data.length>1024*1024)return @{};
    id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];return [value isKindOfClass:[NSDictionary class]]?value:@{};
}
BOOL CophoneWriteTaskJSON(NSDictionary *value,NSString *path) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];
    BOOL ok=[data writeToFile:path atomically:YES];
    if(ok)[[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:path error:NULL];return ok;
}
NSString *CophoneDocuments(void) {
    NSString *base=@"/var/mobile/Applications";
    for(NSString *item in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:base error:NULL]) {
        NSString *folder=[base stringByAppendingPathComponent:item];NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[folder stringByAppendingPathComponent:@"CoPhone.app/Info.plist"]];
        if([info[@"CFBundleIdentifier"] isEqual:@"ai.whaletech.cophone.classic"])return [folder stringByAppendingPathComponent:@"Documents"];
    }return nil;
}
int CophoneAcquirePresence(NSString *documents) {
    if(!documents.length)return -1;
    int fd=open([[documents stringByAppendingPathComponent:@"agent-presence.lock"] fileSystemRepresentation],O_CREAT|O_RDWR,0600);
    if(fd<0)return -1;
    fcntl(fd,F_SETFD,FD_CLOEXEC);
    if(flock(fd,LOCK_EX|LOCK_NB)!=0){close(fd);return -1;}
    if(!CophoneWriteTaskJSON(@{@"session":NSUUID.UUID.UUIDString},[documents stringByAppendingPathComponent:@"agent-presence.json"])){close(fd);return -1;}
    return fd;
}
NSString *CophoneAppSession(NSString *documents) {
    if(!documents.length)return nil;
    int fd=open([[documents stringByAppendingPathComponent:@"agent-presence.lock"] fileSystemRepresentation],O_RDWR);
    if(fd<0)return nil;
    BOOL held=NO;
    if(flock(fd,LOCK_EX|LOCK_NB)==0)flock(fd,LOCK_UN);
    else held=(errno==EWOULDBLOCK || errno==EAGAIN);
    close(fd);if(!held)return nil;
    id session=CophoneTaskJSON([documents stringByAppendingPathComponent:@"agent-presence.json"])[@"session"];
    return [session isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:session]?session:nil;
}
BOOL CophoneTaskSessionActive(NSString *documents,NSDictionary *request) {
    NSString *session=CophoneAppSession(documents);
    return session && [session isEqual:request[@"appSession"]];
}
BOOL CophoneMenuEnabled(NSString *documents) {
    if(!documents.length)return NO;
    NSDictionary *settings=CophoneTaskJSON([documents stringByAppendingPathComponent:@"menu-settings.json"]);
    NSDictionary *state=CophoneTaskJSON([documents stringByAppendingPathComponent:@"review-state.json"]);
    return CophoneAppSession(documents)!=nil && [settings[@"enabled"] boolValue] && fabs([NSDate date].timeIntervalSince1970-[state[@"heartbeat"] doubleValue])<8;
}
BOOL CophoneEnqueue(NSString *documents,NSString *snippet,NSString *action,NSString *source,NSError **error) {
    NSString *message=nil;snippet=[snippet stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!documents.length || !snippet.length || snippet.length>2000 || ![@[@"illustrate",@"summarize"] containsObject:action])message=@"请选择 1–2000 字正文后重试。";
    if(message){if(error)*error=[NSError errorWithDomain:@"cophone.inbox" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return NO;}
    int fd=open([[documents stringByAppendingPathComponent:@"agent-submit.lock"] fileSystemRepresentation],O_CREAT|O_RDWR,0600);
    if(fd<0 || flock(fd,LOCK_EX|LOCK_NB)!=0){if(fd>=0)close(fd);if(error)*error=[NSError errorWithDomain:@"cophone.inbox" code:2 userInfo:@{NSLocalizedDescriptionKey:@"正在提交其他任务，请稍后再试。"}];return NO;}
    NSDictionary *request=CophoneTaskJSON([documents stringByAppendingPathComponent:@"agent-request.json"]),*receipt=CophoneTaskJSON([documents stringByAppendingPathComponent:@"agent-receipt.json"]);
    BOOL terminal=[receipt[@"id"] isEqual:request[@"id"]] && [@[@"completed",@"failed",@"uncertain",@"cancelled"] containsObject:receipt[@"status"]];
    if(request[@"id"] && !terminal && [NSDate date].timeIntervalSince1970-[request[@"issuedAt"] doubleValue]<86400)message=@"已有任务正在整理，请先等待它完成。";
    NSDictionary *config=CophoneTaskJSON([[documents stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone/ai-config.json"]);
    if(CophoneRequiresManualAI(documents) && !CophoneConfiguredKey(documents,config,[action isEqual:@"summarize"]?@"DEEPSEEK_API_KEY":@"DASHSCOPE_API_KEY"))message=@"请先打开 cophone → 设置 → AI 设置，手动添加你自己的 API Key。";
    BOOL saved=NO;
    if(!CophoneAppSession(documents))message=@"cophone 已下线，请先打开应用后重试。";
    if(!message) {
        NSMutableDictionary *next=[@{@"id":NSUUID.UUID.UUIDString,@"action":action,@"snippet":snippet,@"source":source ?: @"app",@"issuedAt":@([NSDate date].timeIntervalSince1970)} mutableCopy];
        NSString *session=CophoneAppSession(documents);if(session)next[@"appSession"]=session;
        saved=CophoneWriteTaskJSON(next,[documents stringByAppendingPathComponent:@"agent-request.json"]);
        if(!saved)message=@"任务未保存，请检查后台服务和存储空间。";
    }
    flock(fd,LOCK_UN);close(fd);
    if(message && error)*error=[NSError errorWithDomain:@"cophone.inbox" code:3 userInfo:@{NSLocalizedDescriptionKey:message}];return saved;
}
