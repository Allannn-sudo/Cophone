#import <Foundation/Foundation.h>
// Notes has no registered URL scheme: the system Spotlight search://<bundle>/<record>
// dispatcher selects Notes, whose handler reads the numeric lastPathComponent as NoteObject.integerId
// (ZINTEGERID), NOT the Core Data Z_PK.
// iOS 6 native application:handleOpenURL: / PhotosURLNavigationRequest formats.
static inline BOOL CophoneResultUUID(id value){
 if(![value isKindOfClass:NSString.class] || [value length]!=36)return NO;
 return [[[[NSUUID alloc] initWithUUIDString:value] UUIDString] isEqual:[value uppercaseString]];
}
static inline NSString *CophoneNoteResultURL(id recordID){
 if(![recordID isKindOfClass:NSNumber.class])return nil;
 long long number=[recordID longLongValue];if(number<=0 || number>2147483647 || [recordID doubleValue]!=(double)number)return nil;
 return [NSString stringWithFormat:@"search://com.apple.mobilenotes/%lld",number];
}
static inline NSString *CophonePhotoResultURL(id assetURL){
 if(![assetURL isKindOfClass:NSString.class])return nil;
 NSURL *url=[NSURL URLWithString:assetURL];
 if(![url.scheme isEqual:@"assets-library"] || ![url.host isEqual:@"asset"] || url.fragment || url.user || url.password || url.port)return nil;
 NSString *identifier=nil;
 for(NSString *pair in [url.query componentsSeparatedByString:@"&"]){NSArray *parts=[pair componentsSeparatedByString:@"="];if(parts.count==2 && [[parts objectAtIndex:0] isEqual:@"id"]){if(identifier)return nil;identifier=[[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];}}
 if(!CophoneResultUUID(identifier))return nil;
 return [@"photos://asset?uuid=" stringByAppendingString:identifier];
}
static inline NSURL *CophoneValidatedResultURL(id value,NSString *target){
 if(![value isKindOfClass:NSString.class] || [value length]>180)return nil;
 NSURL *url=[NSURL URLWithString:value];
 if(url.fragment || url.user || url.password || url.port)return nil;
 if([target isEqual:@"com.apple.mobilenotes"]){
  NSString *digits=url.lastPathComponent;
  if(!digits.length || [digits rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location!=NSNotFound)return nil;
  NSString *expected=CophoneNoteResultURL(@(digits.longLongValue));
  return [value isEqual:expected]?url:nil;
 }
 if([target isEqual:@"com.apple.mobileslideshow"]){
  NSString *prefix=@"photos://asset?uuid=";
  if(![value hasPrefix:prefix])return nil;
  NSString *identifier=[value substringFromIndex:prefix.length];
  return CophoneResultUUID(identifier)?url:nil;
 }
 return nil;
}
