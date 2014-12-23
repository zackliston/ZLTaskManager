//
//  ZLTaskManager.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLTaskManager.h"
#import "ZLWorkItemDatabase.h"
#import "ZLInternalWorkItem.h"
#import "ZLTaskWorker.h"
#import "ZLManager.h"
#import "Reachability.h"


@interface ZLWorkItemDatabase (TestDestructor)

+ (void)resetForTest;

@end

static ZLTaskManager *_sharedTaskManager;
NSString *const kZLDumpStateWorkItemDatabaseKey = @"workItemDatabaseState";
NSString *const kZLActiveTaskQueueName = @"com.agilemd.taskWorker.activeTaskQueue";
NSInteger kZLMajorPriorityUserInitiated = 100000000;

NSTimeInterval const kScheduleWorkTimeInterval = 5.0;

@interface ZLTaskManager ()

@property (nonatomic, strong) NSOperationQueue *activeTaskQueue;
@property (nonatomic, strong) NSDictionary *managersForTypeDictionary;

@property (nonatomic, strong) NSTimer *workTimer;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) BOOL isWaitingForStopCompletion;

@property (nonatomic, strong) dispatch_queue_t serialQueue;

@property (nonatomic, strong) Reachability *reachability;

@end

static dispatch_once_t onceToken;

@implementation ZLTaskManager

#pragma mark - Initialization

- (id)init
{
    self = [super init];
    if (self) {
        [ZLWorkItemDatabase restartExecutingTasks];
        self.serialQueue = dispatch_queue_create("com.agilemd.sdk.taskManager.serialQueue", NULL);
        self.activeTaskQueue = [[NSOperationQueue alloc] init];
        self.activeTaskQueue.name = kZLActiveTaskQueueName;
        self.activeTaskQueue.maxConcurrentOperationCount = 4;
        
        self.isRunning = YES;
        self.isWaitingForStopCompletion = NO;
        self.reachability = [Reachability reachabilityForInternetConnection];
        [self.reachability startNotifier];
        
        __weak ZLTaskManager *weakSelf = self;
        self.reachability.reachableBlock = ^(Reachability *reach) {
            [weakSelf handleNetworkStatusChanged];
        };
        self.reachability.unreachableBlock = ^(Reachability *reach) {
            [weakSelf handleNetworkStatusChanged];
        };
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Getters/setters

- (NSDictionary *)managersForTypeDictionary
{
    if (!_managersForTypeDictionary) {
        _managersForTypeDictionary = [NSDictionary new];
    }
    return _managersForTypeDictionary;
}

- (void)setIsWaitingForStopCompletion:(BOOL)isWaitingForStopCompletion
{
    _isWaitingForStopCompletion = isWaitingForStopCompletion;
    
    if (!_isWaitingForStopCompletion && self.isRunning) {
#ifdef TEST
        [self scheduleMoreWork];
#else
        dispatch_async(self.serialQueue, ^{
            [self scheduleMoreWork];
        });
#endif
    }
}

#pragma mark - Public Methods

+ (ZLTaskManager *)sharedInstance
{
    dispatch_once(&onceToken, ^{
        if (!_sharedTaskManager) {
            _sharedTaskManager = [[ZLTaskManager alloc] init];
        }
    });
    return _sharedTaskManager;
}

#pragma mark Running

- (void)stopWithCompletionHandler:(void (^)(void))completionBlock
{
    dispatch_sync(self.serialQueue, ^{
        self.isRunning = NO;
        self.isWaitingForStopCompletion = YES;
        [self.activeTaskQueue cancelAllOperations];
#warning fix
        //[[ADNetworkManager sharedInstance] cancelAllTasks];
        
        __block ZLTaskManager *weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [weakSelf.activeTaskQueue waitUntilAllOperationsAreFinished];
            weakSelf.isWaitingForStopCompletion = NO;
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        });
    });
}

- (void)stopAndWait
{
    self.isRunning = NO;
    self.isWaitingForStopCompletion = YES;
    dispatch_sync(self.serialQueue, ^{
        [self.activeTaskQueue cancelAllOperations];
#warning fix
       // [[ADNetworkManager sharedInstance] cancelAllTasks];
        
        [self.activeTaskQueue waitUntilAllOperationsAreFinished];
        self.isWaitingForStopCompletion = NO;
    });
}

