#import "ReviewSession.h"
#import "ContentReader.h"
#import "NotePresentation.h"

static NSString *const OwnID=@"ai.whaletech.cophone.classic";
static NSString *nonblank(id value) {
    if(![value isKindOfClass:[NSString class]])return nil;
    NSString *text=[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return text.length?text:nil;
}
NSString *ReviewAppDisplayName(NSString *identifier,id systemName,NSDictionary *localizedInfo,NSDictionary *info) {
    return nonblank(systemName)
        ?: nonblank(localizedInfo[@"CFBundleDisplayName"])
        ?: nonblank(info[@"CFBundleDisplayName"])
        ?: nonblank(localizedInfo[@"CFBundleName"])
        ?: nonblank(info[@"CFBundleName"])
        ?: nonblank(identifier) ?: @"未知应用";
}
static NSString *fingerprint(NSDictionary *row) {
    return [NSString stringWithFormat:@"%@|%@",[row objectForKey:@"lastVisitedDate"],[row objectForKey:@"visitCount"]];
}
static NSString *dateText(NSTimeInterval timestamp) {
    NSDateFormatter *f=[[NSDateFormatter alloc] init];f.dateFormat=@"M月d日 HH:mm";f.timeZone=[NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}
@implementation ReviewSession
- (id)initWithID:(NSString *)identifier at:(NSTimeInterval)time history:(NSDictionary *)history {
    if((self=[super init])) {
        self.sessionID=identifier;self.startedAt=time;self.status=@"awaiting_leave";self.desktopDelay=6;
        self.visits=[NSMutableArray array];self.pages=[NSMutableArray array];self.logs=[NSMutableArray array];
        self.baseline=[NSMutableDictionary dictionary];self.pageKeys=[NSMutableSet set];
        self.videos=[NSMutableArray array];self.videoKeys=[NSMutableSet set];self.videoBaseline=[NSMutableSet set];self.pageSources=[NSMutableArray array];
        for(NSDictionary *row in [history objectForKey:@"WebHistoryDates"]) {
            NSString *url=[row objectForKey:@""];if([url isKindOfClass:[NSString class]])[self.baseline setObject:fingerprint(row) forKey:url];
        }
        [self log:@"本轮已开始；按 Home 后正常使用 Safari、oldbili 等应用" at:time];
    }
    return self;
}
- (void)log:(NSString *)message at:(NSTimeInterval)time {
    [self.logs addObject:@{@"time":@(time),@"message":message}];
    if(self.logs.count>120)[self.logs removeObjectAtIndex:0];
}
- (void)closeVisit:(NSTimeInterval)time {
    if(self.currentVisit){[self.currentVisit setObject:@(time) forKey:@"end"];self.currentVisit=nil;}
}
- (void)observe:(NSString *)identifier name:(NSString *)name locked:(BOOL)locked at:(NSTimeInterval)time {
    if(self.readyToCommit || [@[@"paused",@"cancelled",@"completed",@"failed"] containsObject:self.status])return;
    if(time-self.startedAt>=900 || self.visits.count>=200) {
        [self closeVisit:time];self.status=@"paused";self.endedAt=time;
        [self log:@"达到本轮上限，已停止采集；没有自动写入或通知。请回 App 查看" at:time];return;
    }
    if(locked){[self closeVisit:time];self.desktopSince=0;return;}
    BOOL home=!identifier.length || [identifier isEqual:@"com.apple.springboard"];
    BOOL own=[identifier isEqual:OwnID];
    if(home || own) {
        [self closeVisit:time];
        if(home && self.visits.count) {
            if(!self.desktopSince){self.desktopSince=time;[self log:@"回到桌面，等待连续停留 6 秒；打开其他 App 会继续记录" at:time];}
            if(time-self.desktopSince>=self.desktopDelay) {
                self.readyToCommit=YES;self.status=@"finishing";self.endedAt=time;
                [self log:@"桌面停留已确认，停止采集，准备写入系统备忘录" at:time];
            }
        } else self.desktopSince=0;
        return;
    }
    self.desktopSince=0;self.status=@"recording";
    NSString *displayName=ReviewAppDisplayName(identifier,name,nil,nil);
    if(![[self.currentVisit objectForKey:@"bundle"] isEqual:identifier]) {
        [self closeVisit:time];
        self.currentVisit=[@{@"bundle":identifier,@"name":displayName,@"start":@(time),@"end":@(time)} mutableCopy];
        [self.visits addObject:self.currentVisit];[self log:[NSString stringWithFormat:@"前台应用：%@",displayName] at:time];
    } else {
        [self.currentVisit setObject:@(time) forKey:@"end"];
        if(![displayName isEqual:identifier] && ![[self.currentVisit objectForKey:@"name"] isEqual:displayName])
            [self.currentVisit setObject:displayName forKey:@"name"];
    }
}
- (BOOL)safariWasVisibleAt:(NSTimeInterval)time {
    for(NSDictionary *visit in self.visits)if([[visit objectForKey:@"bundle"] isEqual:@"com.apple.mobilesafari"]
        && time>=[[visit objectForKey:@"start"] doubleValue]-1 && time<=[[visit objectForKey:@"end"] doubleValue]+1)return YES;
    return NO;
}
- (void)readHistory:(NSDictionary *)history at:(NSTimeInterval)time {
    if(self.pages.count>=100)return;
    for(NSDictionary *row in [history objectForKey:@"WebHistoryDates"]) {
        NSString *raw=[row objectForKey:@""];if(![raw isKindOfClass:[NSString class]])continue;
        if([[self.baseline objectForKey:raw] isEqual:fingerprint(row)])continue;
        NSTimeInterval stamp=[[row objectForKey:@"lastVisitedDate"] doubleValue];
        NSTimeInterval apple=stamp+978307200;
        if(fabs(apple-time)<fabs(stamp-time))stamp=apple;
        if(stamp<self.startedAt || stamp>time+2 || ![self safariWasVisibleAt:stamp])continue;
        NSString *key=[NSString stringWithFormat:@"%@|%.3f",raw,stamp];if([self.pageKeys containsObject:key])continue;
        NSURL *url=[NSURL URLWithString:raw];NSString *scheme=[url.scheme lowercaseString];
        if(![@[@"http",@"https"] containsObject:scheme] || !url.host.length)continue;
        // Omit userinfo, query and fragment from the saved URL. Never inspect form fields.
        NSString *safe=[NSString stringWithFormat:@"%@://%@%@%@",scheme,url.host,url.port ? [@":" stringByAppendingString:url.port.stringValue] : @"",url.path ?: @""];
        id title=[row objectForKey:@"title"];if(![title isKindOfClass:[NSString class]] || ![title length])title=url.host;
        if([title length]>300)title=[title substringToIndex:300];
        NSMutableDictionary *page=[@{@"title":title,@"url":safe,@"time":@(stamp),@"source":@"Safari History.plist"} mutableCopy];
        [self.pages addObject:page];[self.pageSources addObject:@{@"page":page,@"rawURL":raw}];
        [self.pageKeys addObject:key];
        [self log:[NSString stringWithFormat:@"Safari 本轮新增页面：%@",title] at:time];
        if(self.pages.count>=100)break;
    }
}
- (void)readTabState:(NSDictionary *)state modifiedAt:(NSTimeInterval)modified at:(NSTimeInterval)time {
    if(modified<self.startedAt || modified>time+2)return;
    id index=state[@"SafariStateActiveDocumentIndex"],documents=state[@"SafariStateDocuments"];
    if(![index isKindOfClass:[NSNumber class]] || ![documents isKindOfClass:[NSArray class]] || [index integerValue]<0 || [index unsignedIntegerValue]>=[documents count])return;
    id document=documents[[index unsignedIntegerValue]];
    if(![document isKindOfClass:[NSDictionary class]])return;
    NSString *raw=document[@"SafariStateDocumentUserVisibleURL"];
    if(![raw isKindOfClass:[NSString class]] || !raw.length)raw=document[@"SafariStateDocumentURL"];
    id viewed=document[@"SafariStateDocumentLastViewedTime"];
    if(![raw isKindOfClass:[NSString class]] || ![viewed isKindOfClass:[NSNumber class]])return;
    // Only the selected tab with a fresh view timestamp; never dump every restored tab.
    NSTimeInterval stamp=[viewed doubleValue],apple=stamp+978307200;
    if(fabs(apple-time)<fabs(stamp-time))stamp=apple;
    if(stamp<self.startedAt || stamp>time+2 || ![self safariWasVisibleAt:stamp])return;
    for(NSDictionary *source in self.pageSources)if([source[@"rawURL"] isEqual:raw])return;
    NSUInteger previous=self.pages.count;
    NSDictionary *row=@{@"":raw,@"title":ReviewCompactText(document[@"SafariStateDocumentTitle"],300),@"lastVisitedDate":@(stamp),@"visitCount":@(-1)};
    [self readHistory:@{@"WebHistoryDates":@[row]} at:time];
    if(self.pages.count>previous)[self.pages lastObject][@"source"]=@"Safari 当前标签状态（本轮查看时间）";
}
- (void)setInitialVideos:(NSArray *)rows {
    for(NSDictionary *row in rows)if([row[@"cacheKey"] isKindOfClass:[NSString class]])[self.videoBaseline addObject:row[@"cacheKey"]];
}
- (void)readVideos:(NSArray *)rows at:(NSTimeInterval)time {
    for(NSDictionary *row in rows) {
        if(self.videos.count>=30)break;
        NSString *key=row[@"cacheKey"];NSTimeInterval stamp=[row[@"time"] doubleValue];
        if(![key isKindOfClass:[NSString class]] || [self.videoBaseline containsObject:key] || stamp<self.startedAt-1 || stamp>time+1)continue;
        BOOL visible=NO;NSString *appBundle=nil;
        for(NSDictionary *visit in self.visits)if([@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:visit[@"bundle"]]
            && stamp>=[visit[@"start"] doubleValue]-1 && stamp<=[visit[@"end"] doubleValue]+1){visible=YES;appBundle=visit[@"bundle"];break;}
        if(!visible)continue;
        NSString *identity=row[@"videoID"];
        if(![identity isKindOfClass:[NSString class]] || !identity.length || ![row[@"title"] isKindOfClass:[NSString class]] || [self.videoKeys containsObject:identity])continue;
        NSMutableDictionary *video=[NSMutableDictionary dictionary];
        for(NSString *field in @[@"title",@"description",@"author",@"videoID",@"url",@"source",@"time"])
            if(row[field])video[field]=row[field];
        if(appBundle)video[@"appBundle"]=appBundle;
        [self.videos addObject:video];[self.videoKeys addObject:identity];
        [self log:[NSString stringWithFormat:@"读到本轮打开的视频：%@",video[@"title"]] at:time];
    }
}
- (void)enrichPagesFromCache:(NSString *)database {
    NSUInteger attempts=0;
    for(NSDictionary *source in [self.pageSources reverseObjectEnumerator]) {
        NSMutableDictionary *page=source[@"page"];
        if([page[@"excerpt"] length])continue;
        if(++attempts>3)break;
        NSString *excerpt=ReviewCachedPage(database,source[@"rawURL"]);
        if(excerpt.length){page[@"excerpt"]=excerpt;page[@"excerptSource"]=@"Safari 缓存正文摘录";}
    }
}
- (NSDictionary *)snapshot {
    return @{@"session":self.sessionID,@"status":self.status,@"startedAt":@(self.startedAt),@"endedAt":@(self.endedAt),
        @"visits":self.visits,@"pages":self.pages,@"videos":self.videos,@"logs":self.logs,@"desktopDelay":@(self.desktopDelay)};
}
- (NSString *)noteTitle {
    NSMutableArray *topics=[NSMutableArray array];
    NSString *page=CophoneNoteCompact([self.pages lastObject][@"title"],self.videos.count?12:22);
    NSString *video=CophoneNoteCompact([self.videos lastObject][@"title"],self.pages.count?12:22);
    if(page.length)[topics addObject:page];if(video.length && ![topics containsObject:video])[topics addObject:video];
    if(topics.count)return CophoneNoteCompact([[topics componentsJoinedByString:@" · "] stringByAppendingString:@"｜浏览回顾"],28);
    NSMutableArray *names=[NSMutableArray array];for(NSDictionary *v in self.visits){NSString *n=CophoneNoteCompact(v[@"name"],10);if(n.length && ![names containsObject:n])[names addObject:n];if(names.count==2)break;}
    return names.count?CophoneNoteCompact([[names componentsJoinedByString:@"、"] stringByAppendingString:@"使用回顾"],28):@"本轮没有应用活动";
}
- (NSString *)noteText {
    NSMutableString *text=[NSMutableString stringWithFormat:@"%@\n目视官 · %@ — %@\n",[self noteTitle],dateText(self.startedAt),dateText(self.endedAt ?: self.startedAt)];
    NSMutableDictionary *apps=[NSMutableDictionary dictionary];NSMutableArray *order=[NSMutableArray array];
    for(NSDictionary *visit in self.visits) {
        NSString *bundle=nonblank(visit[@"bundle"]) ?: @"unknown";
        NSString *name=ReviewAppDisplayName(bundle,visit[@"name"],nil,nil);
        if(!apps[bundle]){apps[bundle]=[NSMutableDictionary dictionaryWithDictionary:@{@"name":name,@"seconds":@0}];[order addObject:bundle];}
        NSMutableDictionary *app=apps[bundle];
        if(![name isEqual:bundle])app[@"name"]=name;
        app[@"seconds"]=@([app[@"seconds"] doubleValue]+MAX(0,[visit[@"end"] doubleValue]-[visit[@"start"] doubleValue]));
    }
    for(NSString *bundle in order) {
        NSDictionary *app=apps[bundle];NSInteger seconds=(NSInteger)round([app[@"seconds"] doubleValue]);
        NSString *duration=seconds>=60?[NSString stringWithFormat:@"%ld分%ld秒",(long)seconds/60,(long)seconds%60]:[NSString stringWithFormat:@"%ld秒",(long)seconds];
        [text appendFormat:@"\n%@ · %@\n",app[@"name"],duration];
        if([bundle isEqual:@"com.apple.mobilesafari"]) {
            if(!self.pages.count){[text appendString:@"使用了浏览器；未取得本轮页面内容。\n"];continue;}
            NSUInteger count=0;for(NSDictionary *page in self.pages) {
                if(++count>5)break;
                [text appendFormat:@"%lu. %@\n",(unsigned long)count,ReviewCompactText(page[@"title"],55)];
                NSString *excerpt=ReviewCompactText(page[@"excerpt"],180);
                [text appendFormat:@"%@\n",excerpt.length?excerpt:@"未取得正文，仅记录标题。"];
                [text appendFormat:@"来源：%@\n",[NSURL URLWithString:page[@"url"]].host ?: @"Safari"];
            }
            if(self.pages.count>5)[text appendFormat:@"另有 %lu 个页面，见记录页。\n",(unsigned long)self.pages.count-5];
        } else if([@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:bundle]) {
            NSUInteger count=0,total=0;
            for(NSDictionary *video in self.videos) {
                if(video[@"appBundle"] && ![video[@"appBundle"] isEqual:bundle])continue;
                if(++total>5)continue;
                [text appendFormat:@"%lu. %@\n",(unsigned long)++count,ReviewCompactText(video[@"title"],70)];
                if([video[@"author"] length])[text appendFormat:@"UP主：%@\n",ReviewCompactText(video[@"author"],30)];
                NSString *desc=ReviewCompactText(video[@"description"],100);
                if(desc.length && ![desc isEqual:@"-"])[text appendFormat:@"%@\n",desc];
            }
            if(!total)[text appendString:@"使用了 oldbili；未取得本轮视频详情。\n"];
            if(total>5)[text appendFormat:@"另有 %lu 条视频，见记录页。\n",(unsigned long)total-5];
        } else [text appendString:@"前台使用了该应用；未读取应用内内容。\n"];
    }
    if(!order.count)[text appendString:@"\n本轮没有可记录的应用活动。\n"];
    [text appendString:@"\n本机记录。网页为缓存摘录；视频为详情信息，不代表看完。"];
    return text;
}
@end
