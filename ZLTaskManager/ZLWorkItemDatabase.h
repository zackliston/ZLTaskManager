//
//  ZLWorkItemDatabase.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZLInternalWorkItem.h"

@interface ZLWorkItemDatabase : NSObject

+ (ZLInternalWorkItem *)getNextWorkItemForTaskTypes:(NSArray *)types;
+ (ZLInternalWorkItem *)getNextWorkItemForNoInternetForTaskTypes:(NSArray *)types;

+ (BOOL)addNewWorkItem:(ZLInternalWorkItem *)workItem;
+ (BOOL)updateWorkItem:(ZLInternalWorkItem *)workItem;
+ (void)deleteWorkItem:(ZLInternalWorkItem *)workItem;

+ (void)deleteWorkItemsWithTaskType:(NSString *)taskType;
+ (void)changePriorityOfTaskType:(NSString *)taskType newMajorPriority:(NSInteger)newMajorPriority;
+ (void)restartHoldingTasks;
+ (void)restartExecutingTasks;

+ (NSInteger)countOfWorkItemsWithTaskType:(NSString *)taskType;
+ (NSInteger)countOfWorkItemsNotHolding;

+ (void)resetDatabase;
+ (NSArray *)getDatabaseState;

@end
