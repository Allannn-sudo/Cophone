#import <Foundation/Foundation.h>
NSDictionary *CophoneParseMenuHTTP(NSData *request,NSString *token);
NSDictionary *CophoneMenuRequest(NSString *path,NSDictionary *body);
@interface CophoneMenuServer : NSObject
@property(nonatomic) int socketFD;
@property(nonatomic) int tokenHigh;
@property(nonatomic) int tokenLow;
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSDictionary *(^handler)(NSString *path,NSDictionary *body);
- (BOOL)start;
@end
