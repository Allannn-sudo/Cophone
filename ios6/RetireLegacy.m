// Reversible retirement of the exact, obsolete system App. Leaves its data,
// the current user App, all keys, and SpringBoard registration untouched.
#import <Foundation/Foundation.h>
int main(int argc,char **argv){@autoreleasepool {
 if(argc!=2 || ![[NSString stringWithUTF8String:argv[1]] isEqual:@"--archive-legacy"])return 2;
 NSString *old=@"/Applications/CoPhone.app";
 NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[old stringByAppendingPathComponent:@"Info.plist"]];
 if(![info[@"CFBundleIdentifier"] isEqual:@"ai.whaletech.cophone.legacy"] || ![info[@"CFBundleShortVersionString"] isEqual:@"0.2.1"]){fputs("Exact legacy 0.2.1 bundle not found; no changes.\n",stderr);return 3;}
 NSFileManager *fm=NSFileManager.defaultManager;BOOL current=NO;
 for(NSString *dir in [fm contentsOfDirectoryAtPath:@"/var/mobile/Applications" error:NULL]){
  NSString *folder=[@"/var/mobile/Applications" stringByAppendingPathComponent:dir];
  for(NSString *app in [fm contentsOfDirectoryAtPath:folder error:NULL])if([app hasSuffix:@".app"]){
   NSDictionary *p=[NSDictionary dictionaryWithContentsOfFile:[[folder stringByAppendingPathComponent:app] stringByAppendingPathComponent:@"Info.plist"]];
   if([p[@"CFBundleIdentifier"] isEqual:@"ai.whaletech.cophone.classic"] && [p[@"CFBundleDisplayName"] isEqual:@"cophone"])current=YES;
  }
 }
 if(!current){fputs("Current cophone not found; no changes.\n",stderr);return 4;}
 NSString *archive=@"/var/mobile/Library/cophone-retired";NSError *error=nil;
 if(![fm createDirectoryAtPath:archive withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:&error] && ![[fm attributesOfItemAtPath:archive error:NULL][NSFileType] isEqual:NSFileTypeDirectory])return 5;
 NSString *backup=[archive stringByAppendingPathComponent:[NSString stringWithFormat:@"CoPhone-legacy-0.2.1-%@.app",NSUUID.UUID.UUIDString]];
 if(![fm moveItemAtPath:old toPath:backup error:&error]){fputs("Legacy archive move failed; no cache refresh requested.\n",stderr);return 6;}
 NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:[backup stringByAppendingPathComponent:@"Info.plist"]];
 if([fm fileExistsAtPath:old] || ![saved[@"CFBundleIdentifier"] isEqual:@"ai.whaletech.cophone.legacy"])return 7;
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:@{@"legacyArchived":@YES,@"backup":backup,@"currentAppPreserved":@YES,@"legacyDataPreserved":@YES,@"desktopReloaded":@NO} options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
