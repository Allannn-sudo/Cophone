#import <Foundation/Foundation.h>
#if defined(COPHONE_ALBUM_TESTING)
#import "AlbumTestAssets.h"
#else
#import <AssetsLibrary/AssetsLibrary.h>
#endif

// Organizes an existing asset; never writes a second copy into Camera Roll.
@interface PhotoAlbum : NSObject
+ (void)fileAsset:(ALAsset *)asset library:(ALAssetsLibrary *)library completion:(void (^)(BOOL verified))completion;
@end
