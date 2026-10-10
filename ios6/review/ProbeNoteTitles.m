// Creates three private fixture notes, verifies title/body via NotesWriter, then
// removes only those exact fresh UUIDs. Never selects or modifies existing notes.
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <dlfcn.h>
#import "NotesWriter.h"
#import "NotePresentation.h"
#import "ReviewSession.h"
@interface NSObject(CophoneTitleProbe)
- (NSArray *)allNotesMatchingPredicate:(NSPredicate *)predicate;
- (BOOL)saveOutsideApp:(NSError **)error;
@end
int main(){@autoreleasepool {
 dlopen("/System/Library/PrivateFrameworks/Notes.framework/Notes",RTLD_NOW);Class cls=NSClassFromString(@"NoteContext");
 if(!cls || ![cls instancesRespondToSelector:@selector(allNotesMatchingPredicate:)])return 2;
 ReviewSession *session=[[ReviewSession alloc] initWithID:NSUUID.UUID.UUIDString at:NSDate.date.timeIntervalSince1970 history:@{}];
 [session.pages addObject:@{@"title":@"扩散模型基础"}];[session.videos addObject:@{@"title":@"AI Agent入门"}];
 NSArray *titles=@[CophoneNoteTitle(@"扩散模型的基本原理\n原文要点",@"fallback"),CophoneNoteTitle(@"AI Agent入门视频怎么选\n比较理由",@"fallback"),[session noteTitle]];
 NSMutableArray *created=[NSMutableArray array],*results=[NSMutableArray array];BOOL all=YES;
 for(NSUInteger i=0;i<titles.count;i++){
  NSString *ident=NSUUID.UUID.UUIDString,*title=titles[i],*body=i==2?[session noteText]:[NSString stringWithFormat:@"%@\n\n标题显示检查：临时样例，验证后自动移除。",title];
  [created addObject:ident];NSError *error=nil;NSDictionary *receipt=WriteNamedNote(ident,body,title,&error);
  BOOL verified=[receipt[@"verified"] boolValue] && [receipt[@"title"] isEqual:title];all=all && verified;
  [results addObject:@{@"kind":@[@"summary",@"videos",@"recap"][i],@"title":title,@"verified":@(verified),@"error":error.localizedDescription ?: @""}];
 }
 id context=[cls new];NSArray *notes=[context allNotesMatchingPredicate:[NSPredicate predicateWithFormat:@"guid IN %@",created]];NSUInteger removed=0;
 for(NSManagedObject *note in notes){if([created containsObject:[note valueForKey:@"guid"]]){[note.managedObjectContext deleteObject:note];removed++;}}
 NSError *error=nil;BOOL cleaned=[context saveOutsideApp:&error];
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:@{@"cases":results,@"allVerified":@(all),@"cleanupSaved":@(cleaned),@"removedOwnFixtures":@(removed),@"cleanupError":error.localizedDescription ?: @""} options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
 return all && cleaned && removed==3?0:3;
}return 0;}
