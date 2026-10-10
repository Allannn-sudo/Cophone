#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
static uint32_t be32(const unsigned char *p){return ((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
static BOOL relevant(NSString *s){NSString *lower=s.lowercaseString;for(NSString *part in @[@"search",@"video",@"detail",@"fav",@"collect",@"login",@"network",@"request",@"result",@"loading",@"bili",@"account"])if([lower rangeOfString:part].location!=NSNotFound)return YES;return NO;}
int main(int argc,char **argv){@autoreleasepool {
 NSFileManager *fm=NSFileManager.defaultManager;NSString *base=@"/var/mobile/Applications";
 for(NSString *dir in [fm contentsOfDirectoryAtPath:base error:NULL]) {
  NSString *folder=[base stringByAppendingPathComponent:dir];
  for(NSString *app in [fm contentsOfDirectoryAtPath:folder error:NULL]) {
   if(![app hasSuffix:@".app"])continue;NSString *path=[folder stringByAppendingPathComponent:app];NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
   if(![@[@"net.iosipa.oldbili",@"com.aramco.cycomm"] containsObject:info[@"CFBundleIdentifier"]])continue;
   if(argc>1 && [[NSString stringWithUTF8String:argv[1]] isEqualToString:@"--adapter"] && [info[@"CFBundleIdentifier"] isEqual:@"net.iosipa.oldbili"]) {
    NSString *bridge=[folder stringByAppendingPathComponent:@"Library/Caches/cophone-agent"],*state=[bridge stringByAppendingPathComponent:@"state.json"];
    NSData *d=[NSData dataWithContentsOfFile:state];if(d.length>128*1024)continue;NSDictionary *v=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;
    if(v)puts([[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding].UTF8String);
    continue;
   }
   if(argc>1 && [[NSString stringWithUTF8String:argv[1]] isEqualToString:@"--runtime"]) {
    NSString *probePath=[folder stringByAppendingPathComponent:@"tmp/cophone-oldbili-probe.json"];
    NSData *probe=[NSData dataWithContentsOfFile:probePath];
    if(probe.length && probe.length<=256*1024) {NSDictionary *value=[NSJSONSerialization JSONObjectWithData:probe options:0 error:NULL];if([value isKindOfClass:NSDictionary.class] && [value[@"bundle"] isEqual:info[@"CFBundleIdentifier"]]) {NSString *json=[[NSString alloc] initWithData:probe encoding:NSUTF8StringEncoding];puts(json.UTF8String);}}
    continue;
   }
   printf("APP bundle=%s version=%s\n",[info[@"CFBundleIdentifier"] UTF8String],[(info[@"CFBundleShortVersionString"] ?: @"unknown") UTF8String]);
   NSData *data=[NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:info[@"CFBundleExecutable"]]];
   if(data.length<sizeof(struct mach_header))continue;const unsigned char *bytes=data.bytes;if(be32(bytes)==0xcafebabe) {
    uint32_t count=be32(bytes+4),chosen=0,length=0;
    for(uint32_t a=0;a<count && a<16;a++){NSUInteger off=8+a*20;if(off+20>data.length)break;if(be32(bytes+off)!=12)continue;uint32_t start=be32(bytes+off+8),size=be32(bytes+off+12);if(start>data.length || size>data.length-start)continue;chosen=start;length=size;if((be32(bytes+off+4)&255)==9)break;}
    if(!length){puts("NO_ARM_SLICE");continue;}data=[data subdataWithRange:NSMakeRange(chosen,length)];bytes=data.bytes;
   }
   struct mach_header h;[data getBytes:&h range:NSMakeRange(0,sizeof(h))];if(h.magic!=MH_MAGIC){puts("UNSUPPORTED_BINARY_FORMAT");continue;}
   NSUInteger offset=sizeof(h),printed=0,classCount=0;
   for(unsigned int i=0;i<h.ncmds && offset+sizeof(struct load_command)<=data.length;i++) {
    struct load_command lc;[data getBytes:&lc range:NSMakeRange(offset,sizeof(lc))];if(lc.cmdsize<sizeof(lc) || offset+lc.cmdsize>data.length)break;
    if(lc.cmd==LC_ENCRYPTION_INFO && lc.cmdsize>=sizeof(struct encryption_info_command)){struct encryption_info_command e;[data getBytes:&e range:NSMakeRange(offset,sizeof(e))];printf("ENCRYPTED %u\n",e.cryptid);}
    if(lc.cmd==LC_SEGMENT && lc.cmdsize>=sizeof(struct segment_command)) {
     struct segment_command seg;[data getBytes:&seg range:NSMakeRange(offset,sizeof(seg))];
     for(unsigned int j=0;j<seg.nsects;j++) {
      NSUInteger at=offset+sizeof(seg)+j*sizeof(struct section);if(at+sizeof(struct section)>offset+lc.cmdsize)break;
      struct section sec;[data getBytes:&sec range:NSMakeRange(at,sizeof(sec))];
      NSString *sectionName=[[NSString alloc] initWithBytes:sec.sectname length:16 encoding:NSASCIIStringEncoding];BOOL cls=[sectionName hasPrefix:@"__objc_classname"],method=[sectionName hasPrefix:@"__objc_methname"];
      if((argc>1 && !cls) || (!cls && !method) || sec.offset>data.length || sec.size>data.length-sec.offset)continue;
      NSUInteger pos=sec.offset,end=pos+sec.size;
      while(pos<end && (cls?classCount<100:printed<240)){NSUInteger start=pos;while(pos<end && bytes[pos])pos++;NSUInteger len=pos-start;pos++;
       if(len<2 || len>160)continue;NSString *name=[[NSString alloc] initWithBytes:bytes+start length:len encoding:NSASCIIStringEncoding];if(name && [name rangeOfString:@"^[A-Za-z_][A-Za-z0-9_:]*$" options:NSRegularExpressionSearch].location!=NSNotFound && (cls || relevant(name))){printf("%s %s\n",cls?"CLASS":"METHOD",name.UTF8String);if(cls)classCount++;else printed++;}
      }
     }
    }offset+=lc.cmdsize;
   }
  }
 }
}return 0;}
