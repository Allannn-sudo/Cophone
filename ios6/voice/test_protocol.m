#import <Foundation/Foundation.h>
#import "VoiceProtocol.h"
static unsigned checked;
static void check(BOOL value,NSString *name){checked++;if(!value){fprintf(stderr,"FAILED %s\n",name.UTF8String);exit(1);}}
static void le(NSMutableData *d,NSUInteger at,uint32_t v,unsigned n){unsigned char *p=d.mutableBytes;for(unsigned i=0;i<n;i++)p[at+i]=(v>>(i*8))&255;}
static NSMutableData *wave(void){NSMutableData *d=[NSMutableData dataWithLength:44+32000];unsigned char *p=d.mutableBytes;const char *tags="RIFFWAVEfmt data";for(int i=0;i<4;i++){p[i]=tags[i];p[8+i]=tags[4+i];p[12+i]=tags[8+i];p[36+i]=tags[12+i];}le(d,4,(uint32_t)d.length-8,4);le(d,16,16,4);le(d,20,1,2);le(d,22,1,2);le(d,24,16000,4);le(d,28,32000,4);le(d,32,2,2);le(d,34,16,2);le(d,40,32000,4);return d;}
int main(){@autoreleasepool {
 NSArray *raw=@[@"",@"f",@"fo",@"foo",@"foob",@"fooba",@"foobar"],*encoded=@[@"",@"Zg==",@"Zm8=",@"Zm9v",@"Zm9vYg==",@"Zm9vYmE=",@"Zm9vYmFy"];
 for(NSUInteger i=0;i<raw.count;i++)check([CophoneVoiceBase64([raw[i] dataUsingEncoding:NSUTF8StringEncoding]) isEqual:encoded[i]],@"RFC4648 vector");
 NSMutableData *valid=wave();check(CophoneVoicePCM(valid),@"mono PCM accepted");
 check(!CophoneVoicePCM([valid subdataWithRange:NSMakeRange(0,valid.length-1)]),@"truncated rejected");
 NSMutableData *bad=[valid mutableCopy];le(bad,24,44100,4);check(!CophoneVoicePCM(bad),@"wrong rate rejected");
 bad=[valid mutableCopy];le(bad,22,2,2);check(!CophoneVoicePCM(bad),@"stereo rejected");
 bad=[valid mutableCopy];le(bad,40,UINT32_MAX,4);check(!CophoneVoicePCM(bad),@"chunk overflow rejected");
 bad=[valid mutableCopy];[bad setLength:44+100];le(bad,4,(uint32_t)bad.length-8,4);le(bad,40,100,4);check(!CophoneVoicePCM(bad),@"too short rejected");
 check(!CophoneVoiceBase64([NSMutableData dataWithLength:512*1024+1]),@"oversized input rejected");
 check(CophoneVoiceVague(@"帮我找视频。"),@"missing topic requires clarification");
 check(!CophoneVoiceVague(@"找两个零基础 AI Agent 视频"),@"specific topic accepted");
 check(CophoneVoiceRoute(@{@"intent":@"oldbili",@"goal":@"找 AI Agent 入门视频",@"question":@""})!=nil,@"supported goal accepted");
 check(!CophoneVoiceRoute(@{@"intent":@"oldbili",@"goal":@"帮我找视频",@"question":@""}),@"vague execution rejected");
 check(!CophoneVoiceRoute(@{@"intent":@"shell",@"goal":@"x",@"question":@""}),@"unknown intent rejected");
 check(!CophoneVoiceRoute(@{@"intent":@"clarify",@"goal":@"",@"question":@""}),@"empty question rejected");
 check(!CophoneVoiceRoute(@[@"bad"]),@"wrong JSON type rejected");
 printf("%u voice protocol checks passed\n",checked);
}return 0;}
