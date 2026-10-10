#import "PhotoAlbum.h"
NSString *const ALAssetsGroupPropertyName=@"name";
@implementation ALAssetRepresentation
@end
@implementation ALAsset
@end
@implementation ALAssetsGroup
- (id)init {if((self=[super init])){self.assets=[NSMutableArray array];self.editable=YES;}return self;}
- (id)valueForProperty:(NSString *)key {return self.name;}
- (void)enumerateAssetsUsingBlock:(void (^)(ALAsset *,NSUInteger,BOOL *))block {
    BOOL stop=NO;NSUInteger i=0;for(ALAsset *asset in [self.assets copy]){block(asset,i++,&stop);if(stop)return;}block(nil,NSNotFound,&stop);
}
- (BOOL)addAsset:(ALAsset *)asset {self.adds++;if(!self.editable)return NO;if(!self.hideAdded)[self.assets addObject:asset];return YES;}
@end
@implementation ALAssetsLibrary
- (id)init {if((self=[super init]))self.groups=[NSMutableArray array];return self;}
- (void)enumerateGroupsWithTypes:(NSUInteger)type usingBlock:(void (^)(ALAssetsGroup *,BOOL *))block failureBlock:(void (^)(NSError *))failure {
    if(self.denied){failure([NSError errorWithDomain:@"denied" code:1 userInfo:nil]);return;}
    BOOL stop=NO;for(ALAssetsGroup *group in [self.groups copy]){block(group,&stop);if(stop)return;}block(nil,&stop);
}
- (void)addAssetsGroupAlbumWithName:(NSString *)name resultBlock:(void (^)(ALAssetsGroup *))result failureBlock:(void (^)(NSError *))failure {
    self.creates++;if(self.denied){failure([NSError errorWithDomain:@"denied" code:1 userInfo:nil]);return;}
    ALAssetsGroup *group=[ALAssetsGroup new];group.name=name;[self.groups addObject:group];result(self.collide?nil:group);
}
@end
static BOOL run(ALAsset *asset,ALAssetsLibrary *library) {
    __block BOOL done=NO,ok=NO;__block NSUInteger callbacks=0;
    [PhotoAlbum fileAsset:asset library:library completion:^(BOOL result){callbacks++;done=YES;ok=result;}];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while(!done && deadline.timeIntervalSinceNow>0)[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    NSCAssert(done && callbacks==1,@"Exactly one completion, including readback timeout");return ok;
}
int main(void) {@autoreleasepool {
    ALAsset *asset=[ALAsset new];asset.defaultRepresentation=[ALAssetRepresentation new];asset.defaultRepresentation.url=[NSURL URLWithString:@"assets-library://asset/asset.PNG?id=ONE&ext=PNG"];
    ALAssetsLibrary *library=[ALAssetsLibrary new];
    NSCAssert(run(asset,library),@"Create album and verify membership");
    ALAssetsGroup *group=library.groups[0];NSCAssert(library.creates==1 && group.adds==1 && [group.name isEqual:@"cophone"],@"Named album only");
    NSCAssert(run(asset,library) && library.creates==1 && group.adds==1,@"Checkpoint resume does not add another membership or create another album");
    group.editable=NO;NSCAssert(run(asset,library),@"Existing membership is valid even if album became read only");
    [group.assets removeAllObjects];NSCAssert(!run(asset,library) && group.adds==1,@"Read-only album cannot report success");
    group.editable=YES;group.hideAdded=YES;NSCAssert(!run(asset,library),@"Successful add without independent membership readback must fail");
    ALAssetsLibrary *collision=[ALAssetsLibrary new];collision.collide=YES;NSCAssert(run(asset,collision) && collision.creates==1,@"Nil creation result reuses concurrent named album");
    ALAssetsLibrary *denied=[ALAssetsLibrary new];denied.denied=YES;NSCAssert(!run(asset,denied),@"Permission denied must not report completed");
    NSLog(@"PhotoAlbum tests passed: creation, reuse, resume, collision, permission and independent membership verification");
}return 0;}
