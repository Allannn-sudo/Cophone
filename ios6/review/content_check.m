#import <Foundation/Foundation.h>
#import "ContentReader.h"
int main(int argc,char **argv) {@autoreleasepool {
    NSMutableArray *paths=[NSMutableArray array];NSString *base=@"/var/mobile/Applications";NSFileManager *fm=[NSFileManager defaultManager];
    for(NSString *container in [fm contentsOfDirectoryAtPath:base error:NULL]) {
        NSString *folder=[base stringByAppendingPathComponent:container];
        for(NSString *app in [fm contentsOfDirectoryAtPath:folder error:NULL])if([app hasSuffix:@".app"]) {
            NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[[folder stringByAppendingPathComponent:app] stringByAppendingPathComponent:@"Info.plist"]];NSString *bundle=info[@"CFBundleIdentifier"];
            if([@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:bundle])[paths addObject:[folder stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Caches/%@/Cache.db",bundle]]];
        }
    }
    NSDictionary *tabs=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Safari/SuspendState.plist"];
    printf("SAFARI_TAB_STATE_ROOT_KEYS=%s\n",[[tabs.allKeys sortedArrayUsingSelector:@selector(compare:)] description].UTF8String ?: "missing");
    for(NSString *key in tabs)if([tabs[key] isKindOfClass:[NSArray class]] && [tabs[key] count]) {
        id first=tabs[key][0];if([first isKindOfClass:[NSDictionary class]])printf("SAFARI_TAB_ITEM_KEYS=%s\n",[[first allKeys] description].UTF8String);
    }
    id index=tabs[@"SafariStateActiveDocumentIndex"],docs=tabs[@"SafariStateDocuments"];
    if([index respondsToSelector:@selector(unsignedIntegerValue)] && [docs isKindOfClass:[NSArray class]] && [index unsignedIntegerValue]<[docs count]) {
        id stamp=docs[[index unsignedIntegerValue]][@"SafariStateDocumentLastViewedTime"];
        printf("ACTIVE_TAB_TIME_TYPE=%s VALUE=%s FILE_MTIME=%s\n",NSStringFromClass([stamp class]).UTF8String,[stamp description].UTF8String,[[[fm attributesOfItemAtPath:@"/var/mobile/Library/Safari/SuspendState.plist" error:NULL] objectForKey:NSFileModificationDate] description].UTF8String);
    }
    NSArray *videos=ReviewCachedVideos(paths);NSUInteger valid=0;
    for(NSDictionary *video in videos)if([video[@"title"] length] && [video[@"videoID"] length] && [video[@"time"] doubleValue]>0)valid++;
    // No historical titles/URLs/credential material printed or persisted.
    printf("CONTENT_READER_DEVICE_CHECK caches=%lu validVideoDetails=%lu\n",(unsigned long)paths.count,(unsigned long)valid);
    NSString *sample=@"<html><article><p>cophone 正文摘录验证</p><script>should_be_removed</script></article></html>";
    BOOL html=[ReviewHTMLExcerpt([sample dataUsingEncoding:NSUTF8StringEncoding]) isEqual:@"cophone 正文摘录验证"];
    printf("HTML_PARSER_ON_IOS6=%s\n",html?"PASS":"FAIL");return valid && html?0:1;
}return 1;}
