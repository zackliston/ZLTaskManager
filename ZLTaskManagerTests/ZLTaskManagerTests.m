//
//  ZLTaskManagerTests.m
//  ZLTaskManagerTests
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZLTaskManager.h"
#import "ZLWorkItemDatabase.h"
#import "OCMock.h"
#import "ZLTaskFinishedProtocol.h"
#import "ZLManager.h"
#import "ZLTaskManager.h"
#import "ZLTask.h"
#import "ZLTestConcurrnetTaskWorker.h"
#import "Reachability.h"

NSString *const kDumpStateWorkItemDatabaseKeyTEST = @"workItemDatabaseState";
NSString *const kActiveTaskQueueNameTEST = @"com.agilemd.taskWorker.activeTaskQueue";
NSInteger const kMaxNumberOfRetriesTEST = 3;
NSTimeInterval const kScheduleWorkTimeIntervalTEST = 5.0;

@interface ZLTaskManager (Test)

+ (void)tearDownForTest;

@property (nonatomic, strong) NSOperationQueue *activeTaskQueue;
@property (nonatomic, strong) NSDictionary *managersForTypeDictionary;

@property (nonatomic, strong) NSTimer *workTimer;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) BOOL isWaitingForStopCompletion;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) Reachability *reachability;

- (BOOL)createAndQueueNextTaskWorker;
- (void)scheduleMoreWork;

@end

@interface ZLWorkItemDatabase (Test)

+ (void)resetForTest;

@end

@interface ZLTaskManagerTests : XCTestCase

@end

@implementation ZLTaskManagerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    [ZLTaskManager tearDownForTest];
    [ZLWorkItemDatabase resetForTest];
    [super tearDown];
}

#pragma mark - Test sharedInstance

- (void)testSharedInstanceNoExistingSharedInstance
{
    id mockWorkDB = [OCMockObject mockForClass:[ZLWorkItemDatabase class]];
    [[mockWorkDB expect] restartExecutingTasks];
    [[mockWorkDB expect] restartHoldingTasks];
    
    ZLTaskManager *taskManager = [ZLTaskManager sharedInstance];
    
    XCTAssertNotNil(taskManager, @"The sharedInstance method should never return a nil taskManager.");
    XCTAssertNotNil(taskManager.activeTaskQueue, @"The activeTaskQueue should not be nil after initialization");
    XCTAssertTrue([taskManager.activeTaskQueue.name isEqualToString:kActiveTaskQueueNameTEST], @"The name of the activeTaskQueue should be %@ but it is %@", kActiveTaskQueueNameTEST, taskManager.activeTaskQueue.name);
    XCTAssertEqual(4, taskManager.activeTaskQueue.maxConcurrentOperationCount, @"The max number of concurrent operations is %i but it should equal the number of processors %i", (int)taskManager.activeTaskQueue.maxConcurrentOperationCount, (int)[[NSProcessInfo processInfo] processorCount]);
    XCTAssertTrue(taskManager.isRunning, @"The TaskManager should be initialized with isRunning set to true");
    XCTAssertFalse(taskManager.isWaitingForStopCompletion, @"The TaskManager should be initialized with isWaitingForStopCompletion set to false");
    XCTAssertNotNil(taskManager.serialQueue);
    
    [mockWorkDB verify];
    [mockWorkDB stopMocking];
}

- (void)testSharedInstanceExistingSharedInstance
{
    ZLTaskManager *taskManagerOne = [ZLTaskManager sharedInstance];
    ZLTaskManager *taskManagerTwo = [ZLTaskManager sharedInstance];
    
    XCTAssertEqual(taskManagerOne, taskManagerTwo, @"sharedInstance should always return the same TaskManager.");
}

- (void)testSharedInstanceImplementsTaskWorkerFinishedDelegate
{
    XCTAssertTrue([[ZLTaskManager sharedInstance] conformsToProtocol:@protocol(ZLTaskFinishedProtocol)]);
}

#pragma mark - Test Running

- (void)testStopWithCompletionHandler
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockActiveTaskQueue = [OCMockObject partialMockForObject:taskManager.activeTaskQueue];
    [[mockActiveTaskQueue expect] cancelAllOperations];
    
    XCTestExpectation *completionBlockExpectation = [self expectationWithDescription:@"The stop completion block shoud have been called"];
    XCTestExpectation *networkCancellationExpectation = [self expectationWithDescription:@"Network CancellationBlock"];
    
    for (int i=0; i<10; i++) {
        ZLTestConcurrnetTaskWorker *waitTaskWorker = [[ZLTestConcurrnetTaskWorker alloc] initWithConcurrentWaitTime:1.5];
        [taskManager.activeTaskQueue addOperation:waitTaskWorker];
    }
    
    
    [taskManager stopWithNetworkCancellationBlock:^{
        [networkCancellationExpectation fulfill];
    } completionHandler:^{
        [completionBlockExpectation fulfill];
        XCTAssertEqual(taskManager.activeTaskQueue.operationCount, 0, @"The completion block shouldn't be called until all the operations have finished");
        XCTAssertFalse(taskManager.isWaitingForStopCompletion, @"Is waitingForStopCompletion should be set to false after the completionHandler is called");
    }];
    
    XCTAssertTrue(taskManager.isWaitingForStopCompletion, @"Is waitingForStopCompletion should be set to true after the stop method is called");
    
    [self waitForExpectationsWithTimeout:15.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error waiting for stop completion block to be called %@", error);
        }
    }];
    XCTAssertFalse(taskManager.isRunning, @"After we call stop the isRunning flag should be set to false");
    [mockActiveTaskQueue verify];
}

