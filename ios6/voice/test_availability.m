#import <Foundation/Foundation.h>
#import "VoiceAvailability.h"
static unsigned checks;
static void check(BOOL ok, const char *name){checks++;if(!ok){fprintf(stderr,"FAILED %s\n",name);exit(1);}}
int main(){@autoreleasepool {
 check(CophoneVoiceSnapshotReady(YES,YES,YES,YES,100,100.75),"fresh online unlocked snapshot");
 check(!CophoneVoiceSnapshotReady(NO,YES,YES,YES,100,100.75),"unhooked fallback");
 check(!CophoneVoiceSnapshotReady(YES,NO,YES,YES,100,100.75),"offline fallback");
 check(!CophoneVoiceSnapshotReady(YES,YES,NO,YES,100,100.75),"locked fallback");
 check(!CophoneVoiceSnapshotReady(YES,YES,YES,NO,100,100.75),"call fallback");
 check(!CophoneVoiceSnapshotReady(YES,YES,YES,YES,0,0),"uninitialized fallback");
 check(!CophoneVoiceSnapshotReady(YES,YES,YES,YES,100,99),"future timestamp rejected");
 check(!CophoneVoiceSnapshotReady(YES,YES,YES,YES,100,102.5),"hung sampler expires without blocking caller");
 check(CophoneVoiceSnapshotReady(YES,YES,YES,YES,200,200),"fresh sample restores readiness");
 // Repeated gesture/timer reads must remain finite even if no new sample ever
 // arrives. No SpringBoard or network access occurs in this production helper.
 unsigned ready=0;for(unsigned i=0;i<100000;i++)ready+=CophoneVoiceSnapshotReady(YES,YES,YES,YES,100,100+i/1000.0);
 check(ready==2500,"stalled sampler never keeps entry online indefinitely");
 printf("%u voice availability checks passed\n",checks);
}return 0;}
