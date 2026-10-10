#import <Foundation/Foundation.h>
#import "BackgroundLaunchPolicy.h"
int main(){@autoreleasepool {
 unsigned checks=0;
 for(id front in @[NSNull.null,@"",@"com.apple.springboard",@"com.apple.mobilesafari",@"com.apple.mobilenotes",@"other.app"]){
  NSString *value=front==NSNull.null?nil:front;
  if(CophoneBackgroundLaunchIssue(YES,NO,value)){fputs("unlocked foreground rejected\n",stderr);return 1;}checks++;
  if(!CophoneBackgroundLaunchIssue(YES,YES,value)){fputs("locked foreground accepted\n",stderr);return 2;}checks++;
  if(!CophoneBackgroundLaunchIssue(NO,NO,value)){fputs("missing API accepted\n",stderr);return 3;}checks++;
 }
 if(!CophoneBackgroundLaunchIssue(YES,NO,@"net.iosipa.oldbili"))return 4;checks++;
 printf("%u background launch checks passed\n",checks);
}return 0;}
