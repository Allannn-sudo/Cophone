#import <UIKit/UIKit.h>
#import <objc/runtime.h>
int main(void){@autoreleasepool {
    for(NSString *name in @[@"UIWebDocumentView",@"UIWebBrowserView",@"UIWebView",@"WebView",@"WebFrame"]) {
        Class c=NSClassFromString(name);printf("CLASS %s %s\n",name.UTF8String,c?"present":"absent");
        unsigned int count=0;Method *methods=class_copyMethodList(c,&count);
        for(unsigned int i=0;i<count;i++) {
            NSString *s=NSStringFromSelector(method_getName(methods[i]));
            if([s.lowercaseString rangeOfString:@"select"].location!=NSNotFound || [s rangeOfString:@"JavaScript"].location!=NSNotFound || [s isEqual:@"canPerformAction:withSender:"])
                printf("METHOD %s %s %s\n",name.UTF8String,s.UTF8String,method_getTypeEncoding(methods[i]));
        }free(methods);
    }
}return 0;}
