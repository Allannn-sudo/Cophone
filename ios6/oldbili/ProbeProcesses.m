#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <sys/proc.h>
int main(){@autoreleasepool {
 int name[]={CTL_KERN,KERN_PROC,KERN_PROC_ALL,0};size_t length=0;if(sysctl(name,4,NULL,&length,NULL,0))return 2;
 NSMutableData *d=[NSMutableData dataWithLength:length*2];length=d.length;if(sysctl(name,4,d.mutableBytes,&length,NULL,0))return 3;
 struct kinfo_proc *p=d.mutableBytes;NSMutableArray *rows=[NSMutableArray array];
 for(size_t i=0;i<length/sizeof(*p);i++){NSString *n=[NSString stringWithUTF8String:p[i].kp_proc.p_comm];if([n.lowercaseString rangeOfString:@"bili"].location!=NSNotFound)[rows addObject:@{@"pid":@(p[i].kp_proc.p_pid),@"name":n,@"state":@(p[i].kp_proc.p_stat),@"flags":@(p[i].kp_proc.p_flag)}];}
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:rows options:NSJSONWritingPrettyPrinted error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
