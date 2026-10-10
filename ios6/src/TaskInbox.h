#import <Foundation/Foundation.h>
NSString *CophoneDocuments(void);
NSDictionary *CophoneTaskJSON(NSString *path);
BOOL CophoneWriteTaskJSON(NSDictionary *value,NSString *path);
BOOL CophoneMenuEnabled(NSString *documents);
// One serialized inbox shared by the App and Safari. No key is read here.
BOOL CophoneEnqueue(NSString *documents,NSString *snippet,NSString *action,NSString *source,NSError **error);

// GUI holds this kernel lock even while suspended; process death releases it.
int CophoneAcquirePresence(NSString *documents);
NSString *CophoneAppSession(NSString *documents);
BOOL CophoneTaskSessionActive(NSString *documents,NSDictionary *request);
