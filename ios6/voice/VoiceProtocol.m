#import "VoiceProtocol.h"
static uint32_t u32(const unsigned char *p){return p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint16_t u16(const unsigned char *p){return p[0]|((uint16_t)p[1]<<8);}
static BOOL tag(const unsigned char *p,const char *s){return p[0]==s[0] && p[1]==s[1] && p[2]==s[2] && p[3]==s[3];}
BOOL CophoneVoicePCM(NSData *d){
 if(d.length<44 || d.length>512*1024)return NO;const unsigned char *p=d.bytes;if(!tag(p,"RIFF") || !tag(p+8,"WAVE") || u32(p+4)!=d.length-8)return NO;
 BOOL fmt=NO,audio=NO;NSUInteger at=12;
 while(at+8<=d.length){uint32_t size=u32(p+at+4);if(size>d.length-at-8)return NO;
 if(tag(p+at,"fmt ")){if(fmt || size<16)return NO;const unsigned char *f=p+at+8;fmt=u16(f)==1 && u16(f+2)==1 && u32(f+4)==16000 && u32(f+8)==32000 && u16(f+12)==2 && u16(f+14)==16;if(!fmt)return NO;}
 if(tag(p+at,"data")){if(audio || size<9600 || size>480000 || size%2)return NO;audio=YES;}
 at+=8+size+(size%2);
 }return fmt && audio && at==d.length;
}
NSString *CophoneVoiceBase64(NSData *d){
 if(d.length>512*1024)return nil;static const char alphabet[]="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
 NSMutableData *encoded=[NSMutableData dataWithLength:((d.length+2)/3)*4];char *out=encoded.mutableBytes;const unsigned char *p=d.bytes;NSUInteger at=0;
 for(NSUInteger i=0;i<d.length;i+=3){NSUInteger left=d.length-i;uint32_t n=((uint32_t)p[i]<<16)|(left>1?(uint32_t)p[i+1]<<8:0)|(left>2?p[i+2]:0);out[at++]=alphabet[(n>>18)&63];out[at++]=alphabet[(n>>12)&63];out[at++]=left>1?alphabet[(n>>6)&63]:'=';out[at++]=left>2?alphabet[n&63]:'=';}
 return [[NSString alloc] initWithData:encoded encoding:NSASCIIStringEncoding];
}
BOOL CophoneVoiceVague(NSString *text){
 if(![text isKindOfClass:NSString.class] || !text.length)return YES;NSString *s=text;
 for(NSString *word in @[@"cophone",@"帮我",@"给我",@"请",@"一下",@"一些",@"几个",@"两个",@"找",@"搜索",@"视频",@"推荐",@"看看",@"我想",@"我要",@"整理",@"备忘录",@"比较",@"然后",@"并",@"到",@"写入",@"写",@"。",@"，",@"！",@"？",@" ",@"、"])s=[s stringByReplacingOccurrencesOfString:word withString:@""];
 return s.length<2;
}
NSDictionary *CophoneVoiceRoute(id v){
 if(![v isKindOfClass:NSDictionary.class] || [v count]!=3)return nil;
 for(NSString *k in @[@"intent",@"goal",@"question"])if(![v[k] isKindOfClass:NSString.class] || [v[k] length]>500)return nil;
 if(![@[@"oldbili",@"clarify",@"unsupported"] containsObject:v[@"intent"]])return nil;
 if([v[@"intent"] isEqual:@"oldbili"] && CophoneVoiceVague(v[@"goal"]))return nil;
 if(![v[@"intent"] isEqual:@"oldbili"] && ![v[@"question"] length])return nil;
 return v;
}
