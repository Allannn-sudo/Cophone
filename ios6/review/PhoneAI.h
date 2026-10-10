#import <Foundation/Foundation.h>
@interface PhoneAIEngine : NSObject
@property(nonatomic,copy) BOOL (^shouldContinue)(void);
- (void)processRequest:(NSDictionary *)request documents:(NSString *)documents config:(NSDictionary *)config;
- (NSData *)fetch:(NSURL *)url key:(NSString *)key payload:(NSDictionary *)payload asynchronous:(BOOL)asynchronous limit:(NSUInteger)limit error:(NSError **)error;
@end
@interface PhoneAIWorker : NSObject
@property(nonatomic) BOOL busy;
@property(nonatomic,copy) BOOL (^shouldContinue)(void);
@property(nonatomic) NSTimeInterval checkedAt;
- (void)tickDocuments:(NSString *)documents unlocked:(BOOL)unlocked;
@end
