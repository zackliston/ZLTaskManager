//
//  ZLTask.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSInteger const kZLDefaultMaxRetryCount;
FOUNDATION_EXPORT NSInteger const kZLDefaultMajorPriority;
FOUNDATION_EXPORT NSInteger const kZLDefaultMinorPriority;

@interface ZLTask : NSObject

@property (nonatomic, strong) NSString *taskType;
@property (nonatomic, strong) NSDictionary *jsonData;
@property (nonatomic, assign) NSInteger majorPriority;
@property (nonatomic, assign) NSInteger minorPriority;
@property (nonatomic, assign) BOOL requiresInternet;
@property (nonatomic, assign) NSInteger maxNumberOfRetries;
@property (nonatomic, assign) BOOL shouldHoldAndRestartAfterMaxRetries;

- (id)initWithTaskType:(NSString *)taskType jsonData:(NSDictionary *)jsonData;

@end

