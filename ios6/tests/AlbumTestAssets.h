#import <Foundation/Foundation.h>
extern NSString *const ALAssetsGroupPropertyName;
enum { ALAssetsGroupAlbum=2 };
@interface ALAssetRepresentation : NSObject
@property(nonatomic,strong) NSURL *url;
@end
@interface ALAsset : NSObject
@property(nonatomic,strong) ALAssetRepresentation *defaultRepresentation;
@end
@interface ALAssetsGroup : NSObject
@property(nonatomic,copy) NSString *name;
@property(nonatomic,getter=isEditable) BOOL editable;
@property(nonatomic,strong) NSMutableArray *assets;
@property(nonatomic) NSUInteger adds;
@property(nonatomic) BOOL hideAdded;
- (id)valueForProperty:(NSString *)key;
- (void)enumerateAssetsUsingBlock:(void (^)(ALAsset *,NSUInteger,BOOL *))block;
- (BOOL)addAsset:(ALAsset *)asset;
@end
@interface ALAssetsLibrary : NSObject
@property(nonatomic,strong) NSMutableArray *groups;
@property(nonatomic) NSUInteger creates;
@property(nonatomic) BOOL denied;
@property(nonatomic) BOOL collide;
- (void)enumerateGroupsWithTypes:(NSUInteger)type usingBlock:(void (^)(ALAssetsGroup *,BOOL *))block failureBlock:(void (^)(NSError *))failure;
- (void)addAssetsGroupAlbumWithName:(NSString *)name resultBlock:(void (^)(ALAssetsGroup *))result failureBlock:(void (^)(NSError *))failure;
@end
