//
//  ZLTask.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLTask.h"

NSInteger const kZLDefaultMaxRetryCount = 3;
NSInteger const kZLDefaultMajorPriority = 10;
NSInteger const kZLDefaultMinorPriority = 10;

@implementation ZLTask

- (id)init
{
    self = [super init];
    if (self) {
        self.majorPriority = kZLDefaultMajorPriority;
        self.minorPriority = kZLDefaultMinorPriority;
        self.requiresInternet = NO;
        self.maxNumberOfRetries = kZLDefaultMaxRetryCount;
        self.shouldHoldAndRestartAfterMaxRetries = NO;
    }
    return self;
}

- (id)initWithTaskType:(NSString *)taskType jsonData:(NSDictionary *)jsonData
{
    self = [self init];
    if (self) {
        self.taskType = taskType;
        self.jsonData = jsonData;
    }
    return self;
}

@end