// Read one system library for local ABI inspection; no user data or UI actions.
#import <Foundation/Foundation.h>
int main(){@autoreleasepool{NSData *d=[NSData dataWithContentsOfFile:@"/System/Library/BulletinBoardPlugins/PushDataProviderFactory.bundle/PushDataProviderFactory"];if(!d.length || d.length>512*1024)return 2;const unsigned char *p=d.bytes;for(NSUInteger i=0;i<d.length;i++)printf("%02x",p[i]);puts("");}return 0;}