- (void)testStopAndWait
{
    ZLTaskManager *manager = [ZLTaskManager new];
    id mockActiveTaskQueue = [OCMockObject partialMockForObject:manager.activeTaskQueue];
    [mockActiveTaskQueue setExpectationOrderMatters:YES];
    [[mockActiveTaskQueue expect] cancelAllOperations];
    [[mockActiveTaskQueue expect] waitUntilAllOperationsAreFinished];
    
     XCTestExpectation *networkCancellationExpectation = [self expectationWithDescription:@"Network CancellationBlock"];
    
    [manager stopAndWaitWithNetworkCancellationBlock:^{
        [networkCancellationExpectation fulfill];
    }];
    
    XCTAssertFalse(manager.isWaitingForStopCompletion, @"Is waitingForStopCompletion should be set to false after the completionHandler is called");
    XCTAssertFalse(manager.isRunning, @"After we call stop the isRunning flag should be set to false");
    
    [mockActiveTaskQueue verify];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testResume
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    [taskManager stopWithNetworkCancellationBlock:nil completionHandler:nil];
    
    [taskManager resume];
    XCTAssertTrue(taskManager.isRunning, @"After we call resume the isRunning flag should be set to true");
}

- (void)testResumeCallsScheduleMoreWorkActiveQueueHasCompleted
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager expect] scheduleMoreWork];
    
    [taskManager resume];
    
    [mockTaskManager verify];
    [mockTaskManager stopMocking];
}

- (void)testScheduleMoreWorkIsCalledAfterCompletionBlockIsFinishedIfIsRunningIsTrue
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager expect] scheduleMoreWork];
    
    taskManager.isRunning = YES;
    taskManager.isWaitingForStopCompletion = NO;
    
    [mockTaskManager verify];
    [mockTaskManager stopMocking];
}

- (void)testScheduleMoreWorkIsNotCalledAfterCompletionBlockIsFinishedIfIsRunningIsFalse
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager reject] scheduleMoreWork];
    
    taskManager.isRunning = NO;
    taskManager.isWaitingForStopCompletion = NO;
    
    [mockTaskManager verify];
    [mockTaskManager stopMocking];
}

- (void)testScheduleMoreWorkIsNotCalledWhenIsWaitingIsSetToTrue
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager reject] scheduleMoreWork];
    
    taskManager.isRunning = YES;
    taskManager.isWaitingForStopCompletion = YES;
    
    [mockTaskManager verify];
    [mockTaskManager stopMocking];
}

#pragma mark - Test Queueing

- (void)testQueueTaskSuccess
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager expect] scheduleMoreWork];
    
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSDictionary *testDataDictionary = @{@"key1":@"value1", @"key2":@"value2", @"Key3":@"value3"};
    NSError *error = nil;
    NSData *testData = [NSJSONSerialization dataWithJSONObject:testDataDictionary options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        NSLog(@"Error in testQueueTask serializing testDataDictionary to NSData %@", error);
    }
    
    NSString *testTaskType = @"testTaskType123";
    NSInteger testMajorPriority = arc4random()%5;
    NSInteger testMinorPriority = arc4random()%5;
    NSInteger testMaxRetryCOunt = arc4random_uniform(34);
    BOOL testShouldRestart = YES;
    
    BOOL testRequiresInternet = YES;
    double testTimeCreated = [[NSDate new] timeIntervalSince1970];
    
    ZLTask *task = [[ZLTask alloc] init];
    task.taskType = testTaskType;
    task.jsonData = testDataDictionary;
    task.majorPriority = testMajorPriority;
    task.minorPriority = testMinorPriority;
    task.requiresInternet = testRequiresInternet;
    task.maxNumberOfRetries = testMaxRetryCOunt;
    task.shouldHoldAndRestartAfterMaxRetries = testShouldRestart;
    
    [OCMExpect([workItemDatabaseMock addNewWorkItem:[OCMArg checkWithBlock:^BOOL(id obj) {
        ZLInternalWorkItem *workItem = nil;
        if ([obj isKindOfClass:[ZLInternalWorkItem class]]) {
            workItem = (ZLInternalWorkItem *)obj;
        } else {
            return NO;
        }
        
        XCTAssertEqual(testTaskType, workItem.taskType, @"The workItem.taskType %@ should equal the provided taskType %@", workItem.taskType, testTaskType);
        XCTAssertEqual(testMajorPriority, workItem.majorPriority, @"The workItem.majorPriority %i should equal the provided majorPriority %i", (int)workItem.majorPriority, (int)testMajorPriority);
        XCTAssertEqual(testMinorPriority, workItem.minorPriority, @"The workItem.minorPriority %i should equal the provided minorPriority %i", (int)workItem.minorPriority, (int)testMinorPriority);
        XCTAssertTrue([testData isEqualToData:workItem.data], @"The workItem.data should equal the NSData equivalent of the provided dataDictionary");
        XCTAssertEqual(ZLWorkItemStateReady, workItem.state, @"The initial state of a workItem should be ADWorkItemStateReady instead it is %i", (int)workItem.state);
        XCTAssertEqual(0, workItem.retryCount, @"The initial retryCount of a workItem should be zero. It is %i", (int)workItem.retryCount);
        XCTAssertEqual(testRequiresInternet, workItem.requiresInternet, @"The workItem.requiresInternet should equal the provided value of %i but it does not", (int)testRequiresInternet);
        XCTAssertEqual(testMaxRetryCOunt, workItem.maxNumberOfRetries);
        XCTAssertEqual(testShouldRestart, workItem.shouldHoldAfterMaxRetries);
        // Since we know the timeCreated won't be exactly the same we just want to make sure it's the same to within a second
        double difference = fabs(testTimeCreated-workItem.timeCreated);
        
        XCTAssertTrue(difference<1.0, @"The workItem.timeCreated %f should be approximately equal to the time when we called the method %f", workItem.timeCreated, testTimeCreated);
        
        return YES;
    }]]) andReturnValue:OCMOCK_VALUE(YES)];
    
    
    BOOL success = [taskManager queueTask:task];
    
    XCTAssertTrue(success, @"This operation should return true when it is successful.");
    
    OCMVerifyAll(workItemDatabaseMock);
    [mockTaskManager verify];
    [workItemDatabaseMock stopMocking];
}

