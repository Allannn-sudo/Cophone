#import <Foundation/Foundation.h>
NSString *ReviewCompactText(id value,NSUInteger limit);
NSString *ReviewHTMLExcerpt(NSData *data);
NSDictionary *ReviewVideoMetadata(NSData *data);
NSArray *ReviewCachedVideos(NSArray *paths);
NSString *ReviewCachedPage(NSString *database,NSString *url);
