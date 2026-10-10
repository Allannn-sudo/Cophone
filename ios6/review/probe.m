#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sqlite3.h>

static void methods(Class cls) {
    if(!cls)return;
    printf("CLASS %s\n",class_getName(cls));
    unsigned count=0;Method *list=class_copyMethodList(cls,&count);
    for(unsigned i=0;i<count;i++)printf("  %s %s\n",sel_getName(method_getName(list[i])),method_getTypeEncoding(list[i]));
    free(list);
}
int main(int argc,char **argv) {
 @autoreleasepool {
  void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_NOW);
  CFStringRef (*front)(void)=dlsym(sbs,"SBSCopyFrontmostApplicationDisplayIdentifier");
  NSString *value=front ? CFBridgingRelease(front()) : nil;
  printf("FRONT %s\n",value.UTF8String ?: "<none>");
  void *notes=dlopen("/System/Library/PrivateFrameworks/Notes.framework/Notes",RTLD_NOW);
  printf("NOTES_LOAD %s\n",notes ? "OK" : dlerror());
  methods(object_getClass(NSClassFromString(@"SBSLocalNotificationClient")));
  for(NSString *name in @[@"NoteContext",@"NoteObject",@"NoteBodyObject",@"NoteStoreObject",@"NoteCollectionObject"]) {
   methods(NSClassFromString(name));methods(object_getClass(NSClassFromString(name)));
  }
  for(NSString *name in @[@"NoteStoreGetSharedNoteStore",@"NoteCreate",@"NoteStoreAddNote",@"NoteStoreSave",@"NoteSetTitle",@"NoteSetContent",@"NoteSetSummary"])printf("SYMBOL %s %p\n",name.UTF8String,dlsym(notes,name.UTF8String));
  sqlite3 *db=NULL;
  if(sqlite3_open_v2("/var/mobile/Library/Notes/notes.sqlite",&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK) {
   sqlite3_stmt *stmt=NULL;sqlite3_prepare_v2(db,"SELECT name,sql FROM sqlite_master WHERE type='table'",-1,&stmt,NULL);
   while(sqlite3_step(stmt)==SQLITE_ROW)printf("SCHEMA %s %s\n",sqlite3_column_text(stmt,0),sqlite3_column_text(stmt,1));sqlite3_finalize(stmt);
  }sqlite3_close(db);
  NSDictionary *history=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Safari/History.plist"];
  printf("SAFARI_KEYS %s\n",[[history allKeys] description].UTF8String ?: "<none>");
  id rows=[history objectForKey:@"WebHistoryDates"];
  printf("SAFARI_ROW_KEYS %s\n",[rows isKindOfClass:[NSArray class]] && [rows count] ? [[[[rows objectAtIndex:0] allKeys] description] UTF8String] : "<none>");
  for(NSString *base in @[@"/Applications",@"/var/mobile/Applications"]) {
   for(NSString *item in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:base error:NULL]) {
    NSString *folder=[base stringByAppendingPathComponent:item];
    NSArray *candidates=[item hasSuffix:@".app"]?@[item]:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
    for(NSString *candidate in candidates)if([candidate hasSuffix:@".app"]) {
     NSString *path=[item hasSuffix:@".app"]?folder:[folder stringByAppendingPathComponent:candidate];
     NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
     NSString *name=[[NSString stringWithFormat:@"%@ %@ %@",[info objectForKey:@"CFBundleIdentifier"],[info objectForKey:@"CFBundleName"],[info objectForKey:@"CFBundleDisplayName"]] lowercaseString];
     if([name rangeOfString:@"bili"].location!=NSNotFound || [[info objectForKey:@"CFBundleIdentifier"] hasPrefix:@"ai.whaletech.cophone"])
      printf("TARGET_APP %s %s %s\n",path.UTF8String,[[info objectForKey:@"CFBundleIdentifier"] UTF8String],[[info objectForKey:@"CFBundleDisplayName"] UTF8String]);
    }
   }
  }
 }
 return 0;
}
