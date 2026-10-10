#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <notify.h>
#import "MenuIPC.h"
static BOOL (*documentCan)(id,SEL,SEL,id),(*browserCan)(id,SEL,SEL,id);
static void (*menuItemsOriginal)(id,SEL,NSArray *);
static SEL imageAction,summaryAction;
static int statusToken;
static uint64_t loadFlags=1;
@interface CophoneSelectionMenu : NSObject <UIAlertViewDelegate>
@property(nonatomic) BOOL ready;
@property(nonatomic) BOOL photosReady;
@property(nonatomic) BOOL checking;
@property(nonatomic) BOOL submitting;
@property(nonatomic,strong) NSString *snippet;
@property(nonatomic,strong) NSString *action;
- (void)choose:(id)view action:(NSString *)action;
- (void)tick;
@end
static CophoneSelectionMenu *controller;
static BOOL eligible(id view) {
    if(!controller.ready)return NO;
    SEL range=NSSelectorFromString(@"hasRangedSelection"),editable=NSSelectorFromString(@"hasEditableSelection");
    return [view respondsToSelector:range] && ((BOOL(*)(id,SEL))objc_msgSend)(view,range) &&
        [view respondsToSelector:editable] && !((BOOL(*)(id,SEL))objc_msgSend)(view,editable);
}
static BOOL documentAction(id view,SEL cmd,SEL action,id sender){return action==imageAction || action==summaryAction?eligible(view):documentCan(view,cmd,action,sender);}
static BOOL browserAction(id view,SEL cmd,SEL action,id sender){return action==imageAction || action==summaryAction?eligible(view):browserCan(view,cmd,action,sender);}
static void imageSelected(id view,SEL cmd,id sender){[controller choose:view action:@"illustrate"];}
static void summarySelected(id view,SEL cmd,id sender){[controller choose:view action:@"summarize"];}
static void setItems(id menu,SEL cmd,NSArray *items) {
    NSMutableArray *next=[NSMutableArray array];
    for(UIMenuItem *item in items)if(item.action!=imageAction && item.action!=summaryAction)[next addObject:item];
    if(controller.ready){[next addObject:[[UIMenuItem alloc] initWithTitle:@"整理成图片" action:imageAction]];[next addObject:[[UIMenuItem alloc] initWithTitle:@"整理成摘要" action:summaryAction]];}
    menuItemsOriginal(menu,cmd,next);
}
@implementation CophoneSelectionMenu
- (void)tick {
    if(self.checking)return;self.checking=YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{@autoreleasepool {
        NSDictionary *status=CophoneMenuRequest(@"/v1/status",nil);
        dispatch_async(dispatch_get_main_queue(),^{
            BOOL before=self.ready;self.ready=[status[@"enabled"] boolValue];self.photosReady=[status[@"photosReady"] boolValue];self.checking=NO;
            notify_set_state(statusToken,loadFlags|(status?2:0)|(self.ready?8:0));
            if(before!=self.ready){UIMenuController *menu=UIMenuController.sharedMenuController;menu.menuItems=menu.menuItems;[menu update];}
        });
    }});
}
- (void)show:(NSString *)message {[[[UIAlertView alloc] initWithTitle:@"cophone" message:message delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];}
- (void)choose:(id)view action:(NSString *)action {
    if(self.snippet || self.submitting || !eligible(view))return;
    SEL selection=NSSelectorFromString(@"selectedDOMRange"),toString=NSSelectorFromString(@"toString");
    id range=[view respondsToSelector:selection]?((id(*)(id,SEL))objc_msgSend)(view,selection):nil;
    id text=[range respondsToSelector:toString]?((id(*)(id,SEL))objc_msgSend)(range,toString):nil;
    if(![text isKindOfClass:NSString.class]){[self show:@"未读到这段选中文字，请重新选择网页正文。未发送请求。 "];return;}
    text=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(![text length] || [text length]>2000){[self show:@"请选择 1–2000 字网页正文。未发送请求。 "];return;}
    self.snippet=text;self.action=action;
    NSString *preview=[text length]>140?[[text substringWithRange:[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,140)]] stringByAppendingString:@"…"]:text;
    BOOL image=[action isEqual:@"illustrate"];
    NSString *message=[NSString stringWithFormat:@"%@\n\n%@\n只发送这段选中文字，会使用 API 额度。",preview,image?@"由千问生成，保存到 cophone 相簿。":@"由 DeepSeek 整理，保存到系统备忘录。"];
    [[[UIAlertView alloc] initWithTitle:image?@"整理成图片？":@"整理成摘要？" message:message delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"开始整理",nil] show];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    if(index==0){self.snippet=nil;self.action=nil;return;}
    if([self.action isEqual:@"illustrate"] && !self.photosReady){self.snippet=nil;self.action=nil;[self show:@"请先在 cophone 的设置中允许相册权限。未提交生图。 "];return;}
    NSDictionary *body=@{@"snippet":self.snippet,@"action":self.action,@"consent":@YES};self.snippet=nil;self.action=nil;self.submitting=YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{@autoreleasepool {
        NSDictionary *result=CophoneMenuRequest(@"/v1/enqueue",body);
        dispatch_async(dispatch_get_main_queue(),^{self.submitting=NO;
            if(!result)[self show:@"提交结果未确认，请到 cophone 的记录页核对；不要重复提交。 "];
            else if(![result[@"accepted"] boolValue])[self show:result[@"error"] ?: @"任务未提交，请检查 cophone 后台。 "];
        });
    }});
}
@end
__attribute__((constructor)) static void installMenu(void) {@autoreleasepool {
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.mobilesafari"])return;
    controller=[CophoneSelectionMenu new];notify_register_check("ai.whaletech.cophone.menu.access",&statusToken);
    void *handle=dlopen("/usr/lib/libsubstrate.dylib",RTLD_NOW);void (*hook)(Class,SEL,IMP,IMP *)=handle?dlsym(handle,"MSHookMessageEx"):NULL;
    if(!hook){notify_set_state(statusToken,loadFlags);return;}
    imageAction=NSSelectorFromString(@"cophone_organizeImage:");summaryAction=NSSelectorFromString(@"cophone_organizeSummary:");
    Class document=NSClassFromString(@"UIWebDocumentView"),browser=NSClassFromString(@"UIWebBrowserView");
    if(document && browser) {
        class_addMethod(document,imageAction,(IMP)imageSelected,"v@:@");class_addMethod(document,summaryAction,(IMP)summarySelected,"v@:@");
        hook(document,@selector(canPerformAction:withSender:),(IMP)documentAction,(IMP *)&documentCan);hook(browser,@selector(canPerformAction:withSender:),(IMP)browserAction,(IMP *)&browserCan);
        hook(UIMenuController.class,@selector(setMenuItems:),(IMP)setItems,(IMP *)&menuItemsOriginal);loadFlags|=4;
    }
    notify_set_state(statusToken,loadFlags);
    [[NSNotificationCenter defaultCenter] addObserver:controller selector:@selector(tick) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSTimer scheduledTimerWithTimeInterval:2 target:controller selector:@selector(tick) userInfo:nil repeats:YES];
    dispatch_async(dispatch_get_main_queue(),^{[controller tick];});
}}
