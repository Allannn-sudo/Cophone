#import <Foundation/Foundation.h>
// Completion actions owned by cophone only. Progress and other apps stay unchanged.
static inline NSString *CophoneNotificationDestination(id section,id info){
 if(![section isKindOfClass:NSString.class] || ![section isEqual:@"ai.whaletech.cophone.classic"] || ![info isKindOfClass:NSDictionary.class])return nil;
 id delivery=info[@"CoPhoneDeliveryID"];
 if(![delivery isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:delivery])return nil;
 if([info[@"CoPhoneAction"] isEqual:@"open-notes"])return @"com.apple.mobilenotes";
 if([info[@"CoPhoneAction"] isEqual:@"show-result"] && [info[@"CoPhoneResultDestination"] isEqual:@"photos"])return @"com.apple.mobileslideshow";
 return nil;
}
