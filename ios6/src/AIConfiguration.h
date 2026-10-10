#import <Foundation/Foundation.h>
// Policy belongs to the installed IPA, never to a copied configuration file.
static inline BOOL CophoneRequiresManualAI(NSString *documents) {
    NSString *info=[[documents stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"CoPhone.app/Info.plist"];
    return [[NSDictionary dictionaryWithContentsOfFile:info][@"CophoneRequireManualAPI"] boolValue];
}
static inline NSString *CophoneConfiguredKey(NSString *documents,NSDictionary *config,NSString *provider) {
    NSString *key=config[provider];
    if(CophoneRequiresManualAI(documents) && ![config[[provider stringByAppendingString:@"_MANUAL"]] boolValue])return nil;
    return [key isKindOfClass:NSString.class] && [key rangeOfString:@"^[!-~]{10,4096}$" options:NSRegularExpressionSearch].location!=NSNotFound?key:nil;
}
