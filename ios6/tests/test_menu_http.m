#import "MenuIPC.h"
static NSData *request(NSString *verb,NSString *path,NSString *token,NSString *extra,NSData *body) {
    NSString *head=[NSString stringWithFormat:@"%@ %@ HTTP/1.1\r\nHost: 127.0.0.1:18769\r\nAuthorization: Bearer %@\r\nContent-Type: application/json\r\nContent-Length: %lu\r\n%@\r\n",verb,path,token,(unsigned long)body.length,extra ?: @""];
    NSMutableData *raw=[[head dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];if(body)[raw appendData:body];return raw;
}
int main(void){@autoreleasepool {
    NSString *token=@"0123456789abcdef0123456789abcdef";
    NSCAssert(CophoneParseMenuHTTP(request(@"GET",@"/v1/status",token,nil,nil),token),@"Authenticated metadata GET");
    NSData *body=[NSJSONSerialization dataWithJSONObject:@{@"action":@"summarize",@"snippet":@"selected text",@"consent":@YES} options:0 error:NULL];
    NSCAssert(CophoneParseMenuHTTP(request(@"POST",@"/v1/enqueue",token,nil,body),token),@"Explicit bounded selection accepted");
    NSCAssert(!CophoneParseMenuHTTP(request(@"POST",@"/v1/enqueue",@"bad",nil,body),token),@"Wrong capability denied");
    NSCAssert(!CophoneParseMenuHTTP(request(@"POST",@"/v1/enqueue",token,@"Origin: https://example.com\r\n",body),token),@"Web page origin cannot enqueue");
    NSCAssert(!CophoneParseMenuHTTP(request(@"POST",@"/v1/enqueue",token,@"Transfer-Encoding: chunked\r\n",body),token),@"Ambiguous framing denied");
    NSCAssert(!CophoneParseMenuHTTP(request(@"POST",@"/v1/enqueue",token,@"Content-Length: 0\r\n",body),token),@"Duplicate length denied");
    NSCAssert(!CophoneParseMenuHTTP(request(@"GET",@"/v1/enqueue",token,nil,nil),token),@"GET cannot trigger a task");
    NSCAssert(!CophoneParseMenuHTTP(request(@"OPTIONS",@"/v1/enqueue",token,nil,nil),token),@"No browser CORS permission");
    NSMutableData *extra=[request(@"POST",@"/v1/enqueue",token,nil,body) mutableCopy];[extra appendData:[@"extra" dataUsingEncoding:NSASCIIStringEncoding]];
    NSCAssert(!CophoneParseMenuHTTP(extra,token),@"Trailing pipelined data denied");
    for(NSDictionary *bad in @[@{@"action":@"shell",@"snippet":@"x",@"consent":@YES},@{@"action":@"summarize",@"snippet":@"x",@"consent":@NO},@{@"action":@"summarize",@"snippet":@"x",@"consent":@YES,@"key":@"unexpected"}]) {
        NSData *data=[NSJSONSerialization dataWithJSONObject:bad options:0 error:NULL];NSCAssert(!CophoneParseMenuHTTP(request(@"POST",@"/v1/enqueue",token,nil,data),token),@"Only two explicit tools and no extra fields");
    }
    NSLog(@"Menu HTTP parser tests passed: capability, origin, method, framing, bounds and explicit consent");
}return 0;}
