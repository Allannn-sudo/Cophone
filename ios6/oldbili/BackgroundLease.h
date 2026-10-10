#import <Foundation/Foundation.h>
@interface CophoneBackgroundLease:NSObject
@property(nonatomic,strong) id assertion;
@property(atomic) BOOL acquired;
+ (instancetype)start:(NSError **)error;
- (BOOL)valid;
- (void)invalidate;
@end
