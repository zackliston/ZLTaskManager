//
//  ZLInternalWorkItem.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMResultSet;

typedef NS_ENUM(NSInteger, ZLWorkItemState) {
    ZLWorkItemStateReady = 0,
    ZLWorkItemStateExecuting,
    ZLWorkItemStateHold
};


@interface ZLInternalWorkItem : NSObject

@property (nonatomic, assign) NSInteger recordID;
@property (nonatomic, strong) NSString *taskType;
@property (nonatomic, strong) NSString *taskID;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) ZLWorkItemState state;
@property (nonatomic, assign) NSInteger majorPriority;
@property (nonatomic, assign) NSInteger minorPriority;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) double timeCreated;
@property (nonatomic, assign) BOOL requiresInternet;
@property (nonatomic, strong) NSDictionary *jsonData;
@property (nonatomic, assign) NSInteger maxNumberOfRetries;
@property (nonatomic, assign) BOOL shouldHoldAfterMaxRetries;

- (id)initWithResultSet:(FMResultSet *)resultSet;

@end
