// Read only our own App identities and bundle locations, never user content.
#import <Foundation/Foundation.h>
static void inspect(NSString *path,NSMutableArray *out){
 NSDictionary *p=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
 NSString *identifier=p[@"CFBundleIdentifier"];
 if(![identifier hasPrefix:@"ai.whaletech.cophone."])return;
 [out addObject:@{@"path":path,@"bundle":identifier,@"version":p[@"CFBundleShortVersionString"] ?: @"",@"displayName":p[@"CFBundleDisplayName"] ?: @"",@"name":p[@"CFBundleName"] ?: @"",@"icons":p[@"CFBundleIconFiles"] ?: @[]}];
}
int main(){@autoreleasepool {
 NSFileManager *fm=NSFileManager.defaultManager;NSMutableArray *out=[NSMutableArray array];
 for(NSString *base in @[@"/Applications",@"/var/mobile/Applications"]){
  for(NSString *entry in [fm contentsOfDirectoryAtPath:base error:NULL]){
   NSString *path=[base stringByAppendingPathComponent:entry];
   if([entry hasSuffix:@".app"]){inspect(path,out);continue;}
   if([base isEqual:@"/var/mobile/Applications"])for(NSString *app in [fm contentsOfDirectoryAtPath:path error:NULL])if([app hasSuffix:@".app"])inspect([path stringByAppendingPathComponent:app],out);
  }
 }
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