- (void)testQueueTaskNoTaskType
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager reject] scheduleMoreWork];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSDictionary *testDataDictionary = @{@"key1":@"value1", @"key2":@"value2", @"Key3":@"value3"};
    
    NSInteger testMajorPriority = arc4random()%5;
    NSInteger testMinorPriority = arc4random()%5;
    
    ZLTask *task = [[ZLTask alloc] init];
    task.jsonData = testDataDictionary;
    task.taskType = nil;
    task.majorPriority = testMajorPriority;
    task.minorPriority = testMinorPriority;
    
    [[workItemDatabaseMock reject] addNewWorkItem:[OCMArg any]];
    
    
    BOOL success = [taskManager queueTask:task];
    
    XCTAssertFalse(success);
    [mockTaskManager verify];
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

- (void)testQueueTaskFailure
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager reject] scheduleMoreWork];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSDictionary *testDataDictionary = @{@"key1":@"value1", @"key2":@"value2", @"Key3":@"value3"};
    
    NSString *testTaskType = @"anotherType";
    NSInteger testMajorPriority = arc4random()%5;
    NSInteger testMinorPriority = arc4random()%5;
    
    ZLTask *task = [[ZLTask alloc] init];
    task.jsonData = testDataDictionary;
    task.taskType = testTaskType;
    task.majorPriority = testMajorPriority;
    task.minorPriority = testMinorPriority;
    
    [OCMExpect([workItemDatabaseMock addNewWorkItem:[OCMArg any]]) andReturnValue:OCMOCK_VALUE(NO)];
    
    
    BOOL success = [taskManager queueTask:task];
    
    XCTAssertFalse(success, @"When the ZLWorkItemDatabase returns false this method must also return false indicating that it failed.");
    [mockTaskManager verify];
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

- (void)testQueueTaskArraySuccess
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager expect] scheduleMoreWork];
    
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSDictionary *testDataDictionary = @{@"key1":@"value1", @"key2":@"value2", @"Key3":@"value3"};
    NSError *error = nil;
    NSData *testData = [NSJSONSerialization dataWithJSONObject:testDataDictionary options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        NSLog(@"Error in testQueueTask serializing testDataDictionary to NSData %@", error);
    }
    
    NSString *testTaskType = @"testTaskType123";
    NSInteger testMajorPriority = arc4random()%5;
    NSInteger testMinorPriority = arc4random()%5;
    NSInteger testMaxRetryCOunt = arc4random_uniform(34);
    
    NSString *testTaskType2 = @"testTaskType12aa3";
    NSInteger testMajorPriority2 = arc4random()%5;
    NSInteger testMinorPriority2 = arc4random()%5;
    NSInteger testMaxRetryCOunt2 = arc4random_uniform(34);
    
    BOOL testShouldRestart = YES;
    
    BOOL testRequiresInternet = YES;
    double testTimeCreated = [[NSDate new] timeIntervalSince1970];
    
    ZLTask *task = [[ZLTask alloc] init];
    task.taskType = testTaskType;
    task.jsonData = testDataDictionary;
    task.majorPriority = testMajorPriority;
    task.minorPriority = testMinorPriority;
    task.requiresInternet = testRequiresInternet;
    task.maxNumberOfRetries = testMaxRetryCOunt;
    task.shouldHoldAndRestartAfterMaxRetries = testShouldRestart;

    
    ZLTask *task2 = [[ZLTask alloc] init];
    task2.taskType = testTaskType2;
    task2.jsonData = testDataDictionary;
    task2.majorPriority = testMajorPriority2;
    task2.minorPriority = testMinorPriority2;
    task2.requiresInternet = testRequiresInternet;
    task2.maxNumberOfRetries = testMaxRetryCOunt2;
    task2.shouldHoldAndRestartAfterMaxRetries = testShouldRestart;

    [OCMExpect([workItemDatabaseMock addNewWorkItem:[OCMArg checkWithBlock:^BOOL(id obj) {
        ZLInternalWorkItem *workItem = nil;
        if ([obj isKindOfClass:[ZLInternalWorkItem class]]) {
            workItem = (ZLInternalWorkItem *)obj;
        } else {
            return NO;
        }
        
        XCTAssertEqual(testTaskType, workItem.taskType, @"The workItem.taskType %@ should equal the provided taskType %@", workItem.taskType, testTaskType);
        XCTAssertEqual(testMajorPriority, workItem.majorPriority, @"The workItem.majorPriority %i should equal the provided majorPriority %i", (int)workItem.majorPriority, (int)testMajorPriority);
        XCTAssertEqual(testMinorPriority, workItem.minorPriority, @"The workItem.minorPriority %i should equal the provided minorPriority %i", (int)workItem.minorPriority, (int)testMinorPriority);
        XCTAssertTrue([testData isEqualToData:workItem.data], @"The workItem.data should equal the NSData equivalent of the provided dataDictionary");
        XCTAssertEqual(ZLWorkItemStateReady, workItem.state, @"The initial state of a workItem should be ADWorkItemStateReady instead it is %i", (int)workItem.state);
        XCTAssertEqual(0, workItem.retryCount, @"The initial retryCount of a workItem should be zero. It is %i", (int)workItem.retryCount);
        XCTAssertEqual(testRequiresInternet, workItem.requiresInternet, @"The workItem.requiresInternet should equal the provided value of %i but it does not", (int)testRequiresInternet);
        XCTAssertEqual(testMaxRetryCOunt, workItem.maxNumberOfRetries);
        XCTAssertEqual(testShouldRestart, workItem.shouldHoldAfterMaxRetries);
        // Since we know the timeCreated won't be exactly the same we just want to make sure it's the same to within a second
        double difference = fabs(testTimeCreated-workItem.timeCreated);
        
        XCTAssertTrue(difference<1.0, @"The workItem.timeCreated %f should be approximately equal to the time when we called the method %f", workItem.timeCreated, testTimeCreated);
        
        return YES;
    }]]) andReturnValue:OCMOCK_VALUE(YES)];
    
    [OCMExpect([workItemDatabaseMock addNewWorkItem:[OCMArg checkWithBlock:^BOOL(id obj) {
        ZLInternalWorkItem *workItem = nil;
        if ([obj isKindOfClass:[ZLInternalWorkItem class]]) {
            workItem = (ZLInternalWorkItem *)obj;
        } else {
            return NO;
        }
        
        XCTAssertEqual(testTaskType2, workItem.taskType, @"The workItem.taskType %@ should equal the provided taskType %@", workItem.taskType, testTaskType);
        XCTAssertEqual(testMajorPriority2, workItem.majorPriority, @"The workItem.majorPriority %i should equal the provided majorPriority %i", (int)workItem.majorPriority, (int)testMajorPriority);
        XCTAssertEqual(testMinorPriority2, workItem.minorPriority, @"The workItem.minorPriority %i should equal the provided minorPriority %i", (int)workItem.minorPriority, (int)testMinorPriority);
        XCTAssertTrue([testData isEqualToData:workItem.data], @"The workItem.data should equal the NSData equivalent of the provided dataDictionary");
        XCTAssertEqual(ZLWorkItemStateReady, workItem.state, @"The initial state of a workItem should be ADWorkItemStateReady instead it is %i", (int)workItem.state);
        XCTAssertEqual(0, workItem.retryCount, @"The initial retryCount of a workItem should be zero. It is %i", (int)workItem.retryCount);
        XCTAssertEqual(testRequiresInternet, workItem.requiresInternet, @"The workItem.requiresInternet should equal the provided value of %i but it does not", (int)testRequiresInternet);
        XCTAssertEqual(testMaxRetryCOunt2, workItem.maxNumberOfRetries);
        XCTAssertEqual(testShouldRestart, workItem.shouldHoldAfterMaxRetries);
        // Since we know the timeCreated won't be exactly the same we just want to make sure it's the same to within a second
        double difference = fabs(testTimeCreated-workItem.timeCreated);
        
        XCTAssertTrue(difference<1.0, @"The workItem.timeCreated %f should be approximately equal to the time when we called the method %f", workItem.timeCreated, testTimeCreated);
        
        return YES;
    }]]) andReturnValue:OCMOCK_VALUE(YES)];
    
    
    BOOL success = [taskManager queueTaskArray:@[task, task2]];
    
    XCTAssertTrue(success, @"This operation should return true when it is successful.");
    
    OCMVerifyAll(workItemDatabaseMock);
    [mockTaskManager verify];
    [workItemDatabaseMock stopMocking];
}

