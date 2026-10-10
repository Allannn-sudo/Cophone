// Scoped diagnostics for cophone's own result identifiers; no other note/photo reads.
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <sqlite3.h>
@interface NSObject(ResultNotes)
- (NSArray *)allNotesMatchingPredicate:(NSPredicate *)predicate;
@end
static NSDictionary *json(NSString *path){NSData *d=[NSData dataWithContentsOfFile:path];id v=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;return [v isKindOfClass:NSDictionary.class]?v:@{};}
int main(){@autoreleasepool{
 NSMutableDictionary *out=[NSMutableDictionary dictionary];
 for(NSString *app in @[@"MobileNotes",@"MobileSlideShow"]){NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/Applications/%@.app/Info.plist",app]];out[app]=info[@"CFBundleURLTypes"] ?: @[];}
 NSString *doc=nil;for(NSString *entry in [NSFileManager.defaultManager contentsOfDirectoryAtPath:@"/var/mobile/Applications" error:NULL]){NSString *root=[@"/var/mobile/Applications" stringByAppendingPathComponent:entry];NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[root stringByAppendingPathComponent:@"CoPhone.app/Info.plist"]];if([info[@"CFBundleIdentifier"] isEqual:@"ai.whaletech.cophone.classic"]){doc=[root stringByAppendingPathComponent:@"Documents"];break;}}
 if(!doc)return 2;
 NSDictionary *receipt=json([doc stringByAppendingPathComponent:@"agent-receipt.json"]);if([receipt[@"verified"] boolValue] && receipt[@"assetURL"])out[@"assetURL"]=receipt[@"assetURL"];
 NSDictionary *video=json([doc stringByAppendingPathComponent:@"oldbili-state.json"]);NSDictionary *note=video[@"receipt"];
 if(![note[@"verified"] boolValue])note=json([doc stringByAppendingPathComponent:@"review-state.json"])[@"receipt"];
 NSString *guid=note[@"guid"];if([[NSUUID alloc] initWithUUIDString:guid]){
  out[@"noteGUID"]=guid;out[@"noteTitle"]=note[@"title"] ?: @"";
  sqlite3 *db=NULL;sqlite3_stmt *s=NULL;if(sqlite3_open_v2("/var/mobile/Library/Notes/notes.sqlite",&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK && sqlite3_prepare_v2(db,"SELECT Z_PK FROM ZNOTE WHERE ZGUID=? AND COALESCE(ZDELETEDFLAG,0)=0",-1,&s,NULL)==SQLITE_OK){sqlite3_bind_text(s,1,guid.UTF8String,-1,SQLITE_TRANSIENT);if(sqlite3_step(s)==SQLITE_ROW)out[@"noteSQLPrimaryKey"]=@(sqlite3_column_int64(s,0));}sqlite3_finalize(s);s=NULL;if(sqlite3_prepare_v2(db,"SELECT sql FROM sqlite_master WHERE name='ZNOTE'",-1,&s,NULL)==SQLITE_OK && sqlite3_step(s)==SQLITE_ROW){const char *sql=(const char *)sqlite3_column_text(s,0);if(sql)out[@"noteSchema"]=@(sql);}sqlite3_finalize(s);sqlite3_close(db);
  dlopen("/System/Library/PrivateFrameworks/Notes.framework/Notes",RTLD_NOW);id ctx=[[NSClassFromString(@"NoteContext") alloc] init];if([ctx respondsToSelector:@selector(allNotesMatchingPredicate:)]){NSArray *matches=[ctx allNotesMatchingPredicate:[NSPredicate predicateWithFormat:@"guid == %@",guid]];id own=matches.count?[matches objectAtIndex:0]:nil;SEL integer=NSSelectorFromString(@"integerId");if([own respondsToSelector:integer]){id value=((id(*)(id,SEL))objc_msgSend)(own,integer);if([value isKindOfClass:NSNumber.class])out[@"noteIntegerId"]=value;}SEL sel=NSSelectorFromString(@"noteId");Method m=own?class_getInstanceMethod([own class],sel):NULL;if(m){char *t=method_copyReturnType(m);out[@"noteIdEncoding"]=@(t);if(t && (t[0]=='i' || t[0]=='I' || t[0]=='l' || t[0]=='L'))out[@"noteNativeId"]=@(((int(*)(id,SEL))objc_msgSend)(own,sel));if(t && t[0]=='@'){id native=((id(*)(id,SEL))objc_msgSend)(own,sel);out[@"noteNativeIdClass"]=NSStringFromClass([native class]) ?: @"nil";out[@"noteNativeIdDescription"]=[native description] ?: @"nil";if([native isKindOfClass:NSNumber.class] || [native isKindOfClass:NSString.class])out[@"noteNativeId"]=native;}free(t);}}
 }
 sqlite3 *photos=NULL;sqlite3_stmt *asset=NULL;
 if(sqlite3_open_v2("/var/mobile/Media/PhotoData/Photos.sqlite",&photos,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK && sqlite3_prepare_v2(photos,"SELECT a.ZUUID FROM ZGENERICASSET a JOIN Z_8ASSETS x ON x.Z_14ASSETS=a.Z_PK JOIN ZGENERICALBUM g ON g.Z_PK=x.Z_8ALBUMS WHERE g.ZTITLE='cophone' ORDER BY a.ZDATECREATED DESC LIMIT 1",-1,&asset,NULL)==SQLITE_OK && sqlite3_step(asset)==SQLITE_ROW){int bytes=sqlite3_column_bytes(asset,0);out[@"ownPhotoUUIDBytes"]=@(bytes);if(bytes==16){NSUUID *uuid=[[NSUUID alloc] initWithUUIDBytes:sqlite3_column_blob(asset,0)];out[@"ownPhotoUUID"]=uuid.UUIDString;}else if(sqlite3_column_type(asset,0)==SQLITE_TEXT){const char *text=(const char *)sqlite3_column_text(asset,0);if(text)out[@"ownPhotoUUID"]=@(text);}}
 sqlite3_finalize(asset);sqlite3_close(photos);

 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
