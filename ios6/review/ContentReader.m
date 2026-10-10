#import "ContentReader.h"
#import <sqlite3.h>
#import <zlib.h>

NSString *ReviewCompactText(id value,NSUInteger limit) {
    if(![value isKindOfClass:[NSString class]])return @"";
    NSString *s=[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    s=[s stringByReplacingOccurrencesOfString:@"\\s+" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0,s.length)];
    if(s.length>limit)s=[[s substringWithRange:[s rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,limit)]] stringByAppendingString:@"…"];
    return s;
}
static NSData *decoded(NSData *data) {
    if(!data.length || data.length>512*1024)return nil;
    const unsigned char *bytes=data.bytes;
    if(data.length<2 || bytes[0]!=0x1f || bytes[1]!=0x8b)return data;
    z_stream stream={0};stream.next_in=(Bytef *)data.bytes;stream.avail_in=(uInt)data.length;
    if(inflateInit2(&stream,15+32)!=Z_OK)return nil;
    NSMutableData *result=[NSMutableData data];int code=Z_OK;
    while(code==Z_OK && result.length<=512*1024) {
        unsigned char buffer[8192];stream.next_out=buffer;stream.avail_out=sizeof(buffer);
        code=inflate(&stream,Z_NO_FLUSH);[result appendBytes:buffer length:sizeof(buffer)-stream.avail_out];
    }
    inflateEnd(&stream);return code==Z_STREAM_END && result.length<=512*1024?result:nil;
}
static NSString *replace(NSString *s,NSString *pattern,NSString *with) {
    return [s stringByReplacingOccurrencesOfString:pattern withString:with options:NSRegularExpressionSearch range:NSMakeRange(0,s.length)];
}
NSString *ReviewHTMLExcerpt(NSData *data) {
    data=decoded(data);if(!data)return @"";
    NSString *s=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if(!s)s=[[NSString alloc] initWithData:data encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
    if(!s || [s rangeOfString:@"<(html|body|article|main|p|div)\\b" options:NSRegularExpressionSearch|NSCaseInsensitiveSearch].location==NSNotFound)return @"";
    s=replace(s,@"(?is)<!--.*?-->|<(script|style|nav|header|footer|noscript)\\b[^>]*>.*?</\\1\\s*>",@" ");
    NSRegularExpression *article=[NSRegularExpression regularExpressionWithPattern:@"(?is)<(?:article|main)\\b[^>]*>(.*?)</(?:article|main)\\s*>" options:0 error:NULL];
    NSTextCheckingResult *match=[article firstMatchInString:s options:0 range:NSMakeRange(0,s.length)];
    if(match)s=[s substringWithRange:[match rangeAtIndex:1]];
    s=replace(s,@"(?is)<[^>]*>",@" ");
    NSDictionary *entities=@{@"&nbsp;":@" ",@"&quot;":@"\"",@"&apos;":@"'",@"&lt;":@"<",@"&gt;":@">",@"&amp;":@"&",@"&mdash;":@"—",@"&ndash;":@"–"};
    for(NSString *key in entities)s=[s stringByReplacingOccurrencesOfString:key withString:entities[key]];
    NSRegularExpression *numeric=[NSRegularExpression regularExpressionWithPattern:@"&#(x[0-9a-fA-F]+|[0-9]+);" options:0 error:NULL];
    NSArray *matches=[numeric matchesInString:s options:0 range:NSMakeRange(0,s.length)];
    for(NSTextCheckingResult *m in [matches reverseObjectEnumerator]) {
        NSString *number=[s substringWithRange:[m rangeAtIndex:1]];unsigned int scalar=0;
        if([number hasPrefix:@"x"])[[NSScanner scannerWithString:[number substringFromIndex:1]] scanHexInt:&scalar];else scalar=(unsigned int)number.longLongValue;
        if(!scalar || scalar>0x10ffff || (scalar>=0xd800 && scalar<=0xdfff))continue;
        unichar chars[2];NSUInteger count=1;
        if(scalar>0xffff){scalar-=0x10000;chars[0]=0xd800+(scalar>>10);chars[1]=0xdc00+(scalar&0x3ff);count=2;}else chars[0]=scalar;
        s=[s stringByReplacingCharactersInRange:m.range withString:[NSString stringWithCharacters:chars length:count]];
    }
    return ReviewCompactText(s,700);
}
NSDictionary *ReviewVideoMetadata(NSData *data) {
    data=decoded(data);if(!data)return nil;
    id json=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if(![json isKindOfClass:[NSDictionary class]] || ![json[@"code"] respondsToSelector:@selector(integerValue)] || [json[@"code"] integerValue]!=0)return nil;
    id view=json[@"data"];if(![view isKindOfClass:[NSDictionary class]])return nil;
    if([view[@"View"] isKindOfClass:[NSDictionary class]])view=view[@"View"];
    NSString *title=ReviewCompactText(view[@"title"],120),*bvid=ReviewCompactText(view[@"bvid"],32);
    long long aid=[view[@"aid"] respondsToSelector:@selector(longLongValue)]?[view[@"aid"] longLongValue]:0;
    if(!title.length || (!bvid.length && aid<=0))return nil;
    NSDictionary *owner=[view[@"owner"] isKindOfClass:[NSDictionary class]]?view[@"owner"]:@{};
    NSString *identity=[bvid hasPrefix:@"BV"]?bvid:aid>0?[NSString stringWithFormat:@"av%lld",aid]:nil;
    if(!identity)return nil;
    return @{@"title":title,@"description":ReviewCompactText(view[@"desc"],400),@"author":ReviewCompactText(owner[@"name"],60),@"videoID":identity,@"aid":@(aid),@"url":[@"https://www.bilibili.com/video/" stringByAppendingString:identity],@"source":@"oldbili 视频详情缓存"};
}
NSArray *ReviewCachedVideos(NSArray *paths) {
    NSMutableArray *rows=[NSMutableArray array];
    NSDateFormatter *formatter=[[NSDateFormatter alloc] init];formatter.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];formatter.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];formatter.dateFormat=@"yyyy-MM-dd HH:mm:ss";
    for(NSString *path in paths) {
        sqlite3 *db=NULL;sqlite3_stmt *s=NULL;
        if(sqlite3_open_v2(path.UTF8String,&db,SQLITE_OPEN_READONLY,NULL)!=SQLITE_OK){sqlite3_close(db);continue;}
        sqlite3_busy_timeout(db,80);
        NSMutableDictionary *metadata=[NSMutableDictionary dictionary];
        const char *sql="SELECT r.entry_ID,r.request_key,r.time_stamp,b.receiver_data FROM cfurl_cache_response r JOIN cfurl_cache_receiver_data b ON r.entry_ID=b.entry_ID WHERE r.request_key LIKE '%/x/web-interface/view%' OR r.request_key LIKE '%/x/v2/view%' ORDER BY r.entry_ID DESC LIMIT 20";
        if(sqlite3_prepare_v2(db,sql,-1,&s,NULL)==SQLITE_OK)while(sqlite3_step(s)==SQLITE_ROW) {
            const unsigned char *key=sqlite3_column_text(s,1),*stamp=sqlite3_column_text(s,2);
            if(!key || !stamp || sqlite3_column_bytes(s,3)>512*1024)continue;
            NSURL *url=[NSURL URLWithString:[NSString stringWithUTF8String:(const char *)key]];
            if(![@[@"api.bilibili.com",@"app.bilibili.com"] containsObject:url.host] || ![@[@"/x/web-interface/view",@"/x/web-interface/view/detail",@"/x/v2/view"] containsObject:url.path])continue;
            NSString *timestamp=[NSString stringWithUTF8String:(const char *)stamp];NSDate *date=[formatter dateFromString:timestamp];if(!date)continue;
            NSDictionary *video=ReviewVideoMetadata([NSData dataWithBytes:sqlite3_column_blob(s,3) length:sqlite3_column_bytes(s,3)]);if(!video)continue;
            metadata[video[@"videoID"]]=video;
            if([video[@"aid"] longLongValue]>0)metadata[[NSString stringWithFormat:@"av%lld",[video[@"aid"] longLongValue]]]=video;
            NSMutableDictionary *row=[video mutableCopy];row[@"time"]=@(date.timeIntervalSince1970);
            row[@"cacheKey"]=[NSString stringWithFormat:@"%@|%lld|%@",path,sqlite3_column_int64(s,0),timestamp];
            [rows addObject:row];
        }
        sqlite3_finalize(s);s=NULL;
        // A fresh playback request can identify a revisited/cached video. Match only
        // an explicit video ID to actual detail metadata from this same app cache.
        const char *playSQL="SELECT r.entry_ID,r.request_key,r.time_stamp,b.receiver_data FROM cfurl_cache_response r JOIN cfurl_cache_receiver_data b ON r.entry_ID=b.entry_ID WHERE r.request_key LIKE '%/x/player/%playurl%' ORDER BY r.entry_ID DESC LIMIT 20";
        if(sqlite3_prepare_v2(db,playSQL,-1,&s,NULL)==SQLITE_OK)while(sqlite3_step(s)==SQLITE_ROW) {
            const char *raw=(const char *)sqlite3_column_text(s,1),*stamp=(const char *)sqlite3_column_text(s,2);
            if(!raw || !stamp || sqlite3_column_bytes(s,3)>512*1024)continue;
            NSURL *url=[NSURL URLWithString:[NSString stringWithUTF8String:raw]];
            if(![@[@"api.bilibili.com",@"app.bilibili.com"] containsObject:url.host] || ![@[@"/x/player/playurl",@"/x/player/wbi/playurl"] containsObject:url.path])continue;
            NSDictionary *video=nil;
            for(NSString *part in [url.query componentsSeparatedByString:@"&"]) {
                NSRange separator=[part rangeOfString:@"="];if(separator.location==NSNotFound)continue;
                NSString *key=[part substringToIndex:separator.location];
                if(![@[@"bvid",@"aid",@"avid"] containsObject:key])continue;
                NSString *value=[[part substringFromIndex:separator.location+1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                if([key isEqual:@"bvid"]) {
                    if([value rangeOfString:@"^BV[A-Za-z0-9]{4,30}$" options:NSRegularExpressionSearch].location!=NSNotFound)video=metadata[value];
                } else if([value rangeOfString:@"^[0-9]{1,18}$" options:NSRegularExpressionSearch].location!=NSNotFound && value.longLongValue>0)video=metadata[[NSString stringWithFormat:@"av%lld",value.longLongValue]];
                if(video)break;
            }
            if(!video)continue;
            NSData *body=decoded([NSData dataWithBytes:sqlite3_column_blob(s,3) length:sqlite3_column_bytes(s,3)]);
            id response=body?[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]:nil;
            if(![response isKindOfClass:[NSDictionary class]] || ![response[@"code"] respondsToSelector:@selector(integerValue)] || [response[@"code"] integerValue]!=0 || ![response[@"data"] isKindOfClass:[NSDictionary class]])continue;
            NSString *timestamp=[NSString stringWithUTF8String:stamp];NSDate *date=[formatter dateFromString:timestamp];if(!date)continue;
            NSMutableDictionary *row=[video mutableCopy];row[@"time"]=@(date.timeIntervalSince1970);
            row[@"source"]=@"oldbili 播放请求与视频详情";
            row[@"cacheKey"]=[NSString stringWithFormat:@"%@|play|%lld|%@",path,sqlite3_column_int64(s,0),timestamp];[rows addObject:row];
        }
        sqlite3_finalize(s);sqlite3_close(db);
    }
    return rows;
}
NSString *ReviewCachedPage(NSString *database,NSString *url) {
    sqlite3 *db=NULL;sqlite3_stmt *s=NULL;NSString *excerpt=@"";
    if(sqlite3_open_v2(database.UTF8String,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK) {
        sqlite3_busy_timeout(db,80);
        const char *sql="SELECT b.receiver_data FROM cfurl_cache_response r JOIN cfurl_cache_receiver_data b ON r.entry_ID=b.entry_ID WHERE r.request_key=? LIMIT 1";
        if(sqlite3_prepare_v2(db,sql,-1,&s,NULL)==SQLITE_OK) {
            sqlite3_bind_text(s,1,url.UTF8String,-1,SQLITE_TRANSIENT);
            if(sqlite3_step(s)==SQLITE_ROW && sqlite3_column_bytes(s,0)<=512*1024)
                excerpt=ReviewHTMLExcerpt([NSData dataWithBytes:sqlite3_column_blob(s,0) length:sqlite3_column_bytes(s,0)]);
        }
        sqlite3_finalize(s);
    }
    sqlite3_close(db);return excerpt;
}
