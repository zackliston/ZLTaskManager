ZLTaskManager
=============

There are many ways to dispatch work with Objective-C, from [Grand Central Dispatch](http://www.raywenderlich.com/60749/grand-central-dispatch-in-depth-part-1) to [NSOperations](http://nshipster.com/nsoperation/) however, none of these approaches handle persisting work. ZLTaskManager fills this void. With this library we can persist work from app launch to app launch. We can make sure this work is retried again and again until it succeeds (or until we decide to stop retrying it, more on this later). And thanks to this we can start work without adding endless failsafes to make sure that it is done correctly.  

###Usage
There are four main classes in ZLTaskManager
1: `ZLTaskManager` - Responsible for queueing, stopping, cancelling, restarting etc all work. <br>
2: `ZLTask` - How we specify and queue work on the `TaskManager`<br>
3: `ZLTaskWorker` - Where the actual work is done. You must provide the custom implementation of your work in a subclass of this. <br>
3: `ZLManager` - Responsible for `TaskWorkers`. The `TaskManager` will ask subclasses of this to create `TaskWorkers` based on the task type it is registered for. <br>

###Initializing 
`ZLTaskManager` is a shared instance and is initialized at the first call. It is recommended to initialize the `TaskManager` and register all available `ZLManager` subclasses on app launch, for example: 

```
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{
    ZLManagerSubclass *yourManager = [ZLManagerSubclass new];
    
    [ZLTaskManager sharedInstance] registerManager:yourManager forTaskType:@"your.task.type"];
}
```
**NOTE** A `ZLManager` can be registered for more than one task type BUT only one manager can be registered for each task type. 
