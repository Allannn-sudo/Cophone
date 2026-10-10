#import "LocalHistory.h"
#import "TaskInbox.h"
BOOL CophoneLocalTasksActive(NSString *doc) {
    NSDictionary *review=CophoneTaskJSON([doc stringByAppendingPathComponent:@"review-state.json"]),*video=CophoneTaskJSON([doc stringByAppendingPathComponent:@"oldbili-state.json"]);
    if([@[@"awaiting_leave",@"recording",@"finishing"] containsObject:review[@"status"]] || [@[@"queued",@"planning",@"operating",@"saving"] containsObject:video[@"status"]])return YES;
    NSDictionary *r=CophoneTaskJSON([doc stringByAppendingPathComponent:@"agent-request.json"]),*receipt=CophoneTaskJSON([doc stringByAppendingPathComponent:@"agent-receipt.json"]);
    if(r[@"id"] && !([r[@"id"] isEqual:receipt[@"id"]] && [@[@"completed",@"failed",@"uncertain",@"cancelled"] containsObject:receipt[@"status"]]) && NSDate.date.timeIntervalSince1970-[r[@"issuedAt"] doubleValue]<86400)return YES;
    NSString *voice=CophoneTaskJSON([doc stringByAppendingPathComponent:@"voice-state.json"])[@"status"];
    return [@[@"transcribing",@"routing"] containsObject:voice];
}
BOOL CophoneClearLocalHistory(NSString *doc,NSError **error) {
    NSFileManager *fm=NSFileManager.defaultManager;
    // Explicit own-file allowlist. Never touch API config, presence/settings,
    // system Notes/Photos, or any other application's files.
    NSArray *names=@[@"agent-request.json",@"agent-result.json",@"agent-receipt.json",@"agent-progress.json",@"oldbili-request.json",@"oldbili-state.json",@"oldbili-cancel.json",@"voice-state.json",@"agent-frame.json",@"agent-frame.png",@"execution-state.json",@"execution-image.png"];
    NSMutableArray *paths=[NSMutableArray array];for(NSString *name in names)[paths addObject:[doc stringByAppendingPathComponent:name]];
    for(NSString *name in [fm contentsOfDirectoryAtPath:doc error:NULL])if([name rangeOfString:@"^agent-[0-9A-Fa-f-]{36}\\.png$" options:NSRegularExpressionSearch].location!=NSNotFound)[paths addObject:[doc stringByAppendingPathComponent:name]];
    NSString *private=[[doc stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone"];
    for(NSString *folder in @[@"jobs",@"voice"]){NSString *base=[private stringByAppendingPathComponent:folder];for(NSString *name in [fm contentsOfDirectoryAtPath:base error:NULL])if([name.pathExtension isEqual:@"json"] || [name.pathExtension isEqual:@"wav"])[paths addObject:[base stringByAppendingPathComponent:name]];}
    for(NSString *path in paths)if([fm fileExistsAtPath:path] && ![fm removeItemAtPath:path error:error])return NO;
    return YES;
}
