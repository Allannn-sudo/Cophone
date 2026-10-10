#import "ExecutionState.h"
#import "../src/TaskInbox.h"
static NSDictionary *pick(NSDictionary *source,NSArray *keys){NSMutableDictionary *v=[NSMutableDictionary dictionary];for(NSString *k in keys)if(source[k])v[k]=source[k];return v;}
static NSArray *rows(id source,NSArray *keys,NSUInteger max){NSMutableArray *out=[NSMutableArray array];if([source isKindOfClass:NSArray.class])for(id v in source){if([v isKindOfClass:NSDictionary.class])[out addObject:pick(v,keys)];if(out.count>=max)break;}return out;}
static NSDictionary *executionRead(NSString *doc,NSString *name){return CophoneTaskJSON([doc stringByAppendingPathComponent:name]);}
void CophoneExportExecution(NSString *doc,NSDictionary *review,NSString *reviewText){
    NSTimeInterval now=NSDate.date.timeIntervalSince1970;NSMutableArray *tasks=[NSMutableArray array];
    NSDictionary *video=executionRead(doc,@"oldbili-state.json"),*vr=executionRead(doc,@"oldbili-request.json");
    if(video[@"id"] && [video[@"id"] isEqual:vr[@"id"]]){NSMutableDictionary *t=[pick(video,@[@"id",@"status",@"goal",@"error",@"verified"]) mutableCopy];t[@"kind"]=@"oldbili";t[@"startedAt"]=vr[@"issuedAt"] ?: @0;t[@"trace"]=rows(video[@"trace"],@[@"step",@"action",@"reason",@"query",@"ids"],7);t[@"title"]=video[@"receipt"][@"title"] ?: @"";[tasks addObject:t];}
    NSDictionary *r=executionRead(doc,@"agent-request.json"),*raw=executionRead(doc,@"agent-result.json"),*saved=executionRead(doc,@"agent-receipt.json");
    NSDictionary *result=[raw[@"id"] isEqual:r[@"id"]]?raw:@{},*receipt=[saved[@"id"] isEqual:r[@"id"]]?saved:@{};
    if(r[@"id"] && [@[@"summarize",@"illustrate"] containsObject:r[@"action"]]){
        NSMutableDictionary *t=[@{@"id":r[@"id"],@"kind":r[@"action"],@"startedAt":r[@"issuedAt"] ?: @0,@"status":receipt[@"status"] ?: result[@"status"] ?: @"queued",@"input":r[@"snippet"] ?: @"",@"goal":[r[@"action"] isEqual:@"illustrate"]?@"将选文整理成图片":@"将选文整理成摘要",@"source":r[@"source"] ?: @"app",@"verified":receipt[@"verified"] ?: @NO,@"output":result[@"text"] ?: @"",@"title":receipt[@"note"][@"title"] ?: @"",@"error":receipt[@"error"] ?: result[@"error"] ?: @"",@"albumVerified":receipt[@"albumVerified"] ?: @NO} mutableCopy];
        NSString *name=[NSString stringWithFormat:@"agent-%@.png",r[@"id"]];
        if([r[@"action"] isEqual:@"illustrate"] && [result[@"imageFile"] isEqual:name] && [result[@"sha256"] isKindOfClass:NSString.class]){
            NSString *dest=[doc stringByAppendingPathComponent:@"execution-image.png"];
            NSDictionary *last=executionRead(doc,@"execution-state.json");BOOL exported=[last[@"imageTaskID"] isEqual:r[@"id"]] && [last[@"imageHash"] isEqual:result[@"sha256"]] && [NSFileManager.defaultManager fileExistsAtPath:dest];
            if(!exported){NSData *image=[NSData dataWithContentsOfFile:[doc stringByAppendingPathComponent:name]];const unsigned char magic[]={137,80,78,71,13,10,26,10};if(image.length>=8 && image.length<=10*1024*1024 && [[image subdataWithRange:NSMakeRange(0,8)] isEqual:[NSData dataWithBytes:magic length:8]])exported=[image writeToFile:dest atomically:YES];}
            if(exported){t[@"imageHash"]=result[@"sha256"];[NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:dest error:NULL];}
        }
        [tasks addObject:t];
    }
    if(review[@"session"]){NSMutableDictionary *t=[@{@"id":review[@"session"],@"kind":@"review",@"goal":@"目视官：分段整理本轮使用和浏览内容",@"startedAt":review[@"startedAt"] ?: @0,@"status":review[@"status"] ?: @"idle",@"output":reviewText ?: @"",@"title":review[@"receipt"][@"title"] ?: @"",@"verified":review[@"receipt"][@"verified"] ?: @NO,@"error":review[@"error"] ?: @""} mutableCopy];t[@"visits"]=rows(review[@"visits"],@[@"name",@"bundle",@"start",@"end"],200);t[@"pages"]=rows(review[@"pages"],@[@"title",@"url",@"excerpt"],60);t[@"videos"]=rows(review[@"videos"],@[@"title",@"author",@"description",@"duration"],30);t[@"trace"]=rows(review[@"logs"],@[@"time",@"message"],100);[tasks addObject:t];}
    NSMutableDictionary *state=[@{@"version":@1,@"capturedAt":@(now),@"online":@(CophoneAppSession(doc)!=nil),@"tasks":tasks,@"source":@"phone-execution-data"} mutableCopy];
    for(NSDictionary *t in tasks)if(t[@"imageHash"]){state[@"imageTaskID"]=t[@"id"];state[@"imageHash"]=t[@"imageHash"];}
    CophoneWriteTaskJSON(state,[doc stringByAppendingPathComponent:@"execution-state.json"]);
}
