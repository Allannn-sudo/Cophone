#import <Foundation/Foundation.h>
#import "ReviewSession.h"
#import "ContentReader.h"
#import <sqlite3.h>
#import <zlib.h>
#define CHECK(x) do { if(!(x)){fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#x);return 1;} } while(0)
static NSDictionary *history(NSString *url,double time,NSInteger count) {
 return @{@"WebHistoryDates":@[@{@"":url,@"title":@"演示页面",@"lastVisitedDate":@(time),@"visitCount":@(count)}]};
}
int main(void) {@autoreleasepool {
 double t=1791532800;
 ReviewSession *s=[[ReviewSession alloc] initWithID:@"test" at:t history:@{}];
 [s observe:nil name:nil locked:NO at:t+1];[s observe:nil name:nil locked:NO at:t+20];CHECK(!s.readyToCommit);
 [s observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+21];
 [s observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+25];
 [s readHistory:history(@"https://user:password@example.com/page?q=secret#fragment",t+23-978307200,1) at:t+25];
 CHECK(s.pages.count==1);CHECK([s.pages[0][@"url"] isEqual:@"https://example.com/page"]);
 [s readHistory:history(@"https://user:password@example.com/page?q=secret#fragment",t+23-978307200,1) at:t+25];CHECK(s.pages.count==1);
 [s observe:nil name:nil locked:NO at:t+26];[s observe:nil name:nil locked:NO at:t+30];CHECK(!s.readyToCommit);
 [s observe:@"net.iosipa.oldbili" name:@"oldbili" locked:NO at:t+31];CHECK(s.visits.count==2);
 [s readHistory:history(@"https://another.example/",t+32,1) at:t+33];CHECK(s.pages.count==1);
 [s observe:nil name:nil locked:YES at:t+40];[s observe:nil name:nil locked:YES at:t+100];CHECK(!s.readyToCommit);
 [s observe:nil name:nil locked:NO at:t+101];[s observe:nil name:nil locked:NO at:t+106];CHECK(!s.readyToCommit);
 [s observe:nil name:nil locked:NO at:t+107];CHECK(s.readyToCommit);CHECK([s.status isEqual:@"finishing"]);
 NSString *note=[s noteText];CHECK([note rangeOfString:@"oldbili"].location!=NSNotFound);CHECK([note hasPrefix:@"演示页面｜浏览回顾\n目视官 · "]);
 CHECK([note rangeOfString:@"password"].location==NSNotFound);CHECK([note rangeOfString:@"secret"].location==NSNotFound);
 ReviewSession *old=[[ReviewSession alloc] initWithID:@"old" at:t history:history(@"https://example.com/",t-20,1)];
 [old observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+1];[old observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+10];
 [old readHistory:history(@"https://example.com/",t-20,1) at:t+10];CHECK(old.pages.count==0);
 [old readHistory:history(@"https://example.com/",t+5,2) at:t+10];CHECK(old.pages.count==1);
 [old readHistory:history(@"https://previous.example/",t-10,3) at:t+10];CHECK(old.pages.count==1);
 [old observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+901];CHECK([old.status isEqual:@"paused"]);CHECK(!old.readyToCommit);
 ReviewSession *cancelled=[[ReviewSession alloc] initWithID:@"cancelled" at:t history:@{}];cancelled.status=@"cancelled";
 [cancelled observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+1];CHECK(cancelled.visits.count==0);
 CHECK([ReviewAppDisplayName(@"example.app",@" \n\t",@{@"CFBundleDisplayName":@" 应用中文名 "},@{@"CFBundleDisplayName":@"Raw name"}) isEqual:@"应用中文名"]);
 CHECK([ReviewAppDisplayName(@"example.app",nil,@{},@{@"CFBundleDisplayName":@"",@"CFBundleName":@"Fallback name"}) isEqual:@"Fallback name"]);
 CHECK([ReviewAppDisplayName(@"example.app",@42,@{@"CFBundleName":@"本地名称"},@{}) isEqual:@"本地名称"]);
 CHECK([ReviewAppDisplayName(@"example.app",@"",nil,nil) isEqual:@"example.app"]);
 CHECK([ReviewAppDisplayName(@"example.app",@" System name ",nil,nil) isEqual:@"System name"]);
 ReviewSession *blank=[[ReviewSession alloc] initWithID:@"blank" at:t history:@{}];
 [blank observe:@"example.app" name:@" \n\t" locked:NO at:t+1];
 CHECK([blank.visits[0][@"name"] isEqual:@"example.app"]);
 CHECK([[blank noteText] rangeOfString:@"example.app · 0秒"].location!=NSNotFound);
 [blank observe:@"example.app" name:@"真正应用名" locked:NO at:t+2];
 CHECK(blank.visits.count==1);CHECK([blank.visits[0][@"name"] isEqual:@"真正应用名"]);
 [blank observe:@"example.app" name:@"" locked:NO at:t+3];
 CHECK([blank.visits[0][@"name"] isEqual:@"真正应用名"]);
 [blank observe:nil name:nil locked:NO at:t+4];[blank observe:nil name:nil locked:NO at:t+10];
 CHECK(blank.readyToCommit);CHECK([[blank noteText] rangeOfString:@"真正应用名 · 3秒"].location!=NSNotFound);
 // Treat actual cached HTML as excerpts; never include scripts, navigation or cookies.
 NSString *html=@"<html><nav>导航</nav><article><p>正文 &amp; &#x4E2D;&#25991;</p><script>secret()</script><style>hidden</style></article></html>";
 CHECK([ReviewHTMLExcerpt([html dataUsingEncoding:NSUTF8StringEncoding]) isEqual:@"正文 & 中文"]);
 CHECK([ReviewHTMLExcerpt([@"{\"script\":\"<script>bad</script>\"}" dataUsingEncoding:NSUTF8StringEncoding]) isEqual:@""]);
 CHECK(ReviewHTMLExcerpt([NSMutableData dataWithLength:600*1024]).length==0);
 NSData *videoJSON=[NSJSONSerialization dataWithJSONObject:@{@"code":@0,@"data":@{@"View":@{@"title":@"本轮视频",@"bvid":@"BV1TEST",@"owner":@{@"name":@"测试UP"},@"desc":@"视频简介"}}} options:0 error:NULL];
 CHECK([ReviewVideoMetadata(videoJSON)[@"author"] isEqual:@"测试UP"]);
 CHECK(!ReviewVideoMetadata([@"{\"code\":null,\"data\":{}}" dataUsingEncoding:NSUTF8StringEncoding]));
 CHECK(!ReviewVideoMetadata([@"{\"code\":0,\"data\":{\"item\":[{\"title\":\"推荐\"}]}}" dataUsingEncoding:NSUTF8StringEncoding]));
 // Gzip bodies are supported, but decompression bombs are bounded.
 z_stream zipped={0};CHECK(deflateInit2(&zipped,Z_DEFAULT_COMPRESSION,Z_DEFLATED,15+16,8,Z_DEFAULT_STRATEGY)==Z_OK);
 NSMutableData *gzip=[NSMutableData dataWithLength:videoJSON.length+200];zipped.next_in=(Bytef *)videoJSON.bytes;zipped.avail_in=(uInt)videoJSON.length;zipped.next_out=gzip.mutableBytes;zipped.avail_out=(uInt)gzip.length;
 CHECK(deflate(&zipped,Z_FINISH)==Z_STREAM_END);gzip.length=zipped.total_out;deflateEnd(&zipped);
 CHECK([ReviewVideoMetadata(gzip)[@"title"] isEqual:@"本轮视频"]);
 ReviewSession *v=[[ReviewSession alloc] initWithID:@"private-guid" at:t history:@{}];
 NSMutableDictionary *row=[ReviewVideoMetadata(videoJSON) mutableCopy];row[@"time"]=@(t+3);row[@"cacheKey"]=@"private-cache-path|1";
 [v setInitialVideos:@[row]];[v observe:@"net.iosipa.oldbili" name:@"oldbili" locked:NO at:t+1];[v observe:@"net.iosipa.oldbili" name:@"oldbili" locked:NO at:t+5];
 [v readVideos:@[row] at:t+5];CHECK(v.videos.count==0);row[@"cacheKey"]=@"private-cache-path|2";
 [v readVideos:@[row] at:t+5];CHECK(v.videos.count==1);CHECK(!v.videos[0][@"cacheKey"]);[v readVideos:@[row] at:t+6];CHECK(v.videos.count==1);
 row[@"videoID"]=@"another";row[@"time"]=@(t+100);[v readVideos:@[row] at:t+100];CHECK(v.videos.count==1);
 NSString *publicJSON=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:[v snapshot] options:0 error:NULL] encoding:NSUTF8StringEncoding];
 CHECK([publicJSON rangeOfString:@"private-cache-path"].location==NSNotFound);CHECK([[v noteText] rangeOfString:@"private-guid"].location==NSNotFound);
 CHECK([[v noteText] rangeOfString:@"本轮视频"].location!=NSNotFound);
 // Read only strict video-detail routes; recommended lists and malformed query-less POST URLs are ignored.
 NSString *dbPath=[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
 sqlite3 *db=NULL;CHECK(sqlite3_open(dbPath.UTF8String,&db)==SQLITE_OK);
 CHECK(sqlite3_exec(db,"CREATE TABLE cfurl_cache_response(entry_ID INTEGER,request_key TEXT,time_stamp TEXT);CREATE TABLE cfurl_cache_receiver_data(entry_ID INTEGER,receiver_data BLOB);",NULL,NULL,NULL)==SQLITE_OK);
 NSArray *urls=@[@"https://api.bilibili.com/x/web-interface/view/detail?bvid=BV1TEST",@"https://api.bilibili.com/x/web-interface/view/detailPOSTsecret",@"https://evil.example/x/web-interface/view/detail",@"https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd"];
 for(NSUInteger n=0;n<urls.count;n++) {
     sqlite3_stmt *q=NULL;sqlite3_prepare_v2(db,"INSERT INTO cfurl_cache_response VALUES(?,?, '2026-10-09 14:04:52')",-1,&q,NULL);sqlite3_bind_int(q,1,(int)n);sqlite3_bind_text(q,2,[urls[n] UTF8String],-1,SQLITE_TRANSIENT);CHECK(sqlite3_step(q)==SQLITE_DONE);sqlite3_finalize(q);
     sqlite3_prepare_v2(db,"INSERT INTO cfurl_cache_receiver_data VALUES(?,?)",-1,&q,NULL);sqlite3_bind_int(q,1,(int)n);sqlite3_bind_blob(q,2,videoJSON.bytes,(int)videoJSON.length,SQLITE_TRANSIENT);CHECK(sqlite3_step(q)==SQLITE_DONE);sqlite3_finalize(q);
 }
 sqlite3_close(db);CHECK(ReviewCachedVideos(@[dbPath]).count==1);
 // Fresh successful playback + an older detail response identifies a revisit;
 // unrelated IDs, error responses and malformed endpoint suffixes do not.
 CHECK(sqlite3_open(dbPath.UTF8String,&db)==SQLITE_OK);
 NSArray *playURLs=@[@"https://api.bilibili.com/x/player/wbi/playurl?bvid=BV1TEST&w_rid=private-signature",@"https://api.bilibili.com/x/player/wbi/playurl?bvid=BVUNRELATED",@"https://evil.example/x/player/wbi/playurl?bvid=BV1TEST",@"https://api.bilibili.com/x/player/wbi/playurlPOSTsecret?bvid=BV1TEST",@"https://api.bilibili.com/x/player/playurl?bvid=BV1TEST"];
 for(NSUInteger n=0;n<playURLs.count;n++) {
     sqlite3_stmt *q=NULL;int entry=(int)n+20;
     sqlite3_prepare_v2(db,"INSERT INTO cfurl_cache_response VALUES(?,?, '2026-10-09 14:05:22')",-1,&q,NULL);sqlite3_bind_int(q,1,entry);sqlite3_bind_text(q,2,[playURLs[n] UTF8String],-1,SQLITE_TRANSIENT);CHECK(sqlite3_step(q)==SQLITE_DONE);sqlite3_finalize(q);
     NSData *body=[NSJSONSerialization dataWithJSONObject:@{@"code":n==4?@(-1):@0,@"data":@{}} options:0 error:NULL];
     sqlite3_prepare_v2(db,"INSERT INTO cfurl_cache_receiver_data VALUES(?,?)",-1,&q,NULL);sqlite3_bind_int(q,1,entry);sqlite3_bind_blob(q,2,body.bytes,(int)body.length,SQLITE_TRANSIENT);CHECK(sqlite3_step(q)==SQLITE_DONE);sqlite3_finalize(q);
 }
 sqlite3_close(db);
 NSArray *cached=ReviewCachedVideos(@[dbPath]);CHECK(cached.count==2);
 NSDictionary *play=cached[1];CHECK([play[@"source"] isEqual:@"oldbili 播放请求与视频详情"]);
 double played=[play[@"time"] doubleValue];ReviewSession *revisit=[[ReviewSession alloc] initWithID:@"revisit" at:played-10 history:@{}];
 [revisit setInitialVideos:@[cached[0]]];[revisit observe:@"net.iosipa.oldbili" name:@"oldbili" locked:NO at:played-1];[revisit observe:@"net.iosipa.oldbili" name:@"oldbili" locked:NO at:played+5];
 [revisit readVideos:cached at:played+5];CHECK(revisit.videos.count==1);CHECK([revisit.videos[0][@"title"] isEqual:@"本轮视频"]);
 CHECK([[[revisit snapshot] description] rangeOfString:@"private-signature"].location==NSNotFound);
 ReviewSession *stalePlay=[[ReviewSession alloc] initWithID:@"stale-play" at:played+100 history:@{}];[stalePlay setInitialVideos:cached];[stalePlay observe:@"net.iosipa.oldbili" name:@"oldbili" locked:NO at:played+101];[stalePlay readVideos:cached at:played+105];CHECK(stalePlay.videos.count==0);
 CHECK(ReviewCachedPage(dbPath,@"https://missing.example/").length==0);[[NSFileManager defaultManager] removeItemAtPath:dbPath error:NULL];
 ReviewSession *tabSession=[[ReviewSession alloc] initWithID:@"tabs" at:t history:@{}];
 [tabSession observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+1];[tabSession observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+10];
 NSDictionary *activeTab=@{@"SafariStateDocumentUserVisibleURL":@"https://example.com/current?token=private",@"SafariStateDocumentTitle":@"继续阅读的旧标签",@"SafariStateDocumentLastViewedTime":@(t+3-978307200)};
 NSDictionary *tabs=@{@"SafariStateActiveDocumentIndex":@0,@"SafariStateDocuments":@[activeTab,@{@"SafariStateDocumentURL":@"https://example.com/private-old-tab"}]};
 [tabSession readTabState:tabs modifiedAt:t-1 at:t+10];CHECK(tabSession.pages.count==0);
 [tabSession readTabState:@{@"SafariStateActiveDocumentIndex":@99,@"SafariStateDocuments":@[activeTab]} modifiedAt:t+8 at:t+10];CHECK(tabSession.pages.count==0);
 [tabSession readTabState:tabs modifiedAt:t+8 at:t+10];CHECK(tabSession.pages.count==1);CHECK([tabSession.pages[0][@"title"] isEqual:@"继续阅读的旧标签"]);
 CHECK([tabSession.pages[0][@"url"] isEqual:@"https://example.com/current"]);
 [tabSession readTabState:tabs modifiedAt:t+9 at:t+11];CHECK(tabSession.pages.count==1);
 ReviewSession *wrongApp=[[ReviewSession alloc] initWithID:@"wrong" at:t history:@{}];[wrongApp observe:@"example.app" name:@"Other" locked:NO at:t+10];
 [wrongApp readTabState:tabs modifiedAt:t+8 at:t+10];CHECK(wrongApp.pages.count==0);
 // App sections remain distinct and repeat visits are merged without inventing content.
 ReviewSession *grouped=[[ReviewSession alloc] initWithID:@"grouped" at:t history:@{}];
 [grouped observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+1];
 [grouped observe:@"example.one" name:@"同名应用" locked:NO at:t+3];
 [grouped observe:@"com.apple.mobilesafari" name:@"Safari" locked:NO at:t+4];
 [grouped observe:@"example.two" name:@"同名应用" locked:NO at:t+7];
 [grouped observe:nil name:nil locked:NO at:t+9];
 NSString *groupedNote=[grouped noteText];CHECK([groupedNote hasPrefix:@"Safari、同名应用使用回顾\n目视官 · "]);
 CHECK([groupedNote componentsSeparatedByString:@"\nSafari · "].count==2);
 CHECK([groupedNote componentsSeparatedByString:@"\n同名应用 · "].count==3);
 CHECK([groupedNote rangeOfString:@"未读取应用内内容"].location!=NSNotFound);
 CHECK([groupedNote rangeOfString:@"未取得本轮页面内容"].location!=NSNotFound);
 puts("PASS native ReviewSession: desktop debounce / app switch / lock / Safari delta / URL sanitizing / timeout / cancellation / blank names & metadata fallback / late name recovery / short app visit / HTML & gzip / scoped video cache / compact notes");
 }return 0;}
