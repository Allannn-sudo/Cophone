#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
static uint32_t BE(const unsigned char *p){return ((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
@interface VoiceBinary:NSObject
@property(nonatomic,strong) NSData *data;
@property(nonatomic,strong) NSArray *segments;
- (NSUInteger)offset:(uint32_t)address;
- (uint32_t)word:(NSUInteger)offset;
- (NSString *)string:(uint32_t)address;
@end
@implementation VoiceBinary
- (NSUInteger)offset:(uint32_t)a{for(NSDictionary *s in self.segments){uint64_t vm=[s[@"vm"] unsignedLongLongValue],size=[s[@"size"] unsignedLongLongValue];if(a>=vm && a-vm<size){uint64_t at=[s[@"file"] unsignedLongLongValue]+a-vm;if(at<self.data.length)return (NSUInteger)at;}}return NSNotFound;}
- (uint32_t)word:(NSUInteger)at{uint32_t v=0;if(at!=NSNotFound && at<=self.data.length && self.data.length-at>=4)[self.data getBytes:&v range:NSMakeRange(at,4)];return v;}
- (NSString *)string:(uint32_t)a{NSUInteger at=[self offset:a];if(at==NSNotFound)return nil;const unsigned char *p=self.data.bytes;NSUInteger n=0;while(at+n<self.data.length && n<240 && p[at+n])n++;if(!n || n==240)return nil;return [[NSString alloc] initWithBytes:p+at length:n encoding:NSUTF8StringEncoding];}
@end
int main(){@autoreleasepool {
 VoiceBinary *b=[VoiceBinary new];b.data=[NSData dataWithContentsOfFile:@"/System/Library/CoreServices/SpringBoard.app/SpringBoard"];
 if(b.data.length<28)return 2;const unsigned char *bytes=b.data.bytes;
 if(BE(bytes)==0xcafebabe){uint32_t count=BE(bytes+4);BOOL found=NO;for(uint32_t i=0;i<count && i<16;i++){NSUInteger o=8+i*20;if(o+20>b.data.length)break;if(BE(bytes+o)!=12)continue;uint32_t at=BE(bytes+o+8),n=BE(bytes+o+12);if(at>b.data.length || n>b.data.length-at)continue;b.data=[b.data subdataWithRange:NSMakeRange(at,n)];found=YES;break;}if(!found)return 3;}
 if([b word:0]!=MH_MAGIC)return 4;
 NSMutableArray *segments=[NSMutableArray array],*classSections=[NSMutableArray array];NSUInteger off=28;uint32_t commands=[b word:16];
 for(uint32_t i=0;i<commands && off+8<=b.data.length;i++){uint32_t cmd=[b word:off],size=[b word:off+4];if(size<8 || size>b.data.length-off)break;
 if(cmd==LC_ENCRYPTION_INFO && [b word:off+16])return 5;
 if(cmd==LC_SEGMENT && size>=56){uint32_t vm=[b word:off+24],file=[b word:off+32],filesize=[b word:off+36],sects=[b word:off+48];[segments addObject:@{@"vm":@(vm),@"file":@(file),@"size":@(filesize)}];
 for(uint32_t j=0;j<sects && 56+(j+1)*68<=size;j++){NSUInteger at=off+56+j*68;char name[17]={0};[b.data getBytes:name range:NSMakeRange(at,16)];if([[NSString stringWithUTF8String:name] isEqual:@"__objc_classlist"])[classSections addObject:@{@"offset":@([b word:at+40]),@"size":@([b word:at+36])}];}}
 off+=size;}b.segments=segments;NSMutableArray *out=[NSMutableArray array];
 for(NSDictionary *section in classSections){NSUInteger at=[section[@"offset"] unsignedIntegerValue],end=at+[section[@"size"] unsignedIntegerValue];if(end>b.data.length)continue;
 for(;at+4<=end;at+=4){uint32_t cls=[b word:at];NSUInteger cp=[b offset:cls],ro=[b offset:[b word:cp+16]&~3u];NSString *name=[b string:[b word:ro+16]];if(!name)continue;BOOL whole=NO;BOOL base=[@[@"SpringBoard",@"SBApplication",@"SBApplicationController",@"SBApplicationProcess",@"SBWorkspace",@"SBAppToAppWorkspaceTransaction",@"SBApplicationProcessState",@"SBApplicationProcessStateSettings"] containsObject:name];if(!whole && !base)continue;
 NSMutableArray *methods=[NSMutableArray array];for(int kind=0;kind<2;kind++){NSUInteger obj=kind?[b offset:[b word:cp]]:cp;NSUInteger info=[b offset:[b word:obj+16]&~3u],list=[b offset:[b word:info+20]];if(list==NSNotFound)continue;uint32_t stride=[b word:list]&0xffff,count=[b word:list+4];if(stride<12 || stride>32)continue;
 for(uint32_t j=0;j<count && j<1000;j++){NSUInteger m=list+8+j*stride;NSString *sel=[b string:[b word:m]],*enc=[b string:[b word:m+4]];NSString *lower=sel.lowercaseString;BOOL wanted=whole;for(NSString *part in @[@"launch",@"susp",@"resum",@"background",@"assert",@"process",@"activate",@"deactiv"])if([lower rangeOfString:part].location!=NSNotFound)wanted=YES;if(wanted && sel && enc)[methods addObject:@{@"selector":sel,@"encoding":enc,@"classMethod":@(kind)}];}}
 if(methods.count)[out addObject:@{@"class":name,@"methods":methods}];
 }}NSData *d=[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL];puts([[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
