#import <Foundation/Foundation.h>
NSDictionary *WriteReviewNote(NSString *identifier, NSString *text, NSError **error);
BOOL SendReviewNotification(NSError **error);

NSDictionary *WriteNamedNote(NSString *identifier,NSString *text,NSString *prefix,NSError **error);
BOOL SendTaskNotification(NSString *message,NSString *action,NSError **error);
BOOL SendTaskResultNotification(NSString *message,NSString *action,NSString *resultURL,NSError **error);
NSString *CophoneSavedNoteURL(NSString *identifier);

BOOL SendTaskProgressNotification(NSString *message,NSError **error);
