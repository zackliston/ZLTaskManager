//
//  ZLTaskManager.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZLTaskFinishedProtocol.h"
#import "ZLTask.h"

@class ZLInternalWorkItem;
@class ZLManager;

// In this header, you should import all the public headers of your framework using statements like #import <ZLTaskManager/PublicHeader.h>

@interface ZLTaskManager : NSObject <ZLTaskFinishedProtocol>

+ (ZLTaskManager *)sharedInstance;

#pragma mark - Running
- (void)stopWithNetworkCancellationBlock:(void (^)(void))networkCancellationBlock completionHandler:(void (^)(void))completionBlock;
- (void)stopAndWaitWithNetworkCancellationBlock:(void (^)(void))networkCancellationBlock;
- (void)resume;

#pragma mark - Task Queueing
- (BOOL)queueTask:(ZLTask *)task;

#pragma mark - Task Methods
- (void)removeTasksOfType:(NSString *)taskType;
- (void)changePriorityOfTasksOfType:(NSString *)typeToChange newMajorPriority:(NSInteger)newMajorPriority;
- (NSInteger)countOfTasksOfType:(NSString *)typeToCount;
- (NSInteger)countOfTasksNotHolding;

- (void)restartHoldingTasks;

#pragma mark - Registration
- (void)registerManager:(ZLManager *)manager forTaskType:(NSString *)taskType;
- (void)removeRegisteredManagerForAllTaskTypes:(ZLManager *)manager;

#pragma mark - Debug Methods
- (NSDictionary *)dumpState;
@end
