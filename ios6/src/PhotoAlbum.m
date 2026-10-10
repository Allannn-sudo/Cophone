#import "PhotoAlbum.h"
#import <dispatch/dispatch.h>

@implementation PhotoAlbum
+ (BOOL)group:(ALAssetsGroup *)group containsURL:(NSURL *)url {
    if(!url)return NO;
    __block BOOL found=NO;
    [group enumerateAssetsUsingBlock:^(ALAsset *item,NSUInteger index,BOOL *stop) {
        if([item.defaultRepresentation.url isEqual:url]){found=YES;*stop=YES;}
    }];
    return found;
}
+ (void)checkGroup:(ALAssetsGroup *)group url:(NSURL *)url attempts:(NSUInteger)attempts completion:(void (^)(BOOL))completion {
    if([self group:group containsURL:url]){completion(YES);return;}
    if(!attempts){completion(NO);return;}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        [self checkGroup:group url:url attempts:attempts-1 completion:completion];
    });
}
+ (void)addAsset:(ALAsset *)asset group:(ALAssetsGroup *)group completion:(void (^)(BOOL))completion {
    NSURL *url=asset.defaultRepresentation.url;
    if([self group:group containsURL:url]){completion(YES);return;}
    if(!url || !group.isEditable || ![group addAsset:asset]){completion(NO);return;}
    // A successful add is not proof that the album contains the asset.
    [self checkGroup:group url:url attempts:3 completion:completion];
}
+ (void)findInLibrary:(ALAssetsLibrary *)library completion:(void (^)(ALAssetsGroup *))completion {
    __block BOOL resolved=NO;
    [library enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group,BOOL *stop) {
        if(resolved)return;
        if(!group || [[group valueForProperty:ALAssetsGroupPropertyName] isEqual:@"cophone"]) {
            resolved=YES;if(group)*stop=YES;completion(group);
        }
    } failureBlock:^(NSError *error) {if(!resolved){resolved=YES;completion(nil);}}];
}
+ (void)fileAsset:(ALAsset *)asset library:(ALAssetsLibrary *)library completion:(void (^)(BOOL))completion {
    __weak ALAssetsLibrary *weakLibrary=library;
    [self findInLibrary:library completion:^(ALAssetsGroup *group) {
        if(group){[self addAsset:asset group:group completion:completion];return;}
        [library addAssetsGroupAlbumWithName:@"cophone" resultBlock:^(ALAssetsGroup *created) {
            if(created){[self addAsset:asset group:created completion:completion];return;}
            // iOS can return nil on a name collision; look up once, do not create duplicates.
            [self findInLibrary:weakLibrary completion:^(ALAssetsGroup *existing) {
                if(existing)[self addAsset:asset group:existing completion:completion];else completion(NO);
            }];
        } failureBlock:^(NSError *error) {completion(NO);}];
    }];
}
@end
