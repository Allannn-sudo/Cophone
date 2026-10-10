#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "AgentTasks.h"
#import "TaskInbox.h"
#import "AIConfiguration.h"
#import "LocalHistory.h"
#import "../voice/VoiceUI.h"

@class CoPhone;
@interface DemoController : UIViewController
@property(nonatomic,weak) CoPhone *owner;
@end
@interface CoPhone : UIResponder <UIApplicationDelegate,UITabBarDelegate,UIAlertViewDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) UIView *header;
@property(nonatomic,strong) UILabel *heading;
@property(nonatomic,strong) UILabel *edition;
@property(nonatomic,strong) UIImageView *mark;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UILabel *body;
@property(nonatomic,strong) UIButton *button;
@property(nonatomic,strong) UIButton *cancel;
@property(nonatomic,strong) UIButton *notes;
@property(nonatomic,strong) UIButton *notificationTest;
@property(nonatomic,strong) UIButton *clearHistory;
@property(nonatomic,strong) UIButton *agentButton;
@property(nonatomic,strong) UIButton *agentCancel;
@property(nonatomic,strong) UIButton *aiSettings;
@property(nonatomic,strong) UIButton *menuSettings;
@property(nonatomic,strong) UIButton *photoSettings;
@property(nonatomic,strong) UITabBar *tabs;
@property(nonatomic,strong) UIButton *observerEntry;
@property(nonatomic,strong) UIButton *snippetEntry;
@property(nonatomic,strong) UIButton *homeBack;
@property(nonatomic,strong) UIButton *oldbiliButton;
@property(nonatomic,strong) UIButton *voiceButton,*voiceSettings;
@property(nonatomic,strong) NSString *oldbiliGoal;
@property(nonatomic) NSInteger selectedSection;
@property(nonatomic) int presenceFD;
@property(nonatomic,strong) AgentTasks *agent;
@property(nonatomic,strong) NSString *pending;
@property(nonatomic) NSTimeInterval pendingAt;
- (void)layout;
@end
@implementation DemoController
- (void)viewDidLayoutSubviews {[super viewDidLayoutSubviews];[self.owner layout];}
- (BOOL)shouldAutorotate {return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return UIInterfaceOrientationMaskAllButUpsideDown;}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)o {return o!=UIInterfaceOrientationPortraitUpsideDown;}
@end
@implementation CoPhone
- (NSString *)path:(NSString *)name {NSString *dir=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];[[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];return [dir stringByAppendingPathComponent:name];}
- (NSDictionary *)state {
    NSData *data=[NSData dataWithContentsOfFile:[self path:@"review-state.json"]];
    id result=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
    return [result isKindOfClass:[NSDictionary class]]?result:@{};
}
- (NSString *)date:(NSNumber *)value {
    NSDateFormatter *f=[[NSDateFormatter alloc] init];f.dateFormat=@"MM-dd HH:mm:ss";f.timeZone=[NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:value.doubleValue]];
}
- (void)refresh {
    [self.agent tick];
    NSDictionary *s=[self state];
    BOOL alive=[s[@"version"] isEqual:@"0.4.0"] && fabs([[NSDate date] timeIntervalSince1970]-[s[@"heartbeat"] doubleValue])<8;
    BOOL acknowledged=self.pending && [s[@"command"] isEqual:self.pending];
    if(acknowledged)self.pending=nil;
    if(self.pending && [[NSDate date] timeIntervalSince1970]-self.pendingAt>15)self.pending=nil;
    NSString *status=s[@"status"] ?: @"idle";
    NSDictionary *names=@{@"idle":@"目视官待命",@"awaiting_leave":@"已开始：现在按 Home 正常用手机",@"recording":@"正在记录本轮使用活动",@"finishing":@"正在写入系统备忘录",@"completed":@"目视官已写入系统备忘录",@"paused":@"本轮已暂停",@"cancelled":@"本轮已取消并清除采集记录",@"failed":@"本轮未完成，请查看原因"};
    NSString *reviewStatus=!alive?@"后台服务未就绪":self.pending?@"等待确认，请暂留此页…":names[status] ?: status;
    NSInteger section=self.selectedSection;
    self.statusLabel.text=section==3?@"目视官":section==4?@"交办任务":section==0?(!alive?@"后台服务未连接":self.pending?@"正在确认请求…":@"选择一项任务"):section==1?@"记录":@"设置与诊断";
    NSMutableString *text=[NSMutableString string];
    if(section==0) {
        // Home contains only entry cards, never stored records or diagnostics.
    } else if(section==3) {
        [text appendString:@"记录你本轮使用了哪些应用，\n将可读到的网页和视频信息按应用分段。\n\n开始后按 Home 正常使用手机。\n回桌面停留 6 秒，保存到系统备忘录。\n\n其他应用目前只记录名称和时长，\n不会猜测未读到的内容。"];
    } else if(section==4) {
        [text appendString:@"oldbili 找视频\n自动在后台唤起 oldbili，无需先打开。\n用一句话说明主题、时长和适合谁。\n提交后切到 Safari，正常使用手机。\n\n手机 AI 按真实搜索结果决定下一步，\n比较标题和简介后写入备忘录。\n当前不自动播放、收藏或登录。\n\n摘录整理\n用复制的文字生成摘要或配图；\nSafari 也可直接选文整理。\n\n进度、结果和执行依据请看“记录”。"];
    } else if(section==2) {
        [text appendFormat:@"cophone 0.10.0 · iPhone 4 / iOS 6\n后台服务：%@\n\nSafari 选中文字后可直接整理成图片或摘要。首次安装菜单插件后，需要退出并重新打开 Safari；不需重启桌面。系统可能将新选项放到菜单右箭头的下一页。\n\n手机直接连接 DeepSeek / 千问。密钥只在本机私有配置保存。\n\n通知自检只检查显示。目视官记录不上云；AI 只发送你确认的摘录。视频元数据不代表完整视频理解。\n\n生成图片归入 cophone 相簿，也会出现在相机胶卷。",alive?(s[@"serviceVersion"] ?: @"已连接"):@"未连接，请安装配套 DEB"];
    } else {
    if([s[@"historyCleared"] boolValue] && !CophoneTaskJSON([self path:@"agent-request.json"])[@"id"] && !CophoneTaskJSON([self path:@"oldbili-state.json"])[@"id"] && !CophoneTaskJSON([self path:@"voice-state.json"])[@"id"])[text appendString:@"暂无历史记录。\n系统备忘录、照片和 API 设置均保留。\n"];
    else {
    [text appendFormat:@"%@\n",reviewStatus];
    if(!alive)[text appendString:@"\n后台服务未就绪：普通 IPA 无法持续观察其他应用。请先安装配套 CoPhone Review Service DEB；不用每次安装或刷新桌面。\n"];
    if(s[@"error"])[text appendFormat:@"\n提示：%@\n",s[@"error"]];
    NSDictionary *receipt=s[@"receipt"];
    if([receipt[@"verified"] boolValue])[text appendFormat:@"\n✓ 已独立回读系统备忘录正文\n%@\n位置：本机备忘录\n通知：%@\n",receipt[@"title"] ?: @"目视官",[s[@"notificationSubmitted"] boolValue]?@"已提交系统（显示取决于通知设置）":@"尚未提交 / 请手动查看"];
    [text appendFormat:@"\n本轮应用记录：%lu 段\n",(unsigned long)[s[@"visits"] count]];
    for(NSDictionary *v in s[@"visits"])[text appendFormat:@"• %@ %@ — %@，约 %.0f 秒\n",v[@"name"],[self date:v[@"start"]],[self date:v[@"end"]],MAX(0,[v[@"end"] doubleValue]-[v[@"start"] doubleValue])];
    [text appendFormat:@"\nSafari 新增页面：%lu 条\n",(unsigned long)[s[@"pages"] count]];
    for(NSDictionary *p in s[@"pages"])[text appendFormat:@"• %@\n%@\n",p[@"title"],p[@"url"]];
    for(NSDictionary *v in s[@"videos"])[text appendFormat:@"\n视频：%@\nUP主：%@\n%@\n",v[@"title"],v[@"author"] ?: @"未提供",v[@"description"] ?: @""];
    NSDictionary *voiceState=CophoneTaskJSON([self path:@"voice-state.json"]);if(voiceState[@"status"])[text appendFormat:@"\n语音交办 · %@\n%@\n",voiceState[@"status"],voiceState[@"error"] ?: voiceState[@"transcript"] ?: @""];
    NSDictionary *b=CophoneTaskJSON([self path:@"oldbili-state.json"]);
    if(b.count){NSDictionary *labels=@{@"queued":@"已排队",@"planning":@"AI 正在决定下一步",@"operating":@"正在 oldbili 操作",@"saving":@"正在保存备忘录",@"completed":@"已保存并回读验证",@"failed":@"未完成",@"uncertain":@"中断，未自动重放",@"cancelled":@"已停止"};
        [text appendFormat:@"\noldbili 任务 · %@\n%@\n",labels[b[@"status"]] ?: @"等待",b[@"goal"] ?: @""];
        if(b[@"error"])[text appendFormat:@"%@\n",b[@"error"]];
        for(NSDictionary *step in b[@"trace"])[text appendFormat:@"%@: %@ · %@\n",step[@"step"],step[@"action"],step[@"reason"]];
        if([b[@"verified"] boolValue])[text appendFormat:@"✓ %@\n",b[@"receipt"][@"title"] ?: @"真实备忘录已核对"];
    }
    [text appendFormat:@"\n%@\n",[self.agent statusText]];
    [text appendString:@"\n执行日志\n"];
    for(NSDictionary *l in s[@"logs"])[text appendFormat:@"%@ · %@\n",[self date:l[@"time"]],l[@"message"]];
    }
    }
    self.body.text=text;
    BOOL active=[@[@"awaiting_leave",@"recording",@"finishing"] containsObject:status];
    [self.button setTitle:active?@"正在记录":@"开始记录" forState:UIControlStateNormal];
    BOOL menuEnabled=[CophoneTaskJSON([self path:@"menu-settings.json"])[@"enabled"] boolValue];
    [self.menuSettings setTitle:menuEnabled?@"Safari 菜单：已开启":@"Safari 菜单：已关闭" forState:UIControlStateNormal];
    self.button.enabled=alive && !self.pending && !active;self.cancel.enabled=alive && !self.pending && active;
    NSDictionary *voiceSetting=CophoneTaskJSON([self path:@"voice-settings.json"]);[self.voiceSettings setTitle:(!voiceSetting[@"enabled"] || [voiceSetting[@"enabled"] boolValue])?@"长按 Home 语音：已开启":@"长按 Home 语音：已关闭" forState:UIControlStateNormal];
    [self layout];
}
- (void)command:(NSString *)action {
    NSString *identifier=[[NSUUID UUID] UUIDString];
    NSDictionary *command=@{@"id":identifier,@"action":action,@"issuedAt":@([[NSDate date] timeIntervalSince1970])};
    NSError *error=nil;NSData *data=[NSJSONSerialization dataWithJSONObject:command options:0 error:&error];
    if(![data writeToFile:[self path:@"review-control.json"] options:NSDataWritingAtomic error:&error]) {
        [[[UIAlertView alloc] initWithTitle:@"请求未保存" message:error.localizedDescription delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;
    }
    self.pending=identifier;self.pendingAt=[[NSDate date] timeIntervalSince1970];[self refresh];[self.scroll setContentOffset:CGPointMake(0,0) animated:YES];
}
- (void)start {CophoneWriteTaskJSON(@{@"enabled":@YES},[self path:@"menu-settings.json"]);[self command:@"start"];}
- (void)toggleMenu {BOOL enabled=[CophoneTaskJSON([self path:@"menu-settings.json"])[@"enabled"] boolValue];CophoneWriteTaskJSON(@{@"enabled":@(!enabled)},[self path:@"menu-settings.json"]);[self refresh];}
- (void)openObserver {self.selectedSection=3;[self.scroll setContentOffset:CGPointZero animated:NO];[self refresh];}
- (void)openTasks {self.selectedSection=4;[self.scroll setContentOffset:CGPointZero animated:NO];[self refresh];}
- (void)oldbiliTask {
    NSString *doc=[[self path:@"oldbili-state.json"] stringByDeletingLastPathComponent];NSDictionary *config=CophoneTaskJSON([[doc stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library/Application Support/cophone/ai-config.json"]);
    if(CophoneRequiresManualAI(doc) && !CophoneConfiguredKey(doc,config,@"DEEPSEEK_API_KEY")){[self.agent configureAI];return;}
    NSDictionary *state=CophoneTaskJSON([self path:@"oldbili-state.json"]);
    if([@[@"queued",@"planning",@"operating",@"saving"] containsObject:state[@"status"]]){[[[UIAlertView alloc] initWithTitle:@"已有任务在执行" message:@"请到记录页查看进度，或停止当前任务。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    UIAlertView *a=[[UIAlertView alloc] initWithTitle:@"交给 cophone" message:@"说说你想找什么视频" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"下一步",nil];a.alertViewStyle=UIAlertViewStylePlainTextInput;a.tag=1101;
    [a textFieldAtIndex:0].text=@"找两个适合零基础、30分钟以内的 AI Agent 视频，比较后推荐一个，把理由记到备忘录。";[a show];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)index {
    if(index==a.cancelButtonIndex)return;
    if(a.tag==1101){
        NSString *goal=[[a textFieldAtIndex:0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!goal.length || goal.length>500)return;self.oldbiliGoal=goal;
        UIAlertView *confirm=[[UIAlertView alloc] initWithTitle:@"开始 oldbili 任务？" message:[goal stringByAppendingString:@"\n\n手机调用 DeepSeek 决策，核对后写入备忘录。确认后静默唤起 oldbili，可继续使用手机。"] delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"开始",nil];confirm.tag=1102;[confirm show];
    } else if(a.tag==1201){[self command:@"clear-history"];
    } else if(a.tag==1102 && self.oldbiliGoal.length){
        NSString *doc=[[self path:@"oldbili-request.json"] stringByDeletingLastPathComponent],*session=CophoneAppSession(doc);if(!session)return;NSString *identifier=NSUUID.UUID.UUIDString;
        NSDictionary *r=@{@"id":identifier,@"goal":self.oldbiliGoal,@"appSession":session,@"issuedAt":@(NSDate.date.timeIntervalSince1970)};
        BOOL ok=CophoneWriteTaskJSON(@{@"id":identifier,@"goal":self.oldbiliGoal,@"status":@"queued"},[self path:@"oldbili-state.json"]) && CophoneWriteTaskJSON(r,[self path:@"oldbili-request.json"]);self.oldbiliGoal=nil;
        [[[UIAlertView alloc] initWithTitle:ok?@"任务已排队":@"任务未保存" message:ok?@"现在按 Home 切到 Safari 正常使用；进度与执行依据在记录页。":@"请稍后重试。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];[self refresh];
    }
}
- (void)goHome {self.selectedSection=0;[self.scroll setContentOffset:CGPointZero animated:NO];[self refresh];}
- (void)voiceTask {CophoneStartVoiceUI();}
- (void)toggleVoice {NSDictionary *s=CophoneTaskJSON([self path:@"voice-settings.json"]);BOOL enabled=!s[@"enabled"] || [s[@"enabled"] boolValue];CophoneWriteTaskJSON(@{@"enabled":@(!enabled)},[self path:@"voice-settings.json"]);[self refresh];}
- (void)agentTask {[self.agent chooseCopiedText];}
- (void)cancelAgent {[self.agent cancelWaiting];NSString *identifier=CophoneTaskJSON([self path:@"oldbili-request.json"])[@"id"];if(identifier)CophoneWriteTaskJSON(@{@"id":identifier},[self path:@"oldbili-cancel.json"]);}
- (void)configureAI {[self.agent configureAI];}
- (void)configurePhotos {[self.agent requestPhotoAccess];}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {self.selectedSection=item.tag;[self.scroll setContentOffset:CGPointZero animated:NO];[self refresh];}
- (void)clearHistoryTapped {
    if(CophoneLocalTasksActive([[self path:@"review-state.json"] stringByDeletingLastPathComponent])){[[[UIAlertView alloc] initWithTitle:@"任务仍在运行" message:@"请先完成或停止任务，再清除历史记录。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];return;}
    UIAlertView *a=[[UIAlertView alloc] initWithTitle:@"清除 App 内历史记录？" message:@"删除记录页中的任务、回顾、选文及执行缓存。系统备忘录、照片和 API 设置保留。正在执行时请先结束任务。" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"清除记录",nil];a.tag=1201;[a show];
}
- (void)cancelRound {[self command:@"cancel"];}
- (void)openNotes {[self command:@"open-notes"];}
- (void)testNotification {
    UILocalNotification *n=[[UILocalNotification alloc] init];
    n.fireDate=[NSDate dateWithTimeIntervalSinceNow:8];
    n.alertBody=@"cophone 通知自检：通知显示正常。这不是任务完成通知。";
    n.alertAction=@"打开";n.userInfo=@{@"CoPhoneAction":@"notification-test"};
    [[UIApplication sharedApplication] scheduleLocalNotification:n];
    [[[UIAlertView alloc] initWithTitle:@"8 秒后通知自检" message:@"现在按 Home 回桌面等待。这条消息仅测试通知，不会记录活动或写入备忘录。" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil] show];
}

- (void)layout {
    CGSize bounds=self.window.rootViewController.view.bounds.size;CGFloat width=bounds.width,inner=width-32;
    self.header.frame=CGRectMake(0,0,width,66);
    self.mark.frame=CGRectMake(16,9,46,46);self.mark.layer.cornerRadius=CGRectGetWidth(self.mark.bounds)*0.175;self.heading.frame=CGRectMake(74,7,width-86,28);self.edition.frame=CGRectMake(74,35,width-86,22);
    self.tabs.frame=CGRectMake(0,bounds.height-49,width,49);
    self.scroll.frame=CGRectMake(0,76,width,MAX(0,bounds.height-125));
    NSInteger section=self.selectedSection;
    for(UIView *view in @[self.button,self.cancel,self.notes,self.agentButton,self.agentCancel,self.aiSettings,self.menuSettings,self.photoSettings,self.notificationTest,self.clearHistory,self.homeBack,self.oldbiliButton,self.voiceButton,self.voiceSettings,self.observerEntry,self.snippetEntry])view.hidden=YES;
    self.statusLabel.hidden=section==0;self.body.hidden=section==0;
    CGFloat y=8;CGSize size=[self.statusLabel sizeThatFits:CGSizeMake(inner,CGFLOAT_MAX)];
    self.statusLabel.frame=CGRectMake(16,y,inner,size.height);y+=size.height+14;
    if(section==0) {
        self.observerEntry.hidden=NO;self.observerEntry.frame=CGRectMake(16,8,inner,126);
        self.snippetEntry.hidden=NO;self.snippetEntry.frame=CGRectMake(16,148,inner,126);
        self.scroll.contentSize=CGSizeMake(width,290);return;
    } else if(section==3) {
        self.button.hidden=NO;self.button.frame=CGRectMake(16,y,inner,44);y+=54;
        if(self.cancel.enabled){self.cancel.hidden=NO;self.cancel.frame=CGRectMake(16,y,inner,36);y+=46;}
        self.homeBack.hidden=NO;self.homeBack.frame=CGRectMake(16,y,inner,32);y+=44;
    } else if(section==4) {
        self.oldbiliButton.hidden=NO;self.oldbiliButton.frame=CGRectMake(16,y,inner,44);y+=54;
        self.voiceButton.hidden=NO;self.voiceButton.frame=CGRectMake(16,y,inner,44);y+=54;
        self.agentButton.hidden=NO;self.agentButton.frame=CGRectMake(16,y,inner,44);y+=54;
        self.homeBack.hidden=NO;self.homeBack.frame=CGRectMake(16,y,inner,32);y+=44;
    } else if(section==1) {
        self.notes.hidden=NO;self.notes.frame=CGRectMake(16,y,inner,36);y+=46;
        self.agentCancel.hidden=NO;self.agentCancel.frame=CGRectMake(16,y,inner,36);y+=48;
        self.clearHistory.hidden=NO;self.clearHistory.frame=CGRectMake(16,y,inner,36);y+=48;
    } else {
        self.aiSettings.hidden=NO;self.aiSettings.frame=CGRectMake(16,y,inner,44);y+=54;
        self.voiceSettings.hidden=NO;self.voiceSettings.frame=CGRectMake(16,y,inner,40);y+=50;
        self.menuSettings.hidden=NO;self.menuSettings.frame=CGRectMake(16,y,inner,40);y+=50;
        self.photoSettings.hidden=NO;self.photoSettings.frame=CGRectMake(16,y,inner,40);y+=50;
        self.notificationTest.hidden=NO;self.notificationTest.frame=CGRectMake(16,y,inner,40);y+=52;
    }
    size=[self.body sizeThatFits:CGSizeMake(inner,CGFLOAT_MAX)];self.body.frame=CGRectMake(16,y,inner,size.height);self.scroll.contentSize=CGSizeMake(width,y+size.height+24);
}
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeRoundedRect];[b setTitle:title forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[self.scroll addSubview:b];return b;
}
- (UIButton *)entry:(NSString *)title detail:(NSString *)detail action:(SEL)action {
    UIButton *card=[UIButton buttonWithType:UIButtonTypeCustom];card.backgroundColor=[UIColor whiteColor];
    card.frame=CGRectMake(16,0,288,126);card.layer.cornerRadius=10;card.layer.borderWidth=1;card.layer.borderColor=[UIColor colorWithRed:0.83 green:0.89 blue:0.92 alpha:1].CGColor;
    [card addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    UILabel *heading=[[UILabel alloc] initWithFrame:CGRectMake(18,17,210,27)];heading.text=title;heading.font=[UIFont boldSystemFontOfSize:20];heading.textColor=[UIColor colorWithRed:0.04 green:0.22 blue:0.35 alpha:1];heading.backgroundColor=[UIColor clearColor];heading.autoresizingMask=UIViewAutoresizingFlexibleWidth;[card addSubview:heading];
    UILabel *caption=[[UILabel alloc] initWithFrame:CGRectMake(18,51,252,56)];caption.text=detail;caption.numberOfLines=3;caption.font=[UIFont systemFontOfSize:14];caption.textColor=[UIColor darkGrayColor];caption.backgroundColor=[UIColor clearColor];caption.autoresizingMask=UIViewAutoresizingFlexibleWidth;[card addSubview:caption];
    [self.scroll addSubview:card];return card;
}
- (UIImage *)tabIcon:(NSInteger)kind {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(28,28),NO,0);
    [[UIColor blackColor] setStroke];[[UIColor blackColor] setFill];
    UIBezierPath *p=[UIBezierPath bezierPath];p.lineWidth=2.4;p.lineCapStyle=kCGLineCapRound;p.lineJoinStyle=kCGLineJoinRound;
    if(kind==0) {
        [p moveToPoint:CGPointMake(3,13)];[p addLineToPoint:CGPointMake(14,3)];[p addLineToPoint:CGPointMake(25,13)];
        [p moveToPoint:CGPointMake(6,12)];[p addLineToPoint:CGPointMake(6,25)];[p addLineToPoint:CGPointMake(11,25)];[p addLineToPoint:CGPointMake(11,17)];[p addLineToPoint:CGPointMake(17,17)];[p addLineToPoint:CGPointMake(17,25)];[p addLineToPoint:CGPointMake(22,25)];[p addLineToPoint:CGPointMake(22,12)];
    } else if(kind==1) {
        for(int i=0;i<3;i++){CGFloat y=7+i*7;[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3,y-1,3,3)] fill];[p moveToPoint:CGPointMake(10,y)];[p addLineToPoint:CGPointMake(25,y)];}
    } else {
        [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(6,6,16,16)]];
        [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(11,11,6,6)]];
        for(int i=0;i<8;i++){CGFloat a=i*M_PI/4;[p moveToPoint:CGPointMake(14+8*cos(a),14+8*sin(a))];[p addLineToPoint:CGPointMake(14+12*cos(a),14+12*sin(a))];}
    }
    [p stroke];UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();return image;
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.presenceFD=CophoneAcquirePresence([[self path:@"agent-request.json"] stringByDeletingLastPathComponent]);
    self.agent=[[AgentTasks alloc] initWithDocuments:[[self path:@"agent-request.json"] stringByDeletingLastPathComponent]];
    if(![[NSFileManager defaultManager] fileExistsAtPath:[self path:@"menu-settings.json"]])CophoneWriteTaskJSON(@{@"enabled":@YES},[self path:@"menu-settings.json"]);
    self.window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];DemoController *controller=[[DemoController alloc] init];controller.owner=self;
    controller.view.backgroundColor=[UIColor colorWithRed:0.92 green:0.97 blue:0.99 alpha:1];
    self.scroll=[[UIScrollView alloc] init];[controller.view addSubview:self.scroll];
    self.header=[[UIView alloc] init];self.header.backgroundColor=[UIColor colorWithRed:0.02 green:0.11 blue:0.26 alpha:1];[controller.view addSubview:self.header];
    self.mark=[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Icon"]];self.mark.layer.masksToBounds=YES;[self.header addSubview:self.mark];
    self.heading=[[UILabel alloc] init];self.heading.text=@"cophone";self.heading.font=[UIFont boldSystemFontOfSize:20];self.heading.textColor=[UIColor whiteColor];self.heading.backgroundColor=[UIColor clearColor];[self.header addSubview:self.heading];
    self.edition=[[UILabel alloc] init];self.edition.text=@"手机独立 AI 助手 · 0.10.0";self.edition.font=[UIFont systemFontOfSize:12];self.edition.textColor=[UIColor colorWithRed:0.45 green:0.88 blue:0.93 alpha:1];self.edition.backgroundColor=[UIColor clearColor];[self.header addSubview:self.edition];
    self.tabs=[[UITabBar alloc] init];self.tabs.delegate=self;
    NSMutableArray *items=[NSMutableArray array];NSArray *titles=@[@"主页",@"记录",@"设置"];
    for(NSInteger i=0;i<3;i++)[items addObject:[[UITabBarItem alloc] initWithTitle:titles[i] image:[self tabIcon:i] tag:i]];
    self.tabs.items=items;self.tabs.selectedItem=items[0];[controller.view addSubview:self.tabs];
    self.statusLabel=[[UILabel alloc] init];self.statusLabel.numberOfLines=0;self.statusLabel.font=[UIFont boldSystemFontOfSize:17];self.statusLabel.backgroundColor=[UIColor clearColor];[self.scroll addSubview:self.statusLabel];
    self.button=[self button:@"启动" action:@selector(start)];self.cancel=[self button:@"取消并清除本轮" action:@selector(cancelRound)];self.notes=[self button:@"打开系统备忘录" action:@selector(openNotes)];
    self.agentButton=[self button:@"用复制的文字做任务" action:@selector(agentTask)];
    self.agentCancel=[self button:@"停止等待 AI 任务" action:@selector(cancelAgent)];
    self.clearHistory=[self button:@"清除 App 内历史记录" action:@selector(clearHistoryTapped)];
    self.aiSettings=[self button:@"AI 设置（手机独立联网）" action:@selector(configureAI)];
    self.menuSettings=[self button:@"Safari 菜单：已开启" action:@selector(toggleMenu)];
    self.photoSettings=[self button:@"相册权限" action:@selector(configurePhotos)];
    self.notificationTest=[self button:@"通知自检（8 秒后）" action:@selector(testNotification)];
    self.observerEntry=[self entry:@"目视官  ›" detail:@"记录本轮操作与浏览内容\n按应用整理到备忘录" action:@selector(openObserver)];
    self.snippetEntry=[self entry:@"交办任务  ›" detail:@"一句话找视频、比较并整理\n摘录可生成摘要或配图" action:@selector(openTasks)];
    self.voiceButton=[self button:@"语音交办" action:@selector(voiceTask)];self.voiceSettings=[self button:@"长按 Home 语音：已开启" action:@selector(toggleVoice)];
    self.oldbiliButton=[self button:@"用一句话找视频" action:@selector(oldbiliTask)];
    self.homeBack=[self button:@"返回主页" action:@selector(goHome)];
    self.body=[[UILabel alloc] init];self.body.numberOfLines=0;self.body.font=[UIFont systemFontOfSize:15];self.body.backgroundColor=[UIColor clearColor];[self.scroll addSubview:self.body];
    self.window.rootViewController=controller;[self.window makeKeyAndVisible];[self refresh];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    UILocalNotification *launchNotification=options[UIApplicationLaunchOptionsLocalNotificationKey];
    if([launchNotification.userInfo[@"CoPhoneAction"] isEqual:@"open-notes"])[self performSelector:@selector(openNotes) withObject:nil afterDelay:0.5];
    if([launchNotification.userInfo[@"CoPhoneAction"] isEqual:@"show-result"]){self.selectedSection=1;self.tabs.selectedItem=self.tabs.items[1];[self refresh];}
    return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {application.applicationIconBadgeNumber=0;CophoneWriteTaskJSON(@{@"authorized":@([ALAssetsLibrary authorizationStatus]==ALAuthorizationStatusAuthorized)},[self path:@"photo-permission.json"]);[self.agent resume];[self refresh];}
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    [self refresh];if(application.applicationState!=UIApplicationStateActive && [notification.userInfo[@"CoPhoneAction"] isEqual:@"open-notes"])[self openNotes];
    if(application.applicationState!=UIApplicationStateActive && [notification.userInfo[@"CoPhoneAction"] isEqual:@"show-result"]){self.selectedSection=1;self.tabs.selectedItem=self.tabs.items[1];[self.scroll setContentOffset:CGPointZero animated:NO];[self refresh];}
}
@end
int main(int argc,char **argv) {@autoreleasepool{
    if(argc==2 && [[NSString stringWithUTF8String:argv[1]] isEqual:@"--photo-probe"])return CophoneRunPhotoWorker(YES);
    if(argc==2 && [[NSString stringWithUTF8String:argv[1]] isEqual:@"--photo-worker"])return CophoneRunPhotoWorker(NO);
    return UIApplicationMain(argc,argv,nil,NSStringFromClass([CoPhone class]));
}}
