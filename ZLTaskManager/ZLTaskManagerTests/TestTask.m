//
//  TestTask.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZLTask.h"
@interface TestTask : XCTestCase

@end

@implementation TestTask

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInit
{
    ZLTask *task = [[ZLTask alloc] init];
    
    XCTAssertNil(task.taskType);
    XCTAssertNil(task.jsonData);
    XCTAssertEqual(task.majorPriority, kZLDefaultMajorPriority);
    XCTAssertEqual(task.minorPriority, kZLDefaultMinorPriority);
    XCTAssertFalse(task.requiresInternet);
    XCTAssertEqual(task.maxNumberOfRetries, kZLDefaultMaxRetryCount);
    XCTAssertFalse(task.shouldHoldAndRestartAfterMaxRetries);
}

- (void)testInitWithTaskTypeData
{
    NSString *taskType = @"taskTypeMan";
    NSDictionary *data = @{@"key":@"value1"};
    
    ZLTask *task = [[ZLTask alloc] initWithTaskType:taskType jsonData:data];
    
    XCTAssertTrue([task.taskType isEqualToString:taskType]);
    XCTAssertTrue([task.jsonData isEqualToDictionary:data]);
    XCTAssertEqual(task.majorPriority, kZLDefaultMajorPriority);
    XCTAssertEqual(task.minorPriority, kZLDefaultMinorPriority);
    XCTAssertFalse(task.requiresInternet);
    XCTAssertEqual(task.maxNumberOfRetries, kZLDefaultMaxRetryCount);
    XCTAssertFalse(task.shouldHoldAndRestartAfterMaxRetries);
}

@end
