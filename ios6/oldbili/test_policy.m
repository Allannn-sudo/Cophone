#import <Foundation/Foundation.h>
#import "AgentPolicy.h"
static NSUInteger checked;
static void check(BOOL value,NSString *name){checked++;if(!value){fprintf(stderr,"FAILED %s\n",name.UTF8String);exit(1);}}
int main(){@autoreleasepool {
 NSDictionary *results=@{@"status":@"results",@"results":@[@{@"videoID":@"BV1111111111"},@{@"videoID":@"BV2222222222"}]};
 NSArray *ids=@[@"BV1111111111",@"BV2222222222"];
 check(CophoneOldbiliDecision(@{@"action":@"search",@"query":@"AI Agent 零基础",@"reason":@"按目标选择关键词"},@{},@[],NULL)!=nil,@"natural search accepted");
 check(!CophoneOldbiliDecision(@{@"action":@"shell",@"query":@"anything",@"reason":@"escape"},results,@[],NULL),@"arbitrary operation rejected");
 check(!CophoneOldbiliDecision(@{@"action":@"search",@"query":@"test",@"reason":@"test",@"url":@"https://example.com"},results,@[],NULL),@"unknown field rejected");
 check(CophoneOldbiliDecision(@{@"action":@"read",@"ids":ids,@"reason":@"比较实际候选"},results,@[],NULL)!=nil,@"real candidates readable");
 check(!CophoneOldbiliDecision(@{@"action":@"read",@"ids":@[@"BV1111111111",@"BV9999999999"],@"reason":@"test"},results,@[],NULL),@"invented ID rejected");
 check(!CophoneOldbiliDecision(@{@"action":@"read",@"ids":@[@"BV1111111111",@"BV1111111111"],@"reason":@"test"},results,@[],NULL),@"duplicate candidate rejected");
 NSDictionary *finish=@{@"action":@"finish",@"ids":ids,@"recommended":ids[0],@"comparison":@"依据标题和简介进行比较。",@"reason":@"已读取候选"};
 check(!CophoneOldbiliDecision(finish,results,ids,NULL),@"finish before App read rejected");
 NSDictionary *read=@{@"status":@"inspected",@"results":results[@"results"]};
 check(!CophoneOldbiliDecision(finish,read,@[ids[0]],NULL),@"unread comparison rejected");
 check(CophoneOldbiliDecision(finish,read,ids,NULL)!=nil,@"verified candidates can finish");
 NSMutableDictionary *wrong=[finish mutableCopy];wrong[@"recommended"]=@"BV3333333333";
 check(!CophoneOldbiliDecision(wrong,read,ids,NULL),@"recommendation outside selection rejected");
 check(!CophoneOldbiliDecision(@[@"bad"],results,ids,NULL),@"wrong JSON type rejected");
 check(CophoneOldbiliDecision(@{@"action":@"stop",@"reason":@"出现未支持弹窗"},results,ids,NULL)!=nil,@"uncertain state can stop");
 NSMutableDictionary *longComparison=[finish mutableCopy];longComparison[@"comparison"]=[@"x" stringByPaddingToLength:651 withString:@"x" startingAtIndex:0];NSError *specific=nil;
 check(!CophoneOldbiliDecision(longComparison,read,ids,&specific) && [specific.localizedDescription rangeOfString:@"650"].location!=NSNotFound,@"oversized comparison gives repair guidance");
 NSMutableDictionary *extra=[finish mutableCopy];extra[@"title"]=@"extra";
 check(!CophoneOldbiliDecision(extra,read,ids,NULL),@"finish extra field remains rejected");
 check([CophoneOldbiliAllowedActions(@{@"status":@"ready"},@[]) isEqual:@[@"search",@"stop"]],@"initial state offers no stale read or finish");
 check([CophoneOldbiliAllowedActions(results,@[]) containsObject:@"read"],@"results explicitly offer read");
 check(![CophoneOldbiliAllowedActions(results,ids) containsObject:@"finish"],@"previous inspected IDs cannot bypass fresh read");
 NSError *duplicateRead=nil;
 check(!CophoneOldbiliDecision(@{@"action":@"read",@"ids":ids,@"reason":@"重复读取"},read,ids,&duplicateRead) && [duplicateRead.localizedDescription rangeOfString:@"不能再次read"].location!=NSNotFound && [duplicateRead.localizedDescription rangeOfString:@"finish"].location!=NSNotFound,@"desktop failure gives specific next-action guidance without replay");
 NSError *extraRead=nil;check(!CophoneOldbiliDecision(@{@"action":@"read",@"ids":ids,@"reason":@"test",@"query":@"extra"},results,@[],&extraRead) && [extraRead.localizedDescription rangeOfString:@"删除其他字段"].location!=NSNotFound,@"field error is separate from state error");
 NSDictionary *three=@{@"status":@"inspected",@"results":@[@{@"videoID":ids[0]},@{@"videoID":ids[1]},@{@"videoID":@"BV3333333333"}]};
 NSArray *allThree=[ids arrayByAddingObject:@"BV3333333333"];
 check([CophoneOldbiliAllowedActions(three,allThree) containsObject:@"finish"] && ![CophoneOldbiliAllowedActions(three,allThree) containsObject:@"read"],@"three inspected candidates offer comparison rather than duplicate read");
 check(CophoneOldbiliDecision(finish,three,allThree,NULL)!=nil,@"can compare two after reading three as in failed desktop trajectory");
 check(![CophoneOldbiliAllowedActions(three,@[ids[0]]) containsObject:@"finish"],@"insufficient verified intersection cannot finish");
 check(![CophoneOldbiliAllowedActions(@{@"status":@"results",@"results":@[@{@"videoID":ids[0]},@{@"videoID":ids[0]}]},@[]) containsObject:@"read"],@"duplicate search rows do not imply two available candidates");
 printf("%lu policy checks passed\n",(unsigned long)checked);
}return 0;}
