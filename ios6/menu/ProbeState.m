#import <Foundation/Foundation.h>
#import <notify.h>
#import "MenuIPC.h"
#import "../src/TaskInbox.h"
int main(void){@autoreleasepool {NSString *documents=CophoneDocuments();printf("APP_PRESENCE online=%d\n",CophoneAppSession(documents)!=nil);int token;uint64_t state=0;notify_register_check("ai.whaletech.cophone.menu.access",&token);notify_get_state(token,&state);notify_cancel(token);printf("SAFARI_MENU loaded=%d connected=%d hooksInstalled=%d ready=%d\n",!!(state&1),!!(state&2),!!(state&4),!!(state&8));NSDictionary *s=CophoneMenuRequest(@"/v1/status",nil);printf("MENU_LOCAL_SERVER reachable=%d enabled=%d photosReady=%d\n",s!=nil,[s[@"enabled"] boolValue],[s[@"photosReady"] boolValue]);}return 0;}
