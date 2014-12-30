ZLTaskManager
=============

There are many ways to dispatch work with Objective-C, from [Grand Central Dispatch](http://www.raywenderlich.com/60749/grand-central-dispatch-in-depth-part-1) to [NSOperations](http://nshipster.com/nsoperation/) however, none of these approaches handle persisting work. ZLTaskManager fills this void. With this library we can persist work from app launch to app launch. We can make sure this work is retried again and again until it succeeds (or until we decide to stop retrying it, more on this later). And thanks to this we can start work without adding endless failsafes to make sure that it is done correctly.  

##Getting Starting
###Installation
####Cocoapods
CocoaPods is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like AFNetworking in your projects. See the "Getting Started" guide for more information.

Podfile
```
platform :ios, '7.1'
pod `ZLTaskManager`, "~> 0.0"
```

##Usage
There are four main classes in ZLTaskManager<br>
1: `ZLTaskManager` - Responsible for queueing, stopping, cancelling, restarting etc all work. <br>
2: `ZLTask` - How we specify and queue work on the `TaskManager`<br>
3: `ZLTaskWorker` - Where the actual work is done. You must provide the custom implementation of your work in a subclass of this. <br>
3: `ZLManager` - Responsible for `TaskWorkers`. The `TaskManager` will ask subclasses of this to create `TaskWorkers` based on the task type it is registered for. <br>

###Initializing 
`ZLTaskManager` is a shared instance and is initialized at the first call. It is recommended to initialize the `TaskManager` and register all available `ZLManager` subclasses on app launch, for example: 

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions 
{
    ZLManagerSubclass *yourManager = [ZLManagerSubclass new];
    
    [ZLTaskManager sharedInstance] registerManager:yourManager forTaskType:@"your.task.type"];
}
```
Once a manager is registered for a certain task type the `TaskManager` will automatically start any work for that task type that has been queued and not completed. 

**NOTE** A `ZLManager` can be registered for more than one task type BUT only one manager can be registered for each task type. 

###Queueing work
Work is specified in the form of `ZLTasks` which are then queued on the `TaskManager`. A `ZLTask` is a way for you to specify everything about the task, from the priority, to its internet requirement to the number of times it should be retried if it fails (can be infinite). However, there are two most important pieces of information:<br>

* `taskType` - This is a string that defines what kind of task it is. It is used by the `TaskManager` to determine what `ZLManager` and `ZLTaskWorker` subclass to use for this task. <br>
* `jsonData` - This is a json compatible NSDictionary (only NSNumbers, NSString, NSArray and other NSDictionaries). You use this to pass any information necessary for completing the work. You will program your `ZLTaskWorker` subclass to understand this dictionary and pull the information out of it appropriately. <br>

This is how you create and queue work:<br>
```objective-c
    // This should be a constant defined somewhere.
    NSString *taskType = @"test.task.type";
    
    NSDictionary *jsonData = @{@"urlToFetch":@"www.example.com/fetch", @"urlToPost":@"www.example.com/post", @"someNumber":@1, @"someParameters":@[@"one", @"two",@"three"]}
    
    ZLTask *task = [[ZLTask alloc] initWithTaskType:taskType jsonData:jsonData];
    task.requiresInternet = YES;
    task.majorPriority = 10000;
    
    [[ZLTaskManager sharedInstance] queueTask:task];
```

###Executing Work
All work is done inside your subclasses of `ZLTaskWorker`. To understand how to implement your `TaskWorker` visit [this page](https://github.com/zackliston/ZLTaskManager/wiki/ZLTaskWorker).<br>
<br>
Your `TaskWorker` is created by your subclass of `ZLManager` that is registered for that task type. You **must** override the `taskWorkerForWorkItem:` method in your `Manager` class. Example below:

``` objective-c
- (ZLTaskWorker *)taskWorkerForWorkItem:(ZLInternalWorkItem *)workItem
{
    //This should be defined as a constant somewhere
    NSString *taskType = @"test.task.type";
    
    ZLTaskWorker *taskWorker;
    
    if ([workItem.taskType isEqualToString:taskType]) {
        taskWorker = [ZLTaskWorkerSubclass new];
    } else if ([workItem.taskType isEqualToString:@"otherTaskTypeManagerHandles"]) {
        taskWorker = [ZLOtherTaskWorkerSubclass new];
    } else 
        // If your Manager is registered for a task type you MUST handle it. This line of code should never execute
        // if you are implementing this correctly. It is recommended to log here in case this happens so you 
        // know what's going wrong.
        NSLog(@"Manager is not handling task type %@", workItem.taskType);
    }
    
    // Required
    [taskWorker setupWithWorkItem:workItem];
    return taskWorker;
}
```

###Stopping and backgrounding
In order to keep the iOS from killing our processes while they're running when the application is about to terminate (plus your own app specific needs), we must stop our work. There are two ways to do this, asynchonously or synchronously. Please review [this page]() for more details. You must implement the below code in your `applicationWillTerminate` method in your app delegate:<br>

```objective-c
- (void)applicationWillTerminate:(UIApplication *)application
{
    // This is a synchronous method. 
    [[ZLTaskManager sharedInstance] stopAndWaitWithNetworkCancellationBlock:^{
        // Cancel any network tasks your task workers may be using so that the cancellation process
        // is not waiting on them to finish. 
    }];
}
```

####Backgrounding disabled
If you decide to not enable backgrounding then you must stop your work everytime your app enters the background and resume it everytime it enters the for ground, as showed below:<br>

```objective-c
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // This is a synchronous method. 
    [[ZLTaskManager sharedInstance] stopAndWaitWithNetworkCancellationBlock:^{
        // Cancel any network tasks your task workers may be using so that the cancellation process
        // is not waiting on them to finish. 
    }];
}
```

```objective-c
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [ZLTaskManager sharedInstance] resume];
}
```

####Backgrounding enabled
If you decide to enable backgrounding for `ZLTaskManager` in your application then you must start a background task everytime your app enters the background and make sure it starts up again everytime your application becomes active: 
```objective-c
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]) {
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            __block UIBackgroundTaskIdentifier backgroundTask;
            backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
                [[ADTaskManager sharedInstance] stopAndWait];
               
                NSLog(@"ZLTaskManager background tasks ran out of time. Stopping");
                [application endBackgroundTask:backgroundTask];
                backgroundTask = UIBackgroundTaskInvalid;
            }];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                //This is a blocking method. It shouldn't be called anywhere but in this context
                [ZLTaskManager waitForTasksToFinishOnSharedInstance];
                
                NSLog(@"ZLTaskManager finished background tasks");
                [application endBackgroundTask:backgroundTask];
                backgroundTask = UIBackgroundTaskInvalid;
            });
        }
    }
}
```
```objective-c
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [ZLTaskManager sharedInstance] resume];
}
```
