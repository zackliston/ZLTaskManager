//
//  TestInternalWorkItem.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "OCMock.h"
#import "ZLInternalWorkItem.h"
#import "FMResultSet.h"
#import "ZLWorkItemDatabaseConstants.h"


@interface TestInternalWorkItem : XCTestCase

@end

@implementation TestInternalWorkItem

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testInitWithValidResultSet
{
    int fakeRecordID = 1;
    NSString *fakeTaskType = @"faketasktyp";
    NSString *fakeTaskID = @"12kkoskksl";
    NSData *fakeData = [@"1234" dataUsingEncoding:NSUTF8StringEncoding];
    int fakeState = 33;
    int fakeMinorPriority = 2;
    int fakeMajorPriority = 8;
    int fakeRetryCount = 21;
    double fakeTimeCreated = 9384382;
    BOOL fakeRequiresInternet = YES;
    
    int maxNumberOfRetries = 32;
    BOOL shouldHoldAfterMaxRetries = YES;
    
    id mockResultSet = OCMClassMock([FMResultSet class]);
    
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(fakeRecordID)] intForColumn:kZLWorkItemIDColumnKey];
    [[[mockResultSet stub] andReturn:fakeTaskType] stringForColumn:kZLTaskTypeColumnKey];
    [[[mockResultSet stub] andReturn:fakeTaskID] stringForColumn:kZLTaskIDColumnKey];
    [[[mockResultSet stub] andReturn:fakeData] dataForColumn:kZLDataColumnKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(fakeState)] intForColumn:kZLStateColumnKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(fakeMinorPriority)] intForColumn:kZLMinorPriorityColumnKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(fakeMajorPriority)] intForColumn:kZLMajorPriorityColumnKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(fakeRetryCount)] intForColumn:kZLRetryCountColumnKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(fakeTimeCreated)] doubleForColumn:kZLTimeCreatedColumnKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(fakeRequiresInternet)] boolForColumn:kZLRequiresIntenetColumnKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(maxNumberOfRetries)] intForColumn:kZLMaxNumberOfRetriesKey];
    [[[mockResultSet stub] andReturnValue:OCMOCK_VALUE(shouldHoldAfterMaxRetries)] boolForColumn:kZLShouldHoldAfterMaxRetriesKey];
    
    ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] initWithResultSet:mockResultSet];
    
    
    XCTAssertEqual(fakeRecordID, workItem.recordID, @"The workItem.recordID %li should equal the value for the ID column in the result set %lu", (long)workItem.recordID, (unsigned long)fakeRecordID);
    XCTAssertTrue([fakeTaskType  isEqualToString:workItem.taskType], @"The workItem.taskType %@ should equal the value for the taskType column in the result set %@", workItem.taskType, fakeTaskType);
    XCTAssertTrue([fakeTaskID isEqualToString:workItem.taskID], @"The workItem.taskID %@ should equal the value for the taskID column in the result set %@", workItem.taskID, fakeTaskID);
    XCTAssertEqual(fakeData, workItem.data, @"The workItem.data should equal the value for the data column in the result set");
    XCTAssertEqual(fakeState, workItem.state, @"The workItem.state %i should equal the value for the state column in the result set %i", (int)workItem.state, fakeState);
    XCTAssertEqual(fakeMinorPriority, workItem.minorPriority, @"The workItem.minorPriority %li should equal the value for the minorPriority column in the result set %i", (long)workItem.minorPriority, fakeMinorPriority);
    XCTAssertEqual(fakeMajorPriority, workItem.majorPriority, @"The workItem.majorPriority %li should equal the value for the majorPriority column in the result set %i", (long)workItem.majorPriority, fakeMajorPriority);
    XCTAssertEqual(fakeRetryCount, workItem.retryCount, @"The workItem.retryCount %li should equal the value for the retryCount column in the result set %i", (long)workItem.retryCount, fakeRetryCount);
    XCTAssertEqual(fakeTimeCreated, workItem.timeCreated, @"The workItem.timeCreated %f should equal the value for the timeCreated column in the result set %f", workItem.timeCreated, fakeTimeCreated);
    XCTAssertEqual(fakeRequiresInternet, workItem.requiresInternet, @"The workItem.requiresInternet should equal the value for the requiresInternet column in the result set");
    XCTAssertEqual(maxNumberOfRetries, workItem.maxNumberOfRetries);
    XCTAssertEqual(shouldHoldAfterMaxRetries, workItem.shouldHoldAfterMaxRetries);
}

- (void)testGetJsonData
{
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    NSDictionary *testJSON = @{@"Keya":@"valueA", @"KeyB":@"ValueB"};
    NSData *testData = [NSJSONSerialization dataWithJSONObject:testJSON options:NSJSONWritingPrettyPrinted error:nil];
    
    workItem.data = testData;
    
    XCTAssertTrue([testJSON isEqualToDictionary:workItem.jsonData], @"The workItem.jsonData should be the same as the original testData that we created.");
}

- (void)testGetJsonDataNoData
{
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    XCTAssertNil(workItem.jsonData, @"Since we don't have any data this shoud be nil but it is %@", workItem.jsonData);
}

- (void)testSetJsonData
{
    ZLInternalWorkItem *workItem = [ZLInternalWorkItem new];
    NSDictionary *json = @{@"key":@"value", @"key2":@"value2"};
    
    workItem.jsonData = json;
    
    XCTAssertTrue([json isEqualToDictionary:workItem.jsonData]);
}

@end
