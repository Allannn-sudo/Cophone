// Own route status and optional explicit test notification only. No AI or user data reads.
#import <Foundation/Foundation.h>
#import <notify.h>
#import "../review/NotesWriter.h"
#import "../results/ResultLink.h"
#import "../results/ResultBadge.h"
int main(int argc,char **argv){@autoreleasepool {
 int token=0;uint64_t value=0;if(notify_register_check("ai.whaletech.cophone.notification-route",&token)==NOTIFY_STATUS_OK){notify_get_state(token,&value);notify_cancel(token);}
 NSMutableDictionary *out=[@{@"routeLoaded":@((value&1)!=0),@"routedBulletins":@(value>>1)} mutableCopy];
 uint64_t click=0;if(notify_register_check("ai.whaletech.cophone.notification-click",&token)==NOTIFY_STATUS_OK){notify_get_state(token,&click);notify_cancel(token);}
 out[@"clickHookReady"]=@((click&1)!=0);out[@"clickActionRewrites"]=@(click>>1);
 uint64_t exact=0;if(notify_register_check("ai.whaletech.cophone.notification-result-route",&token)==NOTIFY_STATUS_OK){notify_get_state(token,&exact);notify_cancel(token);}
 out[@"exactResultHookReady"]=@((exact&1)!=0);out[@"exactResultDispatches"]=@(exact>>1);
 NSString *mode=argc>1?[NSString stringWithUTF8String:argv[1]]:@"state";
 if([@[@"notes",@"photos"] containsObject:mode]){
  if(!(value&1) || !(click&1)){out[@"error"]=@"通知跳转插件尚未就绪，未发送测试。";}else{
   NSError *error=nil;BOOL photo=[mode isEqual:@"photos"];
   BOOL ok=SendTaskNotification(photo?@"跳转测试：点击直接打开照片；不会生成新图。":@"跳转测试：点击直接打开备忘录；不会新增笔记。",photo?@"open-photos":@"open-notes",&error);
   out[@"testSubmitted"]=@(ok);out[@"target"]=mode;if(error)out[@"error"]=error.localizedDescription;
  }
 }
 if([@[@"note-result",@"photo-result"] containsObject:mode]){
  BOOL photo=[mode isEqual:@"photo-result"];NSString *identifier=argc==3?[NSString stringWithUTF8String:argv[2]]:nil;
  NSString *link=photo?CophonePhotoResultURL(identifier):CophoneSavedNoteURL(identifier);
  if(!(exact&1) || !link){out[@"error"]=@"精确跳转插件或指定结果未就绪，未发送测试。";}else{NSError *error=nil;BOOL okay=SendTaskResultNotification(photo?@"定位测试：点击打开 cophone 相簿里这张图片。":@"笔记定位复测：点击打开已有的视频推荐正文。",photo?@"open-photos":@"open-notes",link,&error);out[@"testSubmitted"]=@(okay);out[@"resultURL"]=link;if(error)out[@"error"]=error.localizedDescription;}
 }
 if([@[@"badge-notes",@"badge-photos"] containsObject:mode])out[@"badgeSubmitted"]=@(CophoneMarkResultBadge([mode isEqual:@"badge-notes"]?@"open-notes":@"open-photos"));
 puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL] encoding:NSUTF8StringEncoding].UTF8String);
}return 0;}
