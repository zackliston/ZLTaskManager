//
//  ZLWorkItemDatabaseConstants.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const kZLWorkItemDatabaseLocation;
FOUNDATION_EXPORT NSString *const kZLWorkItemDatabaseTableName;

FOUNDATION_EXPORT NSString *const kZLWorkItemIDColumnKey;
FOUNDATION_EXPORT NSString *const kZLTaskTypeColumnKey;
FOUNDATION_EXPORT NSString *const kZLTaskIDColumnKey;

FOUNDATION_EXPORT NSString *const kZLStateColumnKey;
FOUNDATION_EXPORT NSString *const kZLDataColumnKey;
FOUNDATION_EXPORT NSString *const kZLMajorPriorityColumnKey;
FOUNDATION_EXPORT NSString *const kZLMinorPriorityColumnKey;
FOUNDATION_EXPORT NSString *const kZLRetryCountColumnKey;
FOUNDATION_EXPORT NSString *const kZLTimeCreatedColumnKey;
FOUNDATION_EXPORT NSString *const kZLRequiresIntenetColumnKey;
FOUNDATION_EXPORT NSString *const kZLMaxNumberOfRetriesKey;
FOUNDATION_EXPORT NSString *const kZLShouldHoldAfterMaxRetriesKey;

@interface ZLWorkItemDatabaseConstants : NSObject

@end