- (void)resume
{
#ifdef TEST
    dispatch_sync(self.serialQueue, ^{
#else
    dispatch_async(self.serialQueue, ^{
#endif
        self.isRunning = YES;
        [self scheduleMoreWork];
    });
}
                  
#pragma mark Queue Tasks

- (BOOL)queueTask:(ZLTask *)task
{
    if (self.isWaitingForStopCompletion || (!task.taskType || task.taskType.length<1)) {
        return NO;
    }
    
    __block BOOL success;
    dispatch_sync(self.serialQueue, ^{
        ZLInternalWorkItem *newWorkItem = [[ZLInternalWorkItem alloc] init];
        newWorkItem.taskType = task.taskType;
        newWorkItem.majorPriority = task.majorPriority;
        newWorkItem.minorPriority = task.minorPriority;
        newWorkItem.jsonData = task.jsonData;
        newWorkItem.state = ZLWorkItemStateReady;
        newWorkItem.retryCount = 0;
        newWorkItem.requiresInternet = task.requiresInternet;
        newWorkItem.timeCreated = [[NSDate new] timeIntervalSince1970];
        newWorkItem.maxNumberOfRetries = task.maxNumberOfRetries;
        newWorkItem.shouldHoldAfterMaxRetries = task.shouldHoldAndRestartAfterMaxRetries;
        
        success = [ZLWorkItemDatabase addNewWorkItem:newWorkItem];
        if (success) {
            [self scheduleMoreWork];
        }
    });
    return success;
}

#pragma mark Manipulate WorkItem Database

- (void)removeTasksOfType:(NSString *)taskType
{
    dispatch_sync(self.serialQueue, ^{
        [ZLWorkItemDatabase deleteWorkItemsWithTaskType:taskType];
    });
}

- (void)changePriorityOfTasksOfType:(NSString *)typeToChange newMajorPriority:(NSInteger)newMajorPriority
{
    dispatch_sync(self.serialQueue, ^{
        [ZLWorkItemDatabase changePriorityOfTaskType:typeToChange newMajorPriority:newMajorPriority];
    });
}

- (NSInteger)countOfTasksOfType:(NSString *)typeToCount
{
    __block NSInteger count;
    dispatch_sync(self.serialQueue, ^{
        count = [ZLWorkItemDatabase countOfWorkItemsWithTaskType:typeToCount];
    });
    
    return count;
}

- (NSInteger)countOfTasksNotHolding
{
    __block NSInteger count;
    dispatch_sync(self.serialQueue, ^{
        count = [ZLWorkItemDatabase countOfWorkItemsNotHolding];
    });
    
    return count;
}

- (void)restartHoldingTasks
{
    dispatch_sync(self.serialQueue, ^{
        [ZLWorkItemDatabase restartHoldingTasks];
    });
}

#pragma mark - Registration

- (void)registerManager:(ZLManager *)manager forTaskType:(NSString *)taskType
{
    dispatch_sync(self.serialQueue, ^{
        ZLManager *existingManager = [self.managersForTypeDictionary objectForKey:taskType];
        if (existingManager && ![existingManager isEqual:manager]) {
            [NSException raise:NSInternalInconsistencyException format:@"A manager is already registered for taskType %@ you can not add a second manager for the same type.", taskType];
        }
        
        NSMutableDictionary *mutableManagers = [self.managersForTypeDictionary mutableCopy];
        [mutableManagers setObject:manager forKey:taskType];
        self.managersForTypeDictionary = [mutableManagers copy];
    });
}

- (void)removeRegisteredManagerForAllTaskTypes:(ZLManager *)manager
{
    dispatch_sync(self.serialQueue, ^{
        NSMutableDictionary *mutableManagers = [self.managersForTypeDictionary mutableCopy];
        
        NSMutableArray *keysToRemove = [NSMutableArray new];
        for (NSString *key in mutableManagers.allKeys) {
            ZLManager *managerForKey = [mutableManagers objectForKey:key];
            if ([managerForKey isEqual:manager]) {
                [keysToRemove addObject:key];
            }
        }
        
        for (NSString *key in keysToRemove) {
            [mutableManagers removeObjectForKey:key];
        }
        
        self.managersForTypeDictionary = [mutableManagers copy];
    });
}

#pragma mark Get State

- (NSDictionary *)dumpState
{
    __block NSMutableDictionary *mutableState = [NSMutableDictionary new];
    
    dispatch_sync(self.serialQueue, ^{
        NSArray *workItemDatabaseState = [ZLWorkItemDatabase getDatabaseState];
        
        [mutableState setObject:workItemDatabaseState forKey:kZLDumpStateWorkItemDatabaseKey];
    });
    
    return [mutableState copy];
}

#pragma mark - Private Methods
#pragma mark Managing Work

- (void)scheduleMoreWork
{
    [self.workTimer invalidate];
    
    BOOL stop = (self.activeTaskQueue.operationCount >= self.activeTaskQueue.maxConcurrentOperationCount);
    while (!stop) {
        stop = ![self createAndQueueNextTaskWorker];
        
        if (self.activeTaskQueue.operationCount >= self.activeTaskQueue.maxConcurrentOperationCount) {
            stop = YES;
        }
    }
    self.workTimer = [NSTimer scheduledTimerWithTimeInterval:kScheduleWorkTimeInterval target:self selector:@selector(scheduleMoreWork) userInfo:nil repeats:YES];
}

- (BOOL)createAndQueueNextTaskWorker
{
    if (!self.isRunning || self.isWaitingForStopCompletion) {
        return NO;
    }
    
    BOOL isReachable = self.reachability.isReachable;
    ZLInternalWorkItem *nextWorkItem = nil;
    
    if (!isReachable) {
        nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:self.managersForTypeDictionary.allKeys];
    } else {
        nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:self.managersForTypeDictionary.allKeys];
    }
    
    if (!nextWorkItem) {
        return NO;
    }
    
    nextWorkItem.state = ZLWorkItemStateExecuting;
    [ZLWorkItemDatabase updateWorkItem:nextWorkItem];
    
    ZLManager *manager = [self.managersForTypeDictionary objectForKey:nextWorkItem.taskType];
    ZLTaskWorker *taskWorker = [manager taskWorkerForWorkItem:nextWorkItem];
    [taskWorker setTaskFinishedDelegate:self];
    
    
    [self.activeTaskQueue addOperation:taskWorker];
    
    return YES;
}