- (void)testQueueTaskArrayNoTaskType
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager reject] scheduleMoreWork];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSDictionary *testDataDictionary = @{@"key1":@"value1", @"key2":@"value2", @"Key3":@"value3"};
    
    NSInteger testMajorPriority = arc4random()%5;
    NSInteger testMinorPriority = arc4random()%5;
    
    ZLTask *task = [[ZLTask alloc] init];
    task.jsonData = testDataDictionary;
    task.taskType = nil;
    task.majorPriority = testMajorPriority;
    task.minorPriority = testMinorPriority;
    
    [[workItemDatabaseMock reject] addNewWorkItem:[OCMArg any]];
    
    
    BOOL success = [taskManager queueTaskArray:@[task]];
    
    XCTAssertFalse(success);
    [mockTaskManager verify];
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

- (void)testQueueTaskArrayFailure
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[mockTaskManager reject] scheduleMoreWork];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSDictionary *testDataDictionary = @{@"key1":@"value1", @"key2":@"value2", @"Key3":@"value3"};
    
    NSString *testTaskType = @"anotherType";
    NSInteger testMajorPriority = arc4random()%5;
    NSInteger testMinorPriority = arc4random()%5;
    
    ZLTask *task = [[ZLTask alloc] init];
    task.jsonData = testDataDictionary;
    task.taskType = testTaskType;
    task.majorPriority = testMajorPriority;
    task.minorPriority = testMinorPriority;
    
    [OCMExpect([workItemDatabaseMock addNewWorkItem:[OCMArg any]]) andReturnValue:OCMOCK_VALUE(NO)];
    
    
    BOOL success = [taskManager queueTaskArray:@[task]];
    
    XCTAssertFalse(success, @"When the ZLWorkItemDatabase returns false this method must also return false indicating that it failed.");
    [mockTaskManager verify];
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}


#pragma mark - Test WorkItemDatabase manipulation

- (void)testRemoveTasksOfType
{
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    NSString *testType = @"testingType";
    
    OCMExpect([workItemDatabaseMock deleteWorkItemsWithTaskType:testType]);
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    [taskManager removeTasksOfType:testType];
    
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

- (void)testChangePriorityOfTaskType
{
    NSString *testType = @"testingType";
    NSInteger testMajorPriority = 4;
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    OCMExpect([workItemDatabaseMock changePriorityOfTaskType:testType newMajorPriority:testMajorPriority]);
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    [taskManager changePriorityOfTasksOfType:testType newMajorPriority:testMajorPriority];
    
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

- (void)testCountOfTasksOfType
{
    NSString *testType = @"testingType";
    NSInteger countToReturn = 54;
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    [OCMExpect([workItemDatabaseMock countOfWorkItemsWithTaskType:testType]) andReturnValue:OCMOCK_VALUE(countToReturn)];
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    NSInteger count = [taskManager countOfTasksOfType:testType];
    
    XCTAssertEqual(count, countToReturn, @"The operation returned %i and we exected %i", (int)count, (int)countToReturn);
    
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

- (void)testRestartHoldingTasks
{
    id workItemMock = [OCMockObject mockForClass:[ZLWorkItemDatabase class]];
    [[workItemMock expect] restartHoldingTasks];
    
    ZLTaskManager *manager = [ZLTaskManager new];
    [manager restartHoldingTasks];
    
    [workItemMock verify];
}

#pragma mark - Test Registration

- (void)testRegisterManagerForTaskTypeNotPreviouslyRegistered
{
    NSString *testTaskType = @"testTaskType";
    ZLManager *testManager = [[ZLManager alloc] init];
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    XCTAssertNil([taskManager.managersForTypeDictionary objectForKey:testTaskType], @"There should not yet be a manager for TaskType %@", testTaskType);
    
    [taskManager registerManager:testManager forTaskType:testTaskType];
    
    XCTAssertEqual(testManager, [taskManager.managersForTypeDictionary objectForKey:testTaskType], @"The taskManager manager for %@ should be the same as the manager we provided but it is not", testTaskType);
}

- (void)testRegisterManagerForTaskTypePreviouslyRegistered
{
    NSString *testTaskType = @"testTaskType";
    ZLManager *testManager = [[ZLManager alloc] init];
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    [taskManager registerManager:testManager forTaskType:testTaskType];
    
    XCTAssertNotNil([taskManager.managersForTypeDictionary objectForKey:testTaskType], @"The testManager should be registered for taskType %@", testTaskType);
    
    [taskManager registerManager:testManager forTaskType:testTaskType];
    
    XCTAssertEqual(testManager, [taskManager.managersForTypeDictionary objectForKey:testTaskType], @"The taskManager manager for %@ should be the same as the manager we provided but it is not", testTaskType);
    
}

- (void)testRemoveRegisteredManagerForTaskTypeManagerWasNotRegistered
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    ZLManager *controlManager = [[ZLManager alloc] init];
    NSString *controlTaskType = @"controlTaskType";
    [taskManager registerManager:controlManager forTaskType:controlTaskType];
    
    NSInteger initialNumberOfRegisteredTypes = [taskManager.managersForTypeDictionary allKeys].count;
    
    ZLManager *nonRegisteredManager = [[ZLManager alloc] init];
    [taskManager removeRegisteredManagerForAllTaskTypes:nonRegisteredManager];
    
    NSInteger finalNumberOfRegisteredTypes = [taskManager.managersForTypeDictionary allKeys].count;
    
    XCTAssertEqual(initialNumberOfRegisteredTypes, finalNumberOfRegisteredTypes, @"Since the manager was not registered removing it should have no effect.");
}

- (void)testRemoveregisteredManagerForTaskTypeManagerWasRegisteredForSingleTaskType
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    ZLManager *controlManager = [[ZLManager alloc] init];
    NSString *controlTaskType = @"controlTaskType";
    
    ZLManager *managerToRemove = [[ZLManager alloc] init];
    NSString *taskTypeToRemove = @"taskTypeToRemove";
    
    [taskManager registerManager:managerToRemove forTaskType:taskTypeToRemove];
    [taskManager registerManager:controlManager forTaskType:controlTaskType];
    
    NSInteger initialNumberOfRegisteredTypes = [taskManager.managersForTypeDictionary allKeys].count;
    
    [taskManager removeRegisteredManagerForAllTaskTypes:managerToRemove];
    
    NSInteger finalNumberOfRegisteredTypes = [taskManager.managersForTypeDictionary allKeys].count;
    
    XCTAssertEqual(initialNumberOfRegisteredTypes-1, finalNumberOfRegisteredTypes, @"Since we removed one manager associated with one TaskType we should have one less registration than what we started with");
    
    XCTAssertNil([taskManager.managersForTypeDictionary objectForKey:taskTypeToRemove], @"There should be no manager registered for taskType %@ after we have removed the manager that was previously associated with it.", taskTypeToRemove);
}

- (void)testRemoveregisteredManagerForTaskTypeManagerWasRegisteredForMultipleTaskTypes
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    ZLManager *controlManager = [[ZLManager alloc] init];
    NSString *controlTaskType = @"controlTaskType";
    
    ZLManager *managerToRemove = [[ZLManager alloc] init];
    NSString *taskTypeToRemove = @"taskTypeToRemove";
    NSString *secondTaskTypeToRemove = @"secondTaskTypeToRemove";
    
    [taskManager registerManager:managerToRemove forTaskType:taskTypeToRemove];
    [taskManager registerManager:managerToRemove forTaskType:secondTaskTypeToRemove];
    [taskManager registerManager:controlManager forTaskType:controlTaskType];
    
    NSInteger initialNumberOfRegisteredTypes = [taskManager.managersForTypeDictionary allKeys].count;
    
    [taskManager removeRegisteredManagerForAllTaskTypes:managerToRemove];
    
    NSInteger finalNumberOfRegisteredTypes = [taskManager.managersForTypeDictionary allKeys].count;
    
    XCTAssertEqual(initialNumberOfRegisteredTypes-2, finalNumberOfRegisteredTypes, @"Since we removed one manager associated with two TaskType we should have two less registration than what we started with");
    
    XCTAssertNil([taskManager.managersForTypeDictionary objectForKey:taskTypeToRemove], @"There should be no manager registered for taskType %@ after we have removed the manager that was previously associated with it.", taskTypeToRemove);
    XCTAssertNil([taskManager.managersForTypeDictionary objectForKey:secondTaskTypeToRemove], @"There should be no manager registered for taskType %@ after we have removed the manager that was previously associated with it.", secondTaskTypeToRemove);
}

#pragma mark - Test scheduleMoreWork

- (void)testScheduleMoreWorkResetWorkTimer
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    [taskManager scheduleMoreWork];
    
    XCTAssertTrue(taskManager.workTimer.isValid, @"After the schedulMoreWork method is called the timer should be reset and valid");
    XCTAssertEqual(taskManager.workTimer.timeInterval, kScheduleWorkTimeIntervalTEST, @"The workTimer timeInterval is %i but should equal the constant %i", (int)taskManager.workTimer.timeInterval, (int)kScheduleWorkTimeIntervalTEST);
}

