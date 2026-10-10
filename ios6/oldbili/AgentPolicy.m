#import "AgentPolicy.h"
static BOOL string(id v,NSUInteger n){return [v isKindOfClass:NSString.class] && [v length]>0 && [v length]<=n;}
static NSDictionary *reject(NSError **error,NSString *reason){if(error)*error=[NSError errorWithDomain:@"cophone.Oldbili" code:1 userInfo:@{NSLocalizedDescriptionKey:reason}];return nil;}
NSArray *CophoneOldbiliAllowedActions(NSDictionary *observation,NSArray *inspected){
 NSMutableArray *actions=[NSMutableArray arrayWithObjects:@"search",@"stop",nil];
 NSMutableSet *available=[NSMutableSet set];for(NSDictionary *row in observation[@"results"])if(string(row[@"videoID"],32))[available addObject:row[@"videoID"]];
 if([observation[@"status"] isEqual:@"results"] && available.count>=2)[actions addObject:@"read"];
 [available intersectSet:[NSSet setWithArray:inspected ?: @[]]];
 if([observation[@"status"] isEqual:@"inspected"] && available.count>=2)[actions addObject:@"finish"];
 return actions;
}
NSDictionary *CophoneOldbiliDecision(id v,NSDictionary *observation,NSArray *inspected,NSError **error){
 if(![v isKindOfClass:NSDictionary.class])return reject(error,@"决策必须是JSON对象。");
 if(!string(v[@"reason"],180))return reject(error,@"reason必须是1至180字的理由。");
 NSString *action=v[@"action"];
 if([action isEqual:@"search"]){if([v count]!=3 || !string(v[@"query"],80))return reject(error,@"search只允许action/query/reason，query须1至80字。");return v;}
 if([action isEqual:@"stop"]){if([v count]!=2)return reject(error,@"stop只允许action/reason。");return v;}
 if(![action isEqual:@"read"] && ![action isEqual:@"finish"])return reject(error,@"action只允许search/read/finish/stop。");
 id ids=v[@"ids"];if(![ids isKindOfClass:NSArray.class] || [ids count]<2 || [ids count]>3)return reject(error,@"ids必须是两个或三个真实videoID。");
 NSMutableSet *available=[NSMutableSet set];for(NSDictionary *row in observation[@"results"])if(string(row[@"videoID"],32))[available addObject:row[@"videoID"]];
 NSMutableSet *unique=[NSMutableSet set];for(id ident in ids){if(!string(ident,32) || ![available containsObject:ident])return reject(error,@"ids包含当前App结果中不存在的视频，必须使用observation.results里的videoID。");if([unique containsObject:ident])return reject(error,@"ids不能重复。");[unique addObject:ident];}
 if([action isEqual:@"read"]){
  if([v count]!=3)return reject(error,@"read只能包含action、ids、reason三个字段，请删除其他字段。");
  if(![observation[@"status"] isEqual:@"results"])return reject(error,[observation[@"status"] isEqual:@"inspected"]?@"当前已是inspected：候选简介已读取，不能再次read。资料足够时请用finish比较并推荐；不够则search换词，或stop说明原因。":@"当前尚未得到可读取的搜索结果，请先search；read仅允许在results状态执行。");
  return v;
 }
 if([v count]!=5)return reject(error,@"finish只允许action/ids/recommended/comparison/reason五个字段。");
 if(![observation[@"status"] isEqual:@"inspected"] || ![[NSSet setWithArray:ids] isSubsetOfSet:[NSSet setWithArray:inspected]])return reject(error,@"finish前必须在App里read所选候选，当前状态须inspected。");
 if(![ids containsObject:v[@"recommended"]])return reject(error,@"recommended必须是本次ids中的一个videoID。");
 if(!string(v[@"comparison"],650))return reject(error,@"comparison须1至650字，请简短分段比较，不要重复整段视频简介。");
 return v;
}
