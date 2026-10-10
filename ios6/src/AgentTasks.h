#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
@interface AgentTasks : NSObject <UIAlertViewDelegate>
@property(nonatomic,strong) NSString *documents;
@property(nonatomic,strong) NSString *snippet;
@property(nonatomic,strong) ALAssetsLibrary *library;
@property(nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property(nonatomic) BOOL saving;
@property(nonatomic,strong) NSString *settingProvider;
@property(nonatomic) NSTimeInterval albumRetryAt;
@property(nonatomic) int photoLock;
@property(nonatomic) NSUInteger photoGeneration;
@property(nonatomic) BOOL onlySafariTasks;
@property(nonatomic) BOOL headless;
- (id)initWithDocuments:(NSString *)documents;
- (void)chooseCopiedText;
- (void)configureAI;
- (void)requestPhotoAccess;
- (BOOL)submitSnippet:(NSString *)snippet action:(NSString *)action source:(NSString *)source error:(NSError **)error;
- (void)tick;
- (void)resume;
- (void)cancelWaiting;
- (NSString *)statusText;
@end
int CophoneRunPhotoWorker(BOOL probe);
