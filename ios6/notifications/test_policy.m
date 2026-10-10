#import "RoutePolicy.h"
#import "ScopedRoute.h"
#import "../results/ResultLink.h"
static NSUInteger checks;
static void check(BOOL ok,const char *name){checks++;if(!ok){fprintf(stderr,"FAILED %s\n",name);exit(1);}}
int main(){@autoreleasepool {
 NSString *own=@"ai.whaletech.cophone.classic";
 NSDictionary *notes=@{@"CoPhoneAction":@"open-notes",@"CoPhoneDeliveryID":NSUUID.UUID.UUIDString};
 NSDictionary *photos=@{@"CoPhoneAction":@"show-result",@"CoPhoneResultDestination":@"photos",@"CoPhoneDeliveryID":NSUUID.UUID.UUIDString};
 check([CophoneNotificationDestination(own,notes) isEqual:@"com.apple.mobilenotes"],"verified completion routes to Notes");
 check([CophoneNotificationDestination(own,photos) isEqual:@"com.apple.mobileslideshow"],"image completion routes to Photos");
 check(!CophoneNotificationDestination(@"com.apple.mobilesafari",notes),"foreign section never changed");
 check(!CophoneNotificationDestination(own,@{@"CoPhoneAction":@"open-notes"}),"missing delivery ID rejected");
 check(!CophoneNotificationDestination(own,@{@"CoPhoneAction":@"open-notes",@"CoPhoneDeliveryID":@"not-a-uuid"}),"malformed delivery ID rejected");
 check(!CophoneNotificationDestination(own,@{@"CoPhoneAction":@"show-result",@"CoPhoneDeliveryID":NSUUID.UUID.UUIDString}),"progress and failure stay in cophone");
 check(!CophoneNotificationDestination(own,@{@"CoPhoneAction":@"notification-test",@"CoPhoneDeliveryID":NSUUID.UUID.UUIDString}),"self test unchanged");
 check(!CophoneNotificationDestination(own,@{@"CoPhoneAction":@"open-evil",@"CoPhoneResultDestination":@"photos",@"CoPhoneDeliveryID":NSUUID.UUID.UUIDString}),"unknown action cannot use destination marker");
 check(!CophoneNotificationDestination(own,@[@"bad"]),"wrong info type rejected");
 check(!CophoneNotificationDestination(@12,photos),"wrong section type rejected");
 check(!CophoneNotificationDestination(own,@{@"CoPhoneAction":@"show-result",@"CoPhoneResultDestination":@"com.apple.mobilesafari",@"CoPhoneDeliveryID":NSUUID.UUID.UUIDString}),"arbitrary target rejected");
 check([CophoneScopedLaunchTarget(own,nil) isEqual:own],"ordinary cophone launch stays unchanged");
 check([CophoneScopedLaunchTarget(own,@"com.apple.mobilenotes") isEqual:@"com.apple.mobilenotes"],"coalesced banner construction uses scoped Notes target");
 check([CophoneScopedLaunchTarget(own,@"com.apple.mobileslideshow") isEqual:@"com.apple.mobileslideshow"],"scoped Photos target works");
 check([CophoneScopedLaunchTarget(@"com.apple.mobilesafari",@"com.apple.mobilenotes") isEqual:@"com.apple.mobilesafari"],"scope cannot redirect another app launch");
 check([CophoneScopedLaunchTarget(own,@"evil") isEqual:own],"unknown scoped target rejected");
 id outer=CophonePushRouteScope(@"com.apple.mobilenotes");
 id inner=CophonePushRouteScope(@"com.apple.mobileslideshow");CophonePopRouteScope(inner);
 check([NSThread.currentThread.threadDictionary[CophoneRouteScopeKey] isEqual:@"com.apple.mobilenotes"],"nested scopes restore parent target");
 CophonePopRouteScope(outer);check(!NSThread.currentThread.threadDictionary[CophoneRouteScopeKey],"scope is cleared after callback");
 @try {id saved=CophonePushRouteScope(@"com.apple.mobilenotes");@try{[NSException raise:@"Test" format:@"fixture"];}@finally{CophonePopRouteScope(saved);}}@catch(NSException *exception){}
 check(!NSThread.currentThread.threadDictionary[CophoneRouteScopeKey],"exception cannot leak scope into later app launches");
 NSString *noteURL=CophoneNoteResultURL(@25);NSString *asset=@"assets-library://asset/asset.JPG?id=11223344-5566-7788-99AA-BBCCDDEEFF00&ext=JPG";
 NSString *photoURL=CophonePhotoResultURL(asset);
 check([noteURL isEqual:@"search://com.apple.mobilenotes/25"],"numeric note row creates exact item URL");
 check([CophoneValidatedResultURL(noteURL,@"com.apple.mobilenotes").absoluteString isEqual:noteURL],"native Notes result accepted");
 check([photoURL isEqual:@"photos://asset?uuid=11223344-5566-7788-99AA-BBCCDDEEFF00"],"asset receipt maps to native photo UUID");
 check([CophoneValidatedResultURL(photoURL,@"com.apple.mobileslideshow").absoluteString isEqual:photoURL],"native Photos result accepted");
 check(!CophoneValidatedResultURL(noteURL,@"com.apple.mobileslideshow"),"note URL cannot be passed to Photos");
 check(!CophoneValidatedResultURL(photoURL,@"com.apple.mobilenotes"),"photo URL cannot be passed to Notes");
 check(!CophoneNoteResultURL(@0) && !CophoneNoteResultURL(@(-1)) && !CophoneNoteResultURL(@2147483648LL) && !CophoneNoteResultURL(@1.5),"invalid record IDs rejected");
 check(!CophoneNoteResultURL(@"25"),"string record ID rejected");
 for(NSString *bad in @[@"search://com.apple.mobilenotes/0",@"search://com.apple.mobilenotes/25?x=1",@"search://com.apple.mobilenotes/025",@"search://com.apple.mobilenotes/25#fragment",@"search://user@com.apple.mobilenotes/25",@"https://note/25",@"search://com.apple.mobilenotes/2147483648",@"search://com.apple.mobilenotes/%32%35"])
  check(!CophoneValidatedResultURL(bad,@"com.apple.mobilenotes"),"noncanonical note URL rejected");
 for(NSString *bad in @[@"photos://asset?uuid=bad",[photoURL stringByAppendingString:@"&extra=1"],[photoURL stringByAppendingString:@"#fragment"],@"photos://album?uuid=11223344-5566-7788-99AA-BBCCDDEEFF00"])
  check(!CophoneValidatedResultURL(bad,@"com.apple.mobileslideshow"),"malformed or different photo destination rejected");
 check(!CophonePhotoResultURL(@"assets-library://asset/asset.JPG?ext=JPG"),"missing photo ID safely rejected");
 check(!CophonePhotoResultURL([asset stringByAppendingString:@"&id=11223344-5566-7788-99AA-BBCCDDEEFF00"]),"duplicate photo ID rejected");
 check(!CophonePhotoResultURL(@"https://asset/a?id=11223344-5566-7788-99AA-BBCCDDEEFF00"),"nonlibrary asset rejected");
 check(!CophoneValidatedResultURL(nil,@"com.apple.mobilenotes") && !CophoneValidatedResultURL(@25,@"com.apple.mobilenotes"),"absent or mistyped receipt falls back safely");
 printf("%lu notification routing checks passed\n",(unsigned long)checks);
}return 0;}