#pragma mark - TaskWorkerFinished Delegate

- (void)taskWorker:(ZLTaskWorker *)taskWorker finishedSuccessfully:(BOOL)wasSuccessful
{
    dispatch_async(self.serialQueue, ^{
        if (wasSuccessful) {
            [ZLWorkItemDatabase deleteWorkItem:taskWorker.workItem];
        } else {
            ZLInternalWorkItem *workItem = taskWorker.workItem;
            workItem.retryCount = workItem.retryCount+1;
            
            if (workItem.retryCount >= workItem.maxNumberOfRetries) {
                ZLManager *manager = [self.managersForTypeDictionary objectForKey:workItem.taskType];
                [manager workItemDidFail:workItem];
                
                if (workItem.shouldHoldAfterMaxRetries) {
                    workItem.state = ZLWorkItemStateHold;
                    [ZLWorkItemDatabase updateWorkItem:workItem];
                } else {
                    [ZLWorkItemDatabase deleteWorkItem:workItem];
                }
            } else {
                workItem.state = ZLWorkItemStateReady;
                [ZLWorkItemDatabase updateWorkItem:workItem];
            }
        }
        
        [self scheduleMoreWork];
    });
}

- (void)handleNetworkStatusChanged
{
    dispatch_async(self.serialQueue, ^{
        [self scheduleMoreWork];
    });
}


#pragma mark - Testing Helper

+ (void)tearDownForTest
{
    [ZLWorkItemDatabase resetForTest];
    onceToken = 0;
    _sharedTaskManager = nil;
}
@end
