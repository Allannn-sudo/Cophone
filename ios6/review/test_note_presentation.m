#import "NotePresentation.h"
#import "ReviewSession.h"
static NSUInteger checks;
static void check(BOOL ok,const char *name){checks++;if(!ok){fprintf(stderr,"FAILED %s\n",name);exit(1);}}
int main(){@autoreleasepool {
 check([CophoneNoteTitle(@"扩散模型的基本原理\n\n原文要点\n•逐步去噪",@"fallback") isEqual:@"扩散模型的基本原理"],"summary uses actual model heading");
 check([CophoneNoteTitle(@"## 标题：AI Agent入门视频怎么选\n比较理由",@"fallback") isEqual:@"AI Agent入门视频怎么选"],"remove heading markup and title label");
 check([CophoneNoteTitle(@"cophone 摘录摘要\n\n原文要点\n扩散模型的基本原理",@"fallback") isEqual:@"扩散模型的基本原理"],"skip generic legacy headings");
 check([CophoneNoteTitle(@"cophone如何在后台完成任务\n正文",@"fallback") isEqual:@"cophone如何在后台完成任务"],"brand may appear as an actual subject");
 check([CophoneNoteTitle(@12,@"本次摘录的核心要点") isEqual:@"本次摘录的核心要点"],"invalid model title has bounded fallback");
 NSString *longTitle=CophoneNoteTitle([@"知识" stringByPaddingToLength:120 withString:@"知识" startingAtIndex:0],@"fallback");
 check(longTitle.length==28 && [longTitle hasSuffix:@"…"],"long topic fits legacy small screen");
 NSString *emoji=CophoneNoteCompact(@"🌊🌊🌊🌊",4);check([emoji dataUsingEncoding:NSUTF8StringEncoding]!=nil,"truncation preserves unicode sequences");
 check([CophoneNoteWithoutHeading(@"主题标题\n\n原文要点\n•正文",@"主题标题") isEqual:@"原文要点\n•正文"],"avoid duplicate summary heading");
 check([CophoneNoteWithoutHeading(@"只有一句话",@"只有一句话") isEqual:@"只有一句话"],"never discard a one-line result");
 check([CophoneNotePreview(@"主题\n\n要点甲\n要点乙") isEqual:@"要点甲 要点乙"],"list preview comes from own body");
 ReviewSession *s=[[ReviewSession alloc] initWithID:@"test" at:1 history:@{}];
 [s.pages addObject:@{@"title":@"神经网络基础"}];[s.videos addObject:@{@"title":@"AI Agent入门"}];
 check([[s noteTitle] rangeOfString:@"神经网络基础"].location!=NSNotFound && [[s noteTitle] rangeOfString:@"AI Agent入门"].location!=NSNotFound,"recap title uses real page and video topics");
 check([[s noteText] hasPrefix:[[s noteTitle] stringByAppendingString:@"\n目视官 · "]],"Notes first body line agrees with title");
 ReviewSession *apps=[[ReviewSession alloc] initWithID:@"apps" at:1 history:@{}];[apps.visits addObject:@{@"name":@"Safari"}];[apps.visits addObject:@{@"name":@"oldbili"}];
 check([[apps noteTitle] isEqual:@"Safari、oldbili使用回顾"],"no observed content uses app names without inventing a topic");
 printf("%lu note presentation checks passed\n",(unsigned long)checks);
}return 0;}