- (void)testScheduleMoreWorkQueuesAsManyTaskWorkersAsPossible
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    [[OCMStub([mockTaskManager createAndQueueNextTaskWorker]) andDo:^(NSInvocation *invocation) {
        ZLTestConcurrnetTaskWorker *taskWorker = [[ZLTestConcurrnetTaskWorker alloc] initWithConcurrentWaitTime:1.5];
        [taskManager.activeTaskQueue addOperation:taskWorker];
    }] andReturnValue:OCMOCK_VALUE(YES)];
    
    [taskManager scheduleMoreWork];
    
    XCTAssertEqual(taskManager.activeTaskQueue.maxConcurrentOperationCount, taskManager.activeTaskQueue.operationCount, @"We should have as many operations in the activeTaskQueue as possible after calling scheduleMoreWork");
    
    [mockTaskManager stopMocking];
}

- (void)testScheduleMoreWorkWontQueueMoreWorkIfFull
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id mockTaskManager = [OCMockObject partialMockForObject:taskManager];
    
    [[mockTaskManager reject] createAndQueueNextTaskWorker];
    
    taskManager.activeTaskQueue.suspended = YES;
    taskManager.activeTaskQueue.maxConcurrentOperationCount = 1;
    [taskManager.activeTaskQueue addOperation:[NSOperation new]];
    
    
    [taskManager scheduleMoreWork];
    
    [mockTaskManager verify];
}

#pragma mark - Test createAndAddTaskWorker

- (void)testCreateAndQueueNextTaskWorkerNoMoreWork
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    [[[workItemDatabaseMock expect] andReturn:nil] getNextWorkItemForTaskTypes:[OCMArg any]];
    
    id mockReachability = [OCMockObject partialMockForObject:taskManager.reachability];
    [[[mockReachability stub] andReturnValue:OCMOCK_VALUE(YES)] isReachable];
    
    
    BOOL workAdded = [taskManager createAndQueueNextTaskWorker];
    
    XCTAssertFalse(workAdded, @"There was no work in the WorkItemDatabase so this should have returned false");
    
    [mockReachability stopMocking];
    [workItemDatabaseMock verify];
    [workItemDatabaseMock stopMocking];
}

- (void)testCreateAndQueueNextTaskWorkerIsPaused
{
    NSString *testTaskType = @"testTaskType";
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.taskType = testTaskType;
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id mockReachability = [OCMockObject partialMockForObject:taskManager.reachability];
    [[[mockReachability stub] andReturnValue:OCMOCK_VALUE(YES)] isReachable];
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    id mockManager = [OCMockObject mockForClass:[ZLManager class]];
    [OCMExpect([mockManager taskWorkerForWorkItem:workItem]) andReturn:taskWorker];
    
    [taskManager registerManager:mockManager forTaskType:testTaskType];
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    [OCMStub([workItemDatabaseMock getNextWorkItemForTaskTypes:[taskManager.managersForTypeDictionary allKeys]]) andReturn:workItem];
    
    taskManager.isRunning = NO;
    
    BOOL workAdded = [taskManager createAndQueueNextTaskWorker];
    
    
    XCTAssertFalse(workAdded, @"The taskManager was paused so this should have returned false.");
    
    [mockReachability stopMocking];
}

- (void)testCreateAndQueueNextTaskWorkerWasPausedNotCompleted
{
    NSString *testTaskType = @"testTaskType";
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.taskType = testTaskType;
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id mockReachability = [OCMockObject partialMockForObject:taskManager.reachability];
    [[[mockReachability stub] andReturnValue:OCMOCK_VALUE(YES)] isReachable];
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    id mockManager = [OCMockObject mockForClass:[ZLManager class]];
    [OCMExpect([mockManager taskWorkerForWorkItem:workItem]) andReturn:taskWorker];
    
    [taskManager registerManager:mockManager forTaskType:testTaskType];
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    [OCMStub([workItemDatabaseMock getNextWorkItemForTaskTypes:[taskManager.managersForTypeDictionary allKeys]]) andReturn:workItem];
    
    taskManager.isWaitingForStopCompletion = YES;
    
    BOOL workAdded = [taskManager createAndQueueNextTaskWorker];
    
    XCTAssertFalse(workAdded, @"The taskManager isWaitingForStopCompletion was yes so this should have returned false.");
    
    [mockReachability stopMocking];
}

- (void)testCreateAndQueueNextTaskWorkerNoManagersForWork
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    [taskManager registerManager:[ZLManager new] forTaskType:@"testTaskType"];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    [[[workItemDatabaseMock expect] andReturn:nil] getNextWorkItemForTaskTypes:[taskManager.managersForTypeDictionary allKeys]];
    
    id mockReachability = [OCMockObject partialMockForObject:taskManager.reachability];
    [[[mockReachability stub] andReturnValue:OCMOCK_VALUE(YES)] isReachable];
    
    BOOL workAdded = [taskManager createAndQueueNextTaskWorker];
    
    XCTAssertFalse(workAdded, @"There was no work in the WorkItemDatabase so this should have returned false");
    
    [mockReachability stopMocking];
    [workItemDatabaseMock verify];
    [workItemDatabaseMock stopMocking];
}

- (void)testCreateAndQueueNextTaskWorkerWorkIsAvailable
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    NSString *testTaskType = @"testTaskType";
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.taskType = testTaskType;
    
    id mockReachability = [OCMockObject partialMockForObject:taskManager.reachability];
    [[[mockReachability stub] andReturnValue:OCMOCK_VALUE(YES)] isReachable];
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    id mockWorker = [OCMockObject partialMockForObject:taskWorker];
    [[mockWorker expect] setTaskFinishedDelegate:taskManager];
    
    id mockManager = [OCMockObject mockForClass:[ZLManager class]];
    [OCMExpect([mockManager taskWorkerForWorkItem:workItem]) andReturn:taskWorker];
    
    [taskManager registerManager:mockManager forTaskType:testTaskType];
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    id mockQueue = [OCMockObject partialMockForObject:taskManager.activeTaskQueue];
    [[mockQueue expect] addOperation:taskWorker];
    
    [OCMExpect([workItemDatabaseMock getNextWorkItemForTaskTypes:[taskManager.managersForTypeDictionary allKeys]]) andReturn:workItem];
    OCMExpect([workItemDatabaseMock updateWorkItem:workItem]);
    
    
    BOOL workAdded = [taskManager createAndQueueNextTaskWorker];
    
    
    XCTAssertTrue(workAdded, @"There was work in the WorkItemDatabase so this should have returned true");
    XCTAssertEqual(workItem.state, ZLWorkItemStateExecuting, @"After this operation the WorkItem.state should equal ADWorkItemStateExecuting not %i", (int)workItem.state);
    
    [mockWorker verify];
    [mockReachability stopMocking];
    [mockQueue verify];
    [mockQueue stopMocking];
    [mockManager verify];
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

