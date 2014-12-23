//
//  ZLInternalWorkItem.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLInternalWorkItem.h"
#import "ZLWorkItemDatabaseConstants.h"
#import "FMResultSet.h"

@implementation ZLInternalWorkItem

@synthesize jsonData = _jsonData;

- (id)initWithResultSet:(FMResultSet *)resultSet
{
    self = [super init];
    if (self) {
        self.recordID = [resultSet intForColumn:kZLWorkItemIDColumnKey];
        self.taskType = [resultSet stringForColumn:kZLTaskTypeColumnKey];
        self.taskID = [resultSet stringForColumn:kZLTaskIDColumnKey];
        self.data = [resultSet dataForColumn:kZLDataColumnKey];
        self.state = [resultSet intForColumn:kZLStateColumnKey];
        self.minorPriority = [resultSet intForColumn:kZLMinorPriorityColumnKey];
        self.majorPriority = [resultSet intForColumn:kZLMajorPriorityColumnKey];
        self.retryCount = [resultSet intForColumn:kZLRetryCountColumnKey];
        self.timeCreated = [resultSet doubleForColumn:kZLTimeCreatedColumnKey];
        self.requiresInternet = [resultSet boolForColumn:kZLRequiresIntenetColumnKey];
        self.maxNumberOfRetries = [resultSet intForColumn:kZLMaxNumberOfRetriesKey];
        self.shouldHoldAfterMaxRetries = [resultSet boolForColumn:kZLShouldHoldAfterMaxRetriesKey];
    }
    return self;
}

- (NSDictionary *)jsonData
{
    if (!_data) {
        return nil;
    }
    
    if (!_jsonData) {
        NSError *error = nil;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:_data options:NSJSONReadingAllowFragments error:&error];
        if (error) {
            NSLog(@"Error parsing jsonData from data %@", error);
        }
        _jsonData = dictionary;
    }
    return _jsonData;
}

- (void)setJsonData:(NSDictionary *)jsonData
{
    if (!jsonData) {
        return;
    }
    
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonData options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        NSLog(@"Error parsing data from jsonData %@", error);
    } else {
        _data = data;
        _jsonData = jsonData;
    }
}

- (void)setData:(NSData *)data
{
    if (data != _data) {
        _data = data;
        _jsonData = nil;
    }
}

@end
