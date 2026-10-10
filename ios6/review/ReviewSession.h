#import <Foundation/Foundation.h>

// A missing display name must never hide an otherwise identified application.
NSString *ReviewAppDisplayName(NSString *identifier,id systemName,NSDictionary *localizedInfo,NSDictionary *info);

@interface ReviewSession : NSObject
@property(nonatomic,strong) NSString *sessionID;
@property(nonatomic,strong) NSString *status;
@property(nonatomic,strong) NSMutableArray *visits;
@property(nonatomic,strong) NSMutableArray *pages;
@property(nonatomic,strong) NSMutableArray *logs;
@property(nonatomic,strong) NSMutableArray *videos;
@property(nonatomic,strong) NSMutableSet *videoKeys;
@property(nonatomic,strong) NSMutableSet *videoBaseline;
@property(nonatomic,strong) NSMutableArray *pageSources; // Raw URLs stay in memory, never in snapshots/notes.
- (void)setInitialVideos:(NSArray *)rows;
- (void)readVideos:(NSArray *)rows at:(NSTimeInterval)time;
- (void)enrichPagesFromCache:(NSString *)database;
@property(nonatomic,strong) NSMutableDictionary *baseline;
@property(nonatomic,strong) NSMutableSet *pageKeys;
@property(nonatomic,strong) NSMutableDictionary *currentVisit;
@property(nonatomic) NSTimeInterval startedAt;
@property(nonatomic) NSTimeInterval endedAt;
@property(nonatomic) NSTimeInterval desktopSince;
@property(nonatomic) NSTimeInterval desktopDelay;
@property(nonatomic) BOOL readyToCommit;
- (id)initWithID:(NSString *)identifier at:(NSTimeInterval)time history:(NSDictionary *)history;
- (void)observe:(NSString *)identifier name:(NSString *)name locked:(BOOL)locked at:(NSTimeInterval)time;
- (void)readTabState:(NSDictionary *)state modifiedAt:(NSTimeInterval)modified at:(NSTimeInterval)time;
- (void)readHistory:(NSDictionary *)history at:(NSTimeInterval)time;
- (void)log:(NSString *)message at:(NSTimeInterval)time;
- (NSDictionary *)snapshot;
- (NSString *)noteText;
- (NSString *)noteTitle;
@end