- (void)testCreateAndQueueNextTaskWorkerWorkIsAvailableNoInternet
{
    NSString *testTaskType = @"testTaskType";
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.taskType = testTaskType;
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    id mockReachability = [OCMockObject partialMockForObject:taskManager.reachability];
    [[[mockReachability stub] andReturnValue:OCMOCK_VALUE(NO)] isReachable];
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    id mockManager = [OCMockObject mockForClass:[ZLManager class]];
    [OCMExpect([mockManager taskWorkerForWorkItem:workItem]) andReturn:taskWorker];
    
    [taskManager registerManager:mockManager forTaskType:testTaskType];
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    id mockQueue = [OCMockObject partialMockForObject:taskManager.activeTaskQueue];
    [[mockQueue expect] addOperation:taskWorker];
    
    [OCMExpect([workItemDatabaseMock getNextWorkItemForNoInternetForTaskTypes:[taskManager.managersForTypeDictionary allKeys]]) andReturn:workItem];
    OCMExpect([workItemDatabaseMock updateWorkItem:workItem]);
    
    
    BOOL workAdded = [taskManager createAndQueueNextTaskWorker];
    
    
    XCTAssertTrue(workAdded, @"There was work in the WorkItemDatabase so this should have returned true");
    XCTAssertEqual(workItem.state, ZLWorkItemStateExecuting, @"After this operation the WorkItem.state should equal ADWorkItemStateExecuting not %i", (int)workItem.state);
    
    [mockReachability stopMocking];
    [mockQueue verify];
    [mockQueue stopMocking];
    [mockManager verify];
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

#pragma mark - Test Dump State

- (void)testDumpState
{
    NSArray *workItemDatabaseState = @[@{@"key":@"value"},@{@"AnotherKey":@"AnotherValue"}];
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    [OCMExpect([workItemDatabaseMock getDatabaseState]) andReturn:workItemDatabaseState];
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    NSDictionary *state = [taskManager dumpState];
    
    XCTAssertEqual([state objectForKey:kDumpStateWorkItemDatabaseKeyTEST], workItemDatabaseState, @"The result of getDatabaseState should exist in the result from dumpState under the key kDumpStateWorkItemDatabaseKey");
    
    OCMVerifyAll(workItemDatabaseMock);
    [workItemDatabaseMock stopMocking];
}

#pragma mark - Test WorkerFinished Delegate

- (void)testWorkFinishedDelegateSuccess
{
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.state = ZLWorkItemStateExecuting;
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    [taskWorker setupWithWorkItem:workItem];
    [taskWorker setTaskFinishedDelegate:taskManager];
    OCMExpect([workItemDatabaseMock deleteWorkItem:workItem]);
    
    [taskManager taskWorker:taskWorker finishedSuccessfully:YES];
    
    // Do this since finishedSuccessfully happens async
    dispatch_sync(taskManager.serialQueue, ^{
        
    });
    
    [NSThread sleepForTimeInterval:0.5];
    OCMVerifyAll(workItemDatabaseMock);
}

- (void)testWorkFinishedDelegateFailureLessThanMaxRetries
{
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    
    NSInteger initialNumberOfRetries = 0;
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.maxNumberOfRetries = 100;
    workItem.state = ZLWorkItemStateExecuting;
    workItem.retryCount = initialNumberOfRetries;
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    [taskWorker setupWithWorkItem:workItem];
    [taskWorker setTaskFinishedDelegate:taskManager];
    
    OCMExpect([workItemDatabaseMock updateWorkItem:workItem]);
    
    [taskManager taskWorker:taskWorker finishedSuccessfully:NO];
    
    // Do this since finishedSuccessfully happens async
    dispatch_sync(taskManager.serialQueue, ^{
        
    });
    
    XCTAssertEqual(workItem.state, ZLWorkItemStateReady);
    XCTAssertEqual(workItem.retryCount, initialNumberOfRetries+1, @"The retryCount on the workItem should be one more than it was before the failure.");
    
    OCMVerifyAll(workItemDatabaseMock);
}

- (void)testWorkFinishedDelegateFailureLastRetryShouldNotHoldRegisteredManager
{
    ZLTaskManager *manager = [[ZLTaskManager alloc] init];
    NSString *testTaskType = @"taskTypea";
    
    ZLManager *taskTypeManager = [ZLManager new];
    [manager registerManager:taskTypeManager forTaskType:testTaskType];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSInteger maxNumberOfRetries = 23;
    NSInteger initialNumberOfRetries = maxNumberOfRetries-1;
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.maxNumberOfRetries = maxNumberOfRetries;
    workItem.state = ZLWorkItemStateExecuting;
    workItem.retryCount = initialNumberOfRetries;
    workItem.taskType = testTaskType;
    workItem.shouldHoldAfterMaxRetries = NO;
    
    id mockTaskTypeManager = [OCMockObject partialMockForObject:taskTypeManager];
    [[mockTaskTypeManager expect] workItemDidFail:workItem];
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    [taskWorker setupWithWorkItem:workItem];
    [taskWorker setTaskFinishedDelegate:manager];
    
    OCMExpect([workItemDatabaseMock deleteWorkItem:workItem]);
    [manager taskWorker:taskWorker finishedSuccessfully:NO];
    
    // Do this since finishedSuccessfully happens async
    dispatch_sync(manager.serialQueue, ^{
        
    });
    
    XCTAssertEqual(workItem.retryCount, maxNumberOfRetries, @"The retryCount on the workItem should be one more than it was before the failure.");
    
    [mockTaskTypeManager verify];
    [mockTaskTypeManager stopMocking];
    OCMVerifyAll(workItemDatabaseMock);
}

- (void)testWorkFinishedDelegateFailureLastRetryShouldHoldRegisteredManager
{
    ZLTaskManager *manager = [[ZLTaskManager alloc] init];
    NSString *testTaskType = @"taskTypea";
    
    ZLManager *taskTypeManager = [ZLManager new];
    [manager registerManager:taskTypeManager forTaskType:testTaskType];
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    NSInteger maxNumberOfRetries = 23;
    NSInteger initialNumberOfRetries = maxNumberOfRetries-1;
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.maxNumberOfRetries = maxNumberOfRetries;
    workItem.state = ZLWorkItemStateExecuting;
    workItem.retryCount = initialNumberOfRetries;
    workItem.taskType = testTaskType;
    workItem.shouldHoldAfterMaxRetries = YES;
    
    id mockTaskTypeManager = [OCMockObject partialMockForObject:taskTypeManager];
    [[mockTaskTypeManager expect] workItemDidFail:workItem];
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    [taskWorker setupWithWorkItem:workItem];
    [taskWorker setTaskFinishedDelegate:manager];
    
    OCMExpect([workItemDatabaseMock updateWorkItem:workItem]);
    [manager taskWorker:taskWorker finishedSuccessfully:NO];
    
    // Do this since finishedSuccessfully happens async
    dispatch_sync(manager.serialQueue, ^{
        
    });
    
    XCTAssertEqual(workItem.retryCount, maxNumberOfRetries, @"The retryCount on the workItem should be one more than it was before the failure.");
    XCTAssertEqual(workItem.state, ZLWorkItemStateHold);
    
    [mockTaskTypeManager verify];
    [mockTaskTypeManager stopMocking];
    OCMVerifyAll(workItemDatabaseMock);
}

- (void)testWorkFinishedDelegateFailureThirdRetryNoRegisteredManager
{
    ZLTaskManager *manager = [[ZLTaskManager alloc] init];
    NSString *testTaskType = @"taskTypea";
    
    id workItemDatabaseMock = OCMStrictClassMock([ZLWorkItemDatabase class]);
    
    
    NSInteger maxNumberOfRetries = 23;
    NSInteger initialNumberOfRetries = maxNumberOfRetries-1;
    ZLInternalWorkItem *workItem = [self createRandomTestWorkItem];
    workItem.maxNumberOfRetries = maxNumberOfRetries;
    workItem.state = ZLWorkItemStateExecuting;
    workItem.retryCount = initialNumberOfRetries;
    workItem.taskType = testTaskType;
    workItem.shouldHoldAfterMaxRetries = NO;
    
    ZLTaskWorker *taskWorker = [ZLTaskWorker new];
    [taskWorker setupWithWorkItem:workItem];
    [taskWorker setTaskFinishedDelegate:manager];
    
    OCMExpect([workItemDatabaseMock deleteWorkItem:workItem]);
    [manager taskWorker:taskWorker finishedSuccessfully:NO];
    
    dispatch_sync(manager.serialQueue, ^{
        
    });
    
    XCTAssertEqual(workItem.retryCount, maxNumberOfRetries, @"The retryCount on the workItem should be one more than it was before the failure.");
    
    OCMVerifyAll(workItemDatabaseMock);
}

- (void)testWorkFinishedDelegateDoesScheduleMoreWorkAfterSuccess
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id taskManagerMock = [OCMockObject partialMockForObject:taskManager];
    
    [[taskManagerMock expect] scheduleMoreWork];
    [taskManager taskWorker:[ZLTaskWorker new] finishedSuccessfully:YES];
    
    // Do this since finishedSuccessfully happens async
    dispatch_sync(taskManager.serialQueue, ^{
        
    });
    
    [taskManagerMock verify];
    [taskManagerMock stopMocking];
}

