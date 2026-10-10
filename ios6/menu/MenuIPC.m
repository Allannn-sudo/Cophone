#import "MenuIPC.h"
#import <notify.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <dispatch/dispatch.h>
static const int MenuPort=18769;
static const char *HighName="ai.whaletech.cophone.menu.capability.high",*LowName="ai.whaletech.cophone.menu.capability.low";
static NSString *tokenString(uint64_t high,uint64_t low){return [NSString stringWithFormat:@"%016llx%016llx",(unsigned long long)high,(unsigned long long)low];}
static BOOL equalToken(NSString *a,NSString *b) {
    NSData *x=[a dataUsingEncoding:NSASCIIStringEncoding],*y=[b dataUsingEncoding:NSASCIIStringEncoding];
    if(x.length!=32 || y.length!=32)return NO;const unsigned char *p=x.bytes,*q=y.bytes;unsigned char different=0;
    for(int i=0;i<32;i++)different|=p[i]^q[i];return different==0;
}
static NSDictionary *headers(NSData *raw,NSUInteger *bodyOffset) {
    NSData *separator=[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];NSRange split=[raw rangeOfData:separator options:0 range:NSMakeRange(0,raw.length)];
    if(split.location==NSNotFound || split.location>4096)return nil;
    NSString *text=[[NSString alloc] initWithData:[raw subdataWithRange:NSMakeRange(0,split.location)] encoding:NSASCIIStringEncoding];
    NSArray *lines=[text componentsSeparatedByString:@"\r\n"];if(!lines.count || lines.count>32)return nil;
    NSMutableDictionary *out=[NSMutableDictionary dictionaryWithObject:lines[0] forKey:@":first"];
    for(NSUInteger i=1;i<lines.count;i++) {
        NSString *line=lines[i];NSRange colon=[line rangeOfString:@":"];if(colon.location==NSNotFound || colon.location==0)return nil;
        NSString *key=[[line substringToIndex:colon.location] lowercaseString];
        if([key rangeOfString:@"^[a-z0-9-]+$" options:NSRegularExpressionSearch].location==NSNotFound || out[key])return nil;
        out[key]=[[line substringFromIndex:colon.location+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    if(bodyOffset)*bodyOffset=split.location+4;return out;
}
NSDictionary *CophoneParseMenuHTTP(NSData *raw,NSString *token) {
    if(raw.length>20*1024)return nil;NSUInteger offset=0;NSDictionary *h=headers(raw,&offset);if(!h)return nil;
    NSArray *first=[h[@":first"] componentsSeparatedByString:@" "];if(first.count!=3 || ![first[2] isEqual:@"HTTP/1.1"])return nil;
    if(![h[@"host"] isEqual:@"127.0.0.1:18769"] || h[@"origin"] || h[@"transfer-encoding"] || h[@"expect"])return nil;
    NSString *auth=h[@"authorization"];if(![auth hasPrefix:@"Bearer "] || !equalToken([auth substringFromIndex:7],token))return nil;
    BOOL get=[first[0] isEqual:@"GET"] && [first[1] isEqual:@"/v1/status"],post=[first[0] isEqual:@"POST"] && [first[1] isEqual:@"/v1/enqueue"];
    if(!get && !post)return nil;
    NSString *length=h[@"content-length"] ?: @"0";
    if([length rangeOfString:@"^[0-9]{1,5}$" options:NSRegularExpressionSearch].location==NSNotFound)return nil;
    NSUInteger count=length.integerValue;if(count>16*1024 || raw.length!=offset+count || (get && count))return nil;
    NSDictionary *body=@{};
    if(post) {
        if(![h[@"content-type"] isEqual:@"application/json"] || !count)return nil;
        id json=[NSJSONSerialization JSONObjectWithData:[raw subdataWithRange:NSMakeRange(offset,count)] options:0 error:NULL];
        if(![json isKindOfClass:NSDictionary.class])return nil;body=json;
        if(![@[@"illustrate",@"summarize"] containsObject:body[@"action"]] || ![body[@"snippet"] isKindOfClass:NSString.class] || ![body[@"consent"] isEqual:@YES] || [body[@"snippet"] length]<1 || [body[@"snippet"] length]>2000 || body.count!=3)return nil;
    }return @{@"path":first[1],@"body":body};
}
static NSData *receiveHTTP(int fd) {
    NSMutableData *raw=[NSMutableData data];unsigned char chunk[2048];
    while(raw.length<=20*1024) {
        ssize_t size=recv(fd,chunk,sizeof(chunk),0);if(size<=0)break;[raw appendBytes:chunk length:size];
        NSUInteger offset=0;NSDictionary *h=headers(raw,&offset);
        if(h){NSUInteger length=[h[@"content-length"] integerValue];if(length>16*1024)return nil;if(raw.length>=offset+length)return raw;}
        else if(raw.length>4096)return nil;
    }return nil;
}
static BOOL sendAll(int fd,NSData *data) {
    const unsigned char *p=data.bytes;NSUInteger sent=0;
    while(sent<data.length){ssize_t size=send(fd,p+sent,data.length-sent,0);if(size<=0)return NO;sent+=size;}return YES;
}
static void socketOptions(int fd) {
    int one=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));struct timeval timeout={3,0};
    setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
}
NSDictionary *CophoneMenuRequest(NSString *path,NSDictionary *body) {
    int hi=-1,lo=-1;uint64_t high=0,low=0;
    if(notify_register_check(HighName,&hi)!=NOTIFY_STATUS_OK)return nil;
    if(notify_register_check(LowName,&lo)!=NOTIFY_STATUS_OK){notify_cancel(hi);return nil;}
    notify_get_state(hi,&high);notify_get_state(lo,&low);notify_cancel(hi);notify_cancel(lo);if(!high && !low)return nil;
    int fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0)return nil;socketOptions(fd);
    struct sockaddr_in address={0};address.sin_family=AF_INET;address.sin_port=htons(MenuPort);inet_pton(AF_INET,"127.0.0.1",&address.sin_addr);
    if(connect(fd,(struct sockaddr *)&address,sizeof(address))!=0){close(fd);return nil;}
    NSData *payload=body?[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL]:[NSData data];
    NSString *head=[NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\nHost: 127.0.0.1:18769\r\nAuthorization: Bearer %@\r\nContent-Type: application/json\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",body?@"POST":@"GET",path,tokenString(high,low),(unsigned long)payload.length];
    NSMutableData *request=[[head dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];[request appendData:payload];
    NSData *response=sendAll(fd,request)?receiveHTTP(fd):nil;close(fd);if(!response)return nil;
    NSUInteger offset=0;NSDictionary *h=headers(response,&offset);if(![h[@":first"] isEqual:@"HTTP/1.1 200 OK"])return nil;
    id result=[NSJSONSerialization JSONObjectWithData:[response subdataWithRange:NSMakeRange(offset,response.length-offset)] options:0 error:NULL];
    return [result isKindOfClass:NSDictionary.class]?result:nil;
}
@implementation CophoneMenuServer
- (BOOL)start {
    self.socketFD=socket(AF_INET,SOCK_STREAM,0);if(self.socketFD<0)return NO;int one=1;setsockopt(self.socketFD,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
    struct sockaddr_in address={0};address.sin_family=AF_INET;address.sin_port=htons(MenuPort);inet_pton(AF_INET,"127.0.0.1",&address.sin_addr);
    if(bind(self.socketFD,(struct sockaddr *)&address,sizeof(address))!=0 || listen(self.socketFD,4)!=0){close(self.socketFD);self.socketFD=-1;return NO;}
    uint64_t bits[2];arc4random_buf(bits,sizeof(bits));self.token=tokenString(bits[0],bits[1]);
    notify_register_check(HighName,&_tokenHigh);notify_register_check(LowName,&_tokenLow);notify_set_state(self.tokenHigh,bits[0]);notify_set_state(self.tokenLow,bits[1]);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{while(YES){@autoreleasepool {
        int client=accept(self.socketFD,NULL,NULL);if(client<0)break;socketOptions(client);
        NSData *raw=receiveHTTP(client);NSDictionary *parsed=raw?CophoneParseMenuHTTP(raw,self.token):nil;
        __block NSDictionary *result=nil;
        if(parsed)dispatch_sync(dispatch_get_main_queue(),^{result=self.handler?self.handler(parsed[@"path"],parsed[@"body"]):nil;});
        NSData *json=[NSJSONSerialization dataWithJSONObject:result ?: @{@"accepted":@NO} options:0 error:NULL];
        NSString *head=[NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: application/json\r\nContent-Length: %lu\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n",parsed?@"200 OK":@"403 Forbidden",(unsigned long)json.length];
        NSMutableData *reply=[[head dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];[reply appendData:json];sendAll(client,reply);close(client);
    }}});return YES;
}
@end
