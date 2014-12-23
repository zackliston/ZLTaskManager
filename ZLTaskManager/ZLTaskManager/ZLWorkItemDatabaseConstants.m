//
//  ZLWorkItemDatabaseConstants.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLWorkItemDatabaseConstants.h"

NSString *const kZLWorkItemDatabaseLocation = @"workItemDatabase.db";
NSString *const kZLWorkItemDatabaseTableName = @"workQueueTable";

NSString *const kZLWorkItemIDColumnKey = @"id";
NSString *const kZLTaskTypeColumnKey = @"tasktype";
NSString *const kZLTaskIDColumnKey = @"taskid";

NSString *const kZLStateColumnKey = @"state";
NSString *const kZLDataColumnKey = @"data";
NSString *const kZLMajorPriorityColumnKey = @"majorpriority";
NSString *const kZLMinorPriorityColumnKey = @"minorpriority";
NSString *const kZLRetryCountColumnKey = @"retrycount";
NSString *const kZLTimeCreatedColumnKey = @"timecreated";
NSString *const kZLRequiresIntenetColumnKey = @"requiresinternet";

NSString *const kZLMaxNumberOfRetriesKey = @"maxnumberofretries";
NSString *const kZLShouldHoldAfterMaxRetriesKey = @"shouldholdaftermaxretries";

@implementation ZLWorkItemDatabaseConstants

@end