- (void)testWorkFinishedDelegateDoesScheduleMoreWorkAfterFailure
{
    ZLTaskManager *taskManager = [[ZLTaskManager alloc] init];
    id taskManagerMock = [OCMockObject partialMockForObject:taskManager];
    
    [[taskManagerMock expect] scheduleMoreWork];
    [taskManager taskWorker:[ZLTaskWorker new] finishedSuccessfully:NO];
    
    // Do this since finishedSuccessfully happens async
    dispatch_sync(taskManager.serialQueue, ^{
        
    });
    
    [taskManagerMock verify];
    [taskManagerMock stopMocking];
}

#pragma mark - Helpers

- (ZLInternalWorkItem *)createRandomTestWorkItem
{
    NSInteger randomNumber = arc4random()%200;
    
    NSString *testTaskType = [NSString stringWithFormat:@"type%i", arc4random()%3];
    ZLWorkItemState testState = ZLWorkItemStateReady;
    
    NSString *testDataString = [NSString stringWithFormat:@"lkasjdf li sldie ks %i", (int)randomNumber];
    NSData *testData = [testDataString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *testTaskID = [NSString stringWithFormat:@"thisisatestid %i", (int)randomNumber];
    NSInteger testMajorPriority = arc4random()%20;
    NSInteger testMinorPriority = arc4random()%20;
    NSInteger testRetryCount = arc4random()%20;
    double testTimeCreated = arc4random()%200000;
    BOOL testRequiresInternet = NO;
    
    if (arc4random()%2 == 0) {
        testRequiresInternet = YES;
    }
    
    // Execute the method
    ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] init];
    workItem.recordID = 1;
    workItem.taskType = testTaskType;
    workItem.taskID = testTaskID;
    workItem.state = testState;
    workItem.data = testData;
    workItem.majorPriority = testMajorPriority;
    workItem.minorPriority = testMinorPriority;
    workItem.retryCount = testRetryCount;
    workItem.timeCreated = testTimeCreated;
    workItem.requiresInternet = testRequiresInternet;
    
    return workItem;
}

@end
