#import <Foundation/Foundation.h>
static inline NSString *CophoneNoteCompact(id value,NSUInteger limit){
 if(![value isKindOfClass:NSString.class])return @"";
 NSString *s=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 s=[[s componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@" "];
 while([s rangeOfString:@"  "].location!=NSNotFound)s=[s stringByReplacingOccurrencesOfString:@"  " withString:@" "];
 if(s.length>limit)s=[[s substringWithRange:[s rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,limit-1)]] stringByAppendingString:@"…"];
 return s;
}
static inline NSString *CophoneNoteTitle(id text,NSString *fallback){
 if([text isKindOfClass:NSString.class])for(NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]){
  NSString *s=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  s=[s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#*\"“”「」"]];
  s=[s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  for(NSString *prefix in @[@"标题：",@"标题:"])if([s hasPrefix:prefix])s=[s substringFromIndex:prefix.length];
  s=CophoneNoteCompact(s,28);
  if(!s.length || [@[@"摘要",@"摘录摘要",@"视频推荐",@"使用回顾",@"目视官",@"原文要点",@"原文要点：",@"比较与理由"] containsObject:s] || [@[@"cophone 摘录摘要",@"cophone 视频推荐",@"cophone 使用回顾"] containsObject:s.lowercaseString])continue;
  return s;
 }
 return CophoneNoteCompact(fallback.length?fallback:@"未命名内容",28);
}
static inline NSString *CophoneNotePreview(NSString *body){
 NSArray *lines=[body componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
 if(lines.count<2)return @"";
 return CophoneNoteCompact([[lines subarrayWithRange:NSMakeRange(1,lines.count-1)] componentsJoinedByString:@" "],80);
}
static inline NSString *CophoneNoteWithoutHeading(NSString *body,NSString *title){
 NSArray *lines=[body componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
 for(NSUInteger i=0;i<lines.count;i++){
  NSString *line=[lines[i] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!line.length)continue;
  if(line.length<=80 && i+1<lines.count && [CophoneNoteTitle(line,@"") isEqual:title]){
   NSString *rest=[[lines subarrayWithRange:NSMakeRange(i+1,lines.count-i-1)] componentsJoinedByString:@"\n"];
   rest=[rest stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(rest.length)return rest;
  }
  break;
 }
 return body;
}
