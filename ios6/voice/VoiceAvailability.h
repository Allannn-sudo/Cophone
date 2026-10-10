#import <Foundation/Foundation.h>

// Main-thread gesture handling reads a completed snapshot only. It must never
// wait for SpringBoard IPC, HTTP, or CoreTelephony to answer.
static inline BOOL CophoneVoiceSnapshotReady(BOOL hooked, BOOL hasSession,
                                           BOOL screenUnlocked, BOOL noCall,
                                           NSTimeInterval sampledAt,
                                           NSTimeInterval now) {
    return hooked && hasSession && screenUnlocked && noCall && sampledAt > 0
        && now >= sampledAt && now - sampledAt < 2.5;
}
