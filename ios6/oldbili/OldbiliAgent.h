#import <Foundation/Foundation.h>
@interface CophoneOldbiliAgent:NSObject
@property(nonatomic) BOOL busy;
- (void)tick:(NSString *)documents unlocked:(BOOL)unlocked;
@end
