#import "TaskInbox.h"
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
#import <signal.h>
#import <sys/wait.h>
int main(int argc,char **argv){@autoreleasepool {
    if(argc==3){int held=CophoneAcquirePresence([NSString stringWithUTF8String:argv[2]]);char ready=held>=0;write(STDOUT_FILENO,&ready,1);close(STDOUT_FILENO);for(;;)pause();}

    NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    int presence=CophoneAcquirePresence(folder);NSCAssert(presence>=0,@"GUI acquires lifetime lock");
    NSString *session=CophoneAppSession(folder);NSCAssert(session.length,@"Live GUI session visible");
    NSError *error=nil;NSString *path=[folder stringByAppendingPathComponent:@"agent-request.json"];
    NSCAssert(!CophoneEnqueue(folder,@" ",@"summarize",@"safari-menu",&error),@"Empty selection cannot enqueue");
    NSCAssert(!CophoneEnqueue(folder,@"text",@"shell",@"safari-menu",&error),@"Only the two authorized tools");
    int fd=open([[folder stringByAppendingPathComponent:@"agent-submit.lock"] fileSystemRepresentation],O_CREAT|O_RDWR,0600);flock(fd,LOCK_EX);
    NSCAssert(!CophoneEnqueue(folder,@"first",@"summarize",@"safari-menu",&error),@"Other process holds submission lock");
    flock(fd,LOCK_UN);close(fd);
    NSCAssert(CophoneEnqueue(folder,@" first ",@"summarize",@"safari-menu",&error),@"First selection accepted");
    NSDictionary *first=CophoneTaskJSON(path);NSCAssert([first[@"snippet"] isEqual:@"first"] && [first[@"source"] isEqual:@"safari-menu"],@"Exact selection and entry point preserved");
    NSCAssert(!CophoneEnqueue(folder,@"second",@"illustrate",@"app",&error),@"Cannot replace in-flight Safari task from the App");
    NSCAssert([CophoneTaskJSON(path)[@"id"] isEqual:first[@"id"]],@"Rejected enqueue must not mutate active task");
    CophoneWriteTaskJSON(@{@"id":@"another",@"status":@"completed"},[folder stringByAppendingPathComponent:@"agent-receipt.json"]);
    NSCAssert(!CophoneEnqueue(folder,@"second",@"illustrate",@"app",&error),@"Unrelated completion cannot unlock task");
    CophoneWriteTaskJSON(@{@"id":first[@"id"],@"status":@"completed"},[folder stringByAppendingPathComponent:@"agent-receipt.json"]);
    NSCAssert(CophoneEnqueue(folder,@"second",@"illustrate",@"app",&error),@"Completed task permits another explicit choice");
    NSCAssert(![CophoneTaskJSON(path)[@"id"] isEqual:first[@"id"]],@"New task receives a fresh UUID");
    CophoneWriteTaskJSON(@{@"enabled":@YES},[folder stringByAppendingPathComponent:@"menu-settings.json"]);
    CophoneWriteTaskJSON(@{@"heartbeat":@([NSDate date].timeIntervalSince1970)},[folder stringByAppendingPathComponent:@"review-state.json"]);
    NSCAssert(CophoneMenuEnabled(folder),@"Menu requires explicit setting and live service");
    CophoneWriteTaskJSON(@{@"heartbeat":@([NSDate date].timeIntervalSince1970-20)},[folder stringByAppendingPathComponent:@"review-state.json"]);
    NSCAssert(!CophoneMenuEnabled(folder),@"Stale service cannot accept menu work");
    close(presence);
    NSCAssert(!CophoneAppSession(folder) && !CophoneMenuEnabled(folder),@"Stale marker cannot keep agent online");
    NSCAssert(!CophoneEnqueue(folder,@"offline",@"summarize",@"safari-menu",&error),@"Offline backend refuses new task");
    const char *helperFolder=folder.fileSystemRepresentation;
    int pipes[2];pipe(pipes);pid_t child=fork();
    if(child==0){close(pipes[0]);dup2(pipes[1],STDOUT_FILENO);close(pipes[1]);execl(argv[0],argv[0],"--presence-helper",helperFolder,NULL);_exit(127);}
    close(pipes[1]);char ready=0;read(pipes[0],&ready,1);close(pipes[0]);NSCAssert(ready,@"Child GUI acquired lock");
    NSString *childSession=CophoneAppSession(folder);NSCAssert(childSession && ![childSession isEqual:session],@"Relaunch creates a fresh session");
    NSCAssert(!CophoneTaskSessionActive(folder,first),@"Old task cannot transfer to new GUI session");
    kill(child,SIGSTOP);int status;waitpid(child,&status,WUNTRACED);
    NSCAssert(CophoneAppSession(folder),@"Ordinary suspension retains kernel lock");
    kill(child,SIGKILL);waitpid(child,&status,0);
    NSCAssert(!CophoneAppSession(folder),@"Force kill releases kernel lock without cleanup callback");
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];NSLog(@"TaskInbox tests passed: bounded input, serialization, active task protection, receipt identity, menu readiness");
}return 0;}
