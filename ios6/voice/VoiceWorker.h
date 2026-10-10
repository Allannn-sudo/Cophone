#import <Foundation/Foundation.h>
@interface CophoneVoiceWorker:NSObject
@property(nonatomic) BOOL busy;
@property(atomic) BOOL unlocked;
- (void)tick:(NSString *)documents unlocked:(BOOL)unlocked;
@end
