//
//  ZLTestWorkItemDatabase.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZLWorkItemDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
#import "ZLWorkItemDatabaseConstants.h"
#import "ZLInternalWorkItem.h"

@interface ZLWorkItemDatabase (Test)

+ (FMDatabaseQueue *)sharedQueue;
+ (void)resetForTest;

@end

@interface ZLTestWorkItemDatabase : XCTestCase

@end

@implementation ZLTestWorkItemDatabase

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
	  [ZLWorkItemDatabase resetForTest];
}

#pragma mark - Test Initialize/SharedQueue

- (void)testGettingInitialSharedQueue
{
	[ZLWorkItemDatabase resetForTest];
	
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	
	XCTAssertNotNil(queue, @"Shared queue should not be nil after sharedQueue is called");
	
	NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
	NSString *path = [[NSString alloc] initWithString:[cachesDirectory stringByAppendingPathComponent:kZLWorkItemDatabaseLocation]];
	
	XCTAssertTrue([queue.path isEqualToString:path], @"Queue database path %@ should be the same as the specified path %@", queue.path, path);
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@", kZLWorkItemDatabaseTableName];
		FMResultSet *set = [db executeQuery:query];
		XCTAssertFalse(db.hadError, @"There was an error getting the table from the database %@", [db lastError]);
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLWorkItemIDColumnKey] integerValue], 0, @"The column at index zero should be id");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLTaskTypeColumnKey] integerValue], 1, @"The column at index one should be taskType");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLTaskIDColumnKey] integerValue], 2, @"The column at index two should be taskID");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLStateColumnKey] integerValue], 3, @"The column at index three should be state");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLDataColumnKey] integerValue], 4, @"The column at index four should be data");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLMajorPriorityColumnKey] integerValue], 5, @"The column at index five should be majorpriority");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLMinorPriorityColumnKey] integerValue], 6, @"The column at index six should be minorpriority");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLRetryCountColumnKey] integerValue], 7, @"The column at index seven should be retrycount");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLTimeCreatedColumnKey] integerValue], 8, @"The column at index eight should be timecreated");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLRequiresIntenetColumnKey] integerValue], 9, @"The column at index nine should be requiresinternet.");
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLMaxNumberOfRetriesKey] integerValue], 10);
		XCTAssertEqual([[set.columnNameToIndexMap objectForKey:kZLShouldHoldAfterMaxRetriesKey] integerValue], 11);
		
		
		XCTAssertFalse(db.shouldCacheStatements, @"The database should not cache statements");
		XCTAssertTrue(db.logsErrors, @"The database should log errors");
		
		[db closeOpenResultSets];
		[db close];
	}];
}
- (void)testGettingNonInitialSharedQueue
{
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	FMDatabaseQueue *secondQueue = [ZLWorkItemDatabase sharedQueue];
	
	XCTAssertEqual(queue, secondQueue, @"After the sharedQueue is initialized it should return the same one instead of reinstiating.");
}

#pragma mark - Test Get WorkItem

- (void)testGetNextWorkItemNoneInDatabase
{
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:nil];
	
	XCTAssertNil(nextWorkItem, @"There are no items in the database, this should have returned nil");
}

- (void)testGetNextWorkItemNoneReady
{
	NSString *taskType = @"taskType";
	for (int i=0; i<10; i++) {
		ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] init];
		workItem.majorPriority = arc4random()%5;
		
		if (arc4random_uniform(2) == 0) {
			workItem.state = ZLWorkItemStateHold;
		} else {
			workItem.state = ZLWorkItemStateExecuting;
		}
		workItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:workItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType]];
	
	XCTAssertNil(nextWorkItem, @"There are no items in the database that have state = ZLInternalWorkItemStateread, this should have returned nil");
}

- (void)testGetNextWorkItemNilTypesParameter
{
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:nil];
	XCTAssertNil(nextWorkItem, @"This should return nil since we provided an nil taskTypes array as the paramenter");
}

- (void)testGetNextWorkItemEmptyTypesParameter
{
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[]];
	XCTAssertNil(nextWorkItem, @"This should return nil since we provided an empty taskTypes array as the paramenter");
}

- (void)testGetNextWorkItemNoneOfType
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType]];
	
	XCTAssertNil(nextWorkItem, @"This should return nil since there are no WorkItems with taskType %@ in the database.", taskType);
}

- (void)testGetNextWorkItemOnlyLowPriorityMatchesType
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *highPriority = [[ZLInternalWorkItem alloc] init];
		highPriority.majorPriority = arc4random()%5;
		highPriority.taskID = @"highPriorityTaskID";
		highPriority.state = ZLWorkItemStateReady;
		highPriority.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:highPriority];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 0;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType]];
	
	XCTAssert([workItemToReturn.taskID isEqualToString:nextWorkItem.taskID], @"This method should have returned the task with ID %@ because it is the only task who's taskType matched with a TaskType in the provided array", workItemToReturn.taskID);
}

- (void)testGetNextWorkItemMultipleTaskTypesRequested
{
	NSString *taskType = @"taskType";
	NSString *taskType2 = @"taskType2";
	NSString *taskType3 = @"taskType3";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *highPriority = [[ZLInternalWorkItem alloc] init];
		highPriority.majorPriority = arc4random()%5;
		highPriority.taskID = @"highPriorityTaskID";
		highPriority.state = ZLWorkItemStateReady;
		highPriority.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:highPriority];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 3;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *workItem2 = [[ZLInternalWorkItem alloc] init];
	workItem2.majorPriority = 2;
	workItem2.taskID = @"dontreturn";
	workItem2.state = ZLWorkItemStateReady;
	workItem2.taskType = taskType2;
	[ZLWorkItemDatabase addNewWorkItem:workItem2];
	
	ZLInternalWorkItem *workItem3 = [[ZLInternalWorkItem alloc] init];
	workItem3.majorPriority = 2;
	workItem3.taskID = @"dontreturn";
	workItem3.state = ZLWorkItemStateReady;
	workItem3.taskType = taskType3;
	[ZLWorkItemDatabase addNewWorkItem:workItem3];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType, taskType2, taskType3]];
	[ZLWorkItemDatabase deleteWorkItem:nextWorkItem];
	
	XCTAssert([workItemToReturn.taskID isEqualToString:nextWorkItem.taskID], @"This method should have returned the task with ID %@ because it is the only task who's taskType matched with a TaskType in the provided array but instead it returned %@", workItemToReturn.taskID, nextWorkItem.taskID);
	
	BOOL stop = NO;
	NSInteger numberReturned = 1;
	while (!stop) {
		nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType, taskType2, taskType3]];
		[ZLWorkItemDatabase deleteWorkItem:nextWorkItem];
		if (!nextWorkItem) {
			stop = YES;
		} else {
			numberReturned++;
		}
	}
	
	XCTAssertEqual(numberReturned, 3, @"We added three workItems to the Database and we quereied for those three taskTypes, so we should get all three back. Instead we go %i back", (int)numberReturned);
}

- (void)testGetNextWorkItemSingleHighestMajorPriority
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

- (void)testGetNextWorkItemMultipleHigestMajorPrioritySingleHighestMinorPriority
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.majorPriority = 5;
		} else {
			lowPriorityWorkItem.majorPriority = arc4random()%5;
		}
		
		lowPriorityWorkItem.minorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.minorPriority = 5;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

- (void)testGetNextWorkItemMultipleHighestMajorPriorityMultipleHighestMinorPrioritySingleLowestRetryCount
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.majorPriority = 5;
		} else {
			lowPriorityWorkItem.majorPriority = arc4random()%5;
		}
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.minorPriority = 5;
		} else {
			lowPriorityWorkItem.minorPriority = arc4random()%5;
		}
		
		lowPriorityWorkItem.retryCount = (arc4random()%4)+1;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.minorPriority = 5;
	workItemToReturn.retryCount = 0;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

- (void)testGetNextWorkItemMultipleHighestMajorPriorityMultipleHighestMinorPriorityMutlipleLowestRetryCountSingleMostRecentlyAdded
{
	NSString *taskType = @"taskType";
	
	double earliestTimeCreated = 8393282.0;
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.majorPriority = 5;
		} else {
			lowPriorityWorkItem.majorPriority = arc4random()%5;
		}
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.minorPriority = 5;
		} else {
			lowPriorityWorkItem.minorPriority = arc4random()%5;
		}
		
		lowPriorityWorkItem.retryCount = (arc4random()%2);
		lowPriorityWorkItem.timeCreated = earliestTimeCreated+0.005;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.minorPriority = 5;
	workItemToReturn.retryCount = 0;
	workItemToReturn.timeCreated = earliestTimeCreated;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.majorPriority = 5;
		} else {
			lowPriorityWorkItem.majorPriority = arc4random()%5;
		}
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.minorPriority = 5;
		} else {
			lowPriorityWorkItem.minorPriority = arc4random()%5;
		}
		
		lowPriorityWorkItem.retryCount = (arc4random()%2);
		lowPriorityWorkItem.timeCreated = earliestTimeCreated+0.005;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

#pragma mark - Test Get WorkItem No Internet

- (void)testGetNextWorkItemNoInternetNoneInDatabase
{
	NSString *taskType = @"taskType";
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertNil(nextWorkItem, @"There are no items in the database, this should have returned nil");
}

- (void)testGetNextWorkItemNoInternetNoneReady
{
	NSString *taskType = @"taskType";
	for (int i=0; i<10; i++) {
		ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] init];
		workItem.majorPriority = arc4random()%5;
		
		if (arc4random_uniform(2) == 0) {
			workItem.state = ZLWorkItemStateHold;
		} else {
			workItem.state = ZLWorkItemStateExecuting;
		}
		workItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:workItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertNil(nextWorkItem, @"There are no items in the database that have state = ZLInternalWorkItemStateread, this should have returned nil");
	
}

- (void)testGetNextWorkNoInternetRequiredItemNilTypesParameter
{
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:nil];
	XCTAssertNil(nextWorkItem, @"This should return nil since we provided an nil taskTypes array as the paramenter");
}

- (void)testGetNextWorkItemNoInternetRequiredEmptyTypesParameter
{
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[]];
	XCTAssertNil(nextWorkItem, @"This should return nil since we provided an empty taskTypes array as the paramenter");
}

- (void)testGetNextWorkItemNoInternetRequiredNoneOfType
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertNil(nextWorkItem, @"This should return nil since there are no WorkItems with taskType %@ in the database.", taskType);
}

- (void)testGetNextWorkItemNoInternetRequiredOnlyLowPriorityMatchesType
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *highPriority = [[ZLInternalWorkItem alloc] init];
		highPriority.majorPriority = arc4random()%5;
		highPriority.taskID = @"highPriorityTaskID";
		highPriority.state = ZLWorkItemStateReady;
		highPriority.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:highPriority];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 0;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssert([workItemToReturn.taskID isEqualToString:nextWorkItem.taskID], @"This method should have returned the task with ID %@ because it is the only task who's taskType matched with a TaskType in the provided array", workItemToReturn.taskID);
}

- (void)testGetNextWorkItemNoInternetRequiredMultipleTaskTypesRequested
{
	NSString *taskType = @"taskType";
	NSString *taskType2 = @"taskType2";
	NSString *taskType3 = @"taskType3";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *highPriority = [[ZLInternalWorkItem alloc] init];
		highPriority.majorPriority = arc4random()%5;
		highPriority.taskID = @"highPriorityTaskID";
		highPriority.state = ZLWorkItemStateReady;
		highPriority.taskType = @"notTaskType";
		[ZLWorkItemDatabase addNewWorkItem:highPriority];
	}
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 3;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *workItem2 = [[ZLInternalWorkItem alloc] init];
	workItem2.majorPriority = 2;
	workItem2.taskID = @"dontreturn";
	workItem2.state = ZLWorkItemStateReady;
	workItem2.taskType = taskType2;
	[ZLWorkItemDatabase addNewWorkItem:workItem2];
	
	ZLInternalWorkItem *workItem3 = [[ZLInternalWorkItem alloc] init];
	workItem3.majorPriority = 2;
	workItem3.taskID = @"dontreturn";
	workItem3.state = ZLWorkItemStateReady;
	workItem3.taskType = taskType3;
	[ZLWorkItemDatabase addNewWorkItem:workItem3];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType, taskType2, taskType3]];
	[ZLWorkItemDatabase deleteWorkItem:nextWorkItem];
	
	XCTAssert([workItemToReturn.taskID isEqualToString:nextWorkItem.taskID], @"This method should have returned the task with ID %@ because it is the only task who's taskType matched with a TaskType in the provided array but instead it returned %@", workItemToReturn.taskID, nextWorkItem.taskID);
	
	BOOL stop = NO;
	NSInteger numberReturned = 1;
	while (!stop) {
		nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType, taskType2, taskType3]];
		[ZLWorkItemDatabase deleteWorkItem:nextWorkItem];
		if (!nextWorkItem) {
			stop = YES;
		} else {
			numberReturned++;
		}
	}
	
	XCTAssertEqual(numberReturned, 3, @"We added three workItems to the Database and we quereied for those three taskTypes, so we should get all three back. Instead we go %i back", (int)numberReturned);
}

- (void)testGetNextWorkItemNoInternetSomeReadyAllRequireInternet
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.requiresInternet = YES;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertNil(nextWorkItem, @"There are no items in the database that have requiresInternet = true, this should have returned nil");
}

- (void)testGetNextWorkItemNoInternetSingleHighestMajorPriority
{
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		lowPriorityWorkItem.majorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.requiresInternet = NO;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *highPriorityButNeedsInternet = [[ZLInternalWorkItem alloc] init];
	highPriorityButNeedsInternet.majorPriority = 6;
	highPriorityButNeedsInternet.taskID = @"needsInternet";
	highPriorityButNeedsInternet.state = ZLWorkItemStateReady;
	highPriorityButNeedsInternet.requiresInternet = YES;
	highPriorityButNeedsInternet.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:highPriorityButNeedsInternet];
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.requiresInternet = NO;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

- (void)testGetNextWorkItemNoInternetMultipleHigestMajorPrioritySingleHighestMinorPriority
{
	NSString *taskType = @"taskType";
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.majorPriority = 5;
		} else {
			lowPriorityWorkItem.majorPriority = arc4random()%5;
		}
		
		lowPriorityWorkItem.minorPriority = arc4random()%5;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.requiresInternet = NO;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *highPriorityButNeedsInternet = [[ZLInternalWorkItem alloc] init];
	highPriorityButNeedsInternet.majorPriority = 5;
	highPriorityButNeedsInternet.minorPriority = 6;
	highPriorityButNeedsInternet.taskID = @"needsInternet";
	highPriorityButNeedsInternet.state = ZLWorkItemStateReady;
	highPriorityButNeedsInternet.requiresInternet = YES;
	highPriorityButNeedsInternet.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:highPriorityButNeedsInternet];
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.minorPriority = 5;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.requiresInternet = NO;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

- (void)testGetNextWorkItemNoInternetMultipleHighestMajorPriorityMultipleHighestMinorPrioritySingleLowestRetryCount
{
	NSString *taskType = @"taskType";
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.majorPriority = 5;
		} else {
			lowPriorityWorkItem.majorPriority = arc4random()%5;
		}
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.minorPriority = 5;
		} else {
			lowPriorityWorkItem.minorPriority = arc4random()%5;
		}
		
		lowPriorityWorkItem.retryCount = (arc4random()%4)+2;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.requiresInternet = NO;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *highPriorityButNeedsInternet = [[ZLInternalWorkItem alloc] init];
	highPriorityButNeedsInternet.majorPriority = 5;
	highPriorityButNeedsInternet.minorPriority = 5;
	highPriorityButNeedsInternet.retryCount = 0;
	highPriorityButNeedsInternet.taskID = @"needsInternet";
	highPriorityButNeedsInternet.state = ZLWorkItemStateReady;
	highPriorityButNeedsInternet.requiresInternet = YES;
	highPriorityButNeedsInternet.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:highPriorityButNeedsInternet];
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.minorPriority = 5;
	workItemToReturn.retryCount = 1;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.requiresInternet = NO;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

- (void)testGetNextWorkItemNoInternetMultipleHighestMajorPriorityMultipleHighestMinorPriorityMutlipleLowestRetryCountSingleMostRecentlyAdded
{
	NSInteger earliestTimeCreated = 8393282;
	NSString *taskType = @"taskType";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *lowPriorityWorkItem = [[ZLInternalWorkItem alloc] init];
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.majorPriority = 5;
		} else {
			lowPriorityWorkItem.majorPriority = arc4random()%5;
		}
		
		if (arc4random()%2==0) {
			lowPriorityWorkItem.minorPriority = 5;
		} else {
			lowPriorityWorkItem.minorPriority = arc4random()%5;
		}
		
		lowPriorityWorkItem.retryCount = (arc4random()%2);
		lowPriorityWorkItem.timeCreated = (arc4random()%10)+earliestTimeCreated+1;
		lowPriorityWorkItem.taskID = @"LowPriorityTaskID";
		lowPriorityWorkItem.state = ZLWorkItemStateReady;
		lowPriorityWorkItem.requiresInternet = NO;
		lowPriorityWorkItem.taskType = taskType;
		[ZLWorkItemDatabase addNewWorkItem:lowPriorityWorkItem];
	}
	
	ZLInternalWorkItem *highPriorityButNeedsInternet = [[ZLInternalWorkItem alloc] init];
	highPriorityButNeedsInternet.majorPriority = 5;
	highPriorityButNeedsInternet.minorPriority = 5;
	highPriorityButNeedsInternet.retryCount = 0;
	highPriorityButNeedsInternet.timeCreated = (double)(earliestTimeCreated-10);
	highPriorityButNeedsInternet.taskID = @"needsInternet";
	highPriorityButNeedsInternet.state = ZLWorkItemStateReady;
	highPriorityButNeedsInternet.requiresInternet = YES;
	highPriorityButNeedsInternet.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:highPriorityButNeedsInternet];
	
	ZLInternalWorkItem *workItemToReturn = [[ZLInternalWorkItem alloc] init];
	workItemToReturn.majorPriority = 5;
	workItemToReturn.minorPriority = 5;
	workItemToReturn.retryCount = 0;
	workItemToReturn.timeCreated = (double)earliestTimeCreated;
	workItemToReturn.taskID = @"workItemToReturnID";
	workItemToReturn.state = ZLWorkItemStateReady;
	workItemToReturn.requiresInternet = NO;
	workItemToReturn.taskType = taskType;
	[ZLWorkItemDatabase addNewWorkItem:workItemToReturn];
	
	ZLInternalWorkItem *nextWorkItem = [ZLWorkItemDatabase getNextWorkItemForNoInternetForTaskTypes:@[taskType]];
	
	XCTAssertTrue([nextWorkItem.taskID isEqualToString:workItemToReturn.taskID], @"The returned workItem should have taskID %@ but has taskID %@ instead", workItemToReturn.taskID, nextWorkItem.taskID);
}

#pragma mark - Test WorkItem Manipulation

- (void)testAddWorkItemSuccess
{
	ZLInternalWorkItem *initialWorkItem = [[ZLInternalWorkItem alloc] init];
	[ZLWorkItemDatabase addNewWorkItem:initialWorkItem];
	
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	
	// Get the initial State of the database. Just the Primary keys before the method call
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	// Execute the method
	ZLInternalWorkItem *workItem = [self createTestWorkItem];
	workItem.shouldHoldAfterMaxRetries = YES;
	
	BOOL success = [ZLWorkItemDatabase addNewWorkItem:workItem];
	
	XCTAssertTrue(success, @"This method should return true if it succeeds.");
	
	// Get the state after the method call. Get the primary keys
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	XCTAssertEqual(initialIDs.count+1, finalIDs.count, @"There should be one more row after the addWorkItem method than before. Initial %lu Final %lu", (unsigned long)initialIDs.count, (unsigned long)finalIDs.count);
	
	// Make sure that all initalIDs are also in finalIDs. Then remove the initialID from the finalIDs array so we can find the new IDs
	NSMutableArray *mutableFinalIDs = [finalIDs mutableCopy];
	
	for (NSNumber *initialRecordID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialRecordID]);
		[mutableFinalIDs removeObject:initialRecordID];
	}
	
	finalIDs = [mutableFinalIDs copy];
	
	XCTAssertTrue(finalIDs.count == 1, @"There should be one and only one recordID left once all the initial IDs have been removed");
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == %@", kZLWorkItemDatabaseTableName, kZLWorkItemIDColumnKey, [finalIDs firstObject]];
		FMResultSet *set = [db executeQuery:query];
		
		XCTAssertTrue([set next], @"The query should have returned at least one row");
		
		//Make sure the actual values for the new row are the same as the workItem we created
		
		XCTAssertTrue([workItem.taskType isEqualToString:[set stringForColumn:kZLTaskTypeColumnKey]], @"The workItem.taskType %@ should equal the value for taskType on the row %@", workItem.taskType, [set stringForColumn:kZLTaskTypeColumnKey]);
		XCTAssertTrue([workItem.taskID isEqualToString:[set stringForColumn:kZLTaskIDColumnKey]], @"The workItem.taskID %@ should equal the value for the taskID on the row %@", workItem.taskID, [set stringForColumn:kZLTaskIDColumnKey]);
		XCTAssertEqual(workItem.state, [set intForColumn:kZLStateColumnKey], @"The workItem.state %i should equal the value for state on the row %i", (int)workItem.state, [set intForColumn:kZLStateColumnKey]);
		XCTAssertTrue([workItem.data isEqualToData:[set dataForColumn:kZLDataColumnKey]], @"The workItem.data should equal the value for data on the row");
		XCTAssertEqual(workItem.majorPriority, [set intForColumn:kZLMajorPriorityColumnKey], @"The workItem.majorPriority %li should equal the value for majorPriority on the row %i", (long)workItem.majorPriority, [set intForColumn:kZLMajorPriorityColumnKey]);
		XCTAssertEqual(workItem.minorPriority, [set intForColumn:kZLMinorPriorityColumnKey], @"The workItem.minorPriority %li should equal the value for minorPriority on the row %i", (long)workItem.minorPriority, [set intForColumn:kZLMinorPriorityColumnKey]);
		XCTAssertEqual(workItem.retryCount, [set intForColumn:kZLRetryCountColumnKey], @"The workItem.retryCount %li should equal the value for the retryCount on the row %i", (long)workItem.retryCount, [set intForColumn:kZLRetryCountColumnKey]);
		XCTAssertEqual(workItem.timeCreated, [set doubleForColumn:kZLTimeCreatedColumnKey], @"The workItem.timeCreated %f should equal the value for timeCreated on the row %f", workItem.timeCreated, [set doubleForColumn:kZLTimeCreatedColumnKey]);
		XCTAssertEqual(workItem.requiresInternet, [set boolForColumn:kZLRequiresIntenetColumnKey], @"The workItem.requiresInternet should equal the value for requiresInternet on the row");
		XCTAssertEqual((int)workItem.maxNumberOfRetries, [set intForColumn:kZLMaxNumberOfRetriesKey]);
		XCTAssertEqual(workItem.shouldHoldAfterMaxRetries, [set boolForColumn:kZLShouldHoldAfterMaxRetriesKey]);
		
		XCTAssertFalse([set next], @"The query should NOT have returned more than one row");
		
		[db closeOpenResultSets];
		[db close];
	}];
}

- (void)testAddWorkItemFailure
{
	[[ZLWorkItemDatabase sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *deleteCommand = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", kZLWorkItemDatabaseTableName];
		
		[db executeUpdate:deleteCommand];
		[db close];
	}];
	
	ZLInternalWorkItem *initialWorkItem = [[ZLInternalWorkItem alloc] init];
	BOOL success = [ZLWorkItemDatabase addNewWorkItem:initialWorkItem];
	
	XCTAssertFalse(success, @"This should return no if the method failed to add the WorkItem.");
}

- (void)testUpdateWorkItemDoesNotExist
{
	
	// In SQLite3 with autoincrementing Primary Keys it's impossible to have a negative value for id
	NSInteger nonExistantID = -1;
	
	ZLInternalWorkItem *testWorkItem = [self createTestWorkItem];
	testWorkItem.recordID = nonExistantID;
	
	XCTAssertFalse([ZLWorkItemDatabase updateWorkItem:testWorkItem]);
}

- (void)testUpdateWorkItemSuccess
{
	NSString *testTaskType = @"Test task typee";
	NSString *testTaskID = @"idididid";
	NSData *testData = [@"This si going to be turned into data" dataUsingEncoding:NSUTF8StringEncoding];
	ZLWorkItemState testState = ZLWorkItemStateExecuting;
	NSInteger testMajorPriority = 123321;
	NSInteger testMinorPriority = 83923784;
	NSInteger testRetryCount = 304;
	double testTimeCreated = 3938493902;
	BOOL testRequiresInternet = YES;
	
	NSInteger maxNumberOfRetries = 234;
	BOOL shouldRestart = YES;
	
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	//Set up the initial state. Insert a test WorkItem into the database which we will later update
	ZLInternalWorkItem *initialWorkItem = [self createTestWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:initialWorkItem];
	
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	ZLInternalWorkItem *workItemToUpdate = [[ZLInternalWorkItem alloc] init];
	workItemToUpdate.recordID = [[initialIDs firstObject] intValue];
	workItemToUpdate.taskType = testTaskType;
	workItemToUpdate.taskID = testTaskID;
	workItemToUpdate.data = testData;
	workItemToUpdate.state = testState;
	workItemToUpdate.majorPriority = testMajorPriority;
	workItemToUpdate.minorPriority = testMinorPriority;
	workItemToUpdate.retryCount = testRetryCount;
	workItemToUpdate.timeCreated = testTimeCreated;
	workItemToUpdate.requiresInternet = testRequiresInternet;
	workItemToUpdate.maxNumberOfRetries = maxNumberOfRetries;
	workItemToUpdate.shouldHoldAfterMaxRetries = shouldRestart;
	
	BOOL success = [ZLWorkItemDatabase updateWorkItem:workItemToUpdate];
	
	XCTAssertTrue(success, @"The operation should return true if it succeeded");
	
	ZLInternalWorkItem *updatedWorkItem = [self getWorkItemFromQueue:queue withID:workItemToUpdate.recordID];
	
	XCTAssertNotNil(updatedWorkItem, @"The initial row with id %li should exist after the update.", (long)workItemToUpdate.recordID);
	
	XCTAssertTrue([updatedWorkItem.taskType isEqualToString:testTaskType], @"The workItem.taskType %@ should equal the value for taskType on the row %@", updatedWorkItem.taskType, testTaskType);
	XCTAssertTrue([updatedWorkItem.taskID isEqualToString:testTaskID], @"The workItem.taskID %@ should equal the value for the taskID on the row %@", updatedWorkItem.taskID, testTaskID);
	XCTAssertEqual(updatedWorkItem.state, testState, @"The workItem.state %i should equal the value for state on the row %i", (int)updatedWorkItem.state, (int)testState);
	XCTAssertTrue([updatedWorkItem.data isEqualToData:testData], @"The workItem.data should equal the value for data on the row");
	XCTAssertEqual(updatedWorkItem.majorPriority, testMajorPriority, @"The workItem.majorPriority %li should equal the value for majorPriority on the row %li", (long)updatedWorkItem.majorPriority, (long)testMajorPriority);
	XCTAssertEqual(updatedWorkItem.minorPriority, testMinorPriority, @"The workItem.minorPriority %li should equal the value for minorPriority on the row %li", (long)updatedWorkItem.minorPriority, (long)testMinorPriority);
	XCTAssertEqual(updatedWorkItem.retryCount, testRetryCount, @"The workItem.retryCount %li should equal the value for the retryCount on the row %li", (long)updatedWorkItem.retryCount, (long)testRetryCount);
	XCTAssertEqual(updatedWorkItem.timeCreated, testTimeCreated, @"The workItem.timeCreated %f should equal the value for timeCreated on the row %f", updatedWorkItem.timeCreated, testTimeCreated);
	XCTAssertEqual(updatedWorkItem.requiresInternet, testRequiresInternet, @"The workItem.requiresInternet should equal the value for requiresInternet on the row");
	XCTAssertEqual(updatedWorkItem.maxNumberOfRetries, maxNumberOfRetries);
	XCTAssertEqual(updatedWorkItem.shouldHoldAfterMaxRetries, shouldRestart);
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	XCTAssertEqual(initialIDs.count, finalIDs.count, @"There should be the same number of rows before and after the operation");
	
	for (NSNumber *initialID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialID], @"Every ID that was initially in the database should still be there afterwards, but %@ is not", initialID);
	}
}

- (void)testUpdateWorkItemFailure
{
	[[ZLWorkItemDatabase sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *deleteCommand = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", kZLWorkItemDatabaseTableName];
		
		[db executeUpdate:deleteCommand];
		[db close];
	}];
	
	ZLInternalWorkItem *initialWorkItem = [[ZLInternalWorkItem alloc] init];
	BOOL success = [ZLWorkItemDatabase updateWorkItem:initialWorkItem];
	
	XCTAssertFalse(success, @"This should return no if the method failed to add the WorkItem.");
}

- (void)testDeleteWorkItem
{
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	
	// Set up some initial values
	ZLInternalWorkItem *initialWorkItem = [self createTestWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:initialWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:initialWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:initialWorkItem];
	
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	ZLInternalWorkItem *workItemToDelete = [self getWorkItemFromQueue:queue withID:[[initialIDs firstObject] integerValue]];
	[ZLWorkItemDatabase deleteWorkItem:workItemToDelete];
	
	ZLInternalWorkItem *deletedWorkItem = [self getWorkItemFromQueue:queue withID:workItemToDelete.recordID];
	
	XCTAssertNil(deletedWorkItem, @"There should NO WorkItem for recordID %i after it has been deleted", (int)workItemToDelete.recordID);
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	XCTAssertEqual(initialIDs.count-1, finalIDs.count, @"The final count of IDs %i should be one less than the initial count %i", (int)initialIDs.count, (int)finalIDs.count);
	
	for (NSNumber *finalID in finalIDs) {
		XCTAssertTrue([initialIDs containsObject:finalID], @"All the final IDs should match up to an initialID %@ is not", finalID);
	}
	
}

#pragma mark - Test Group WorkItem Manipulation

- (void)testDeleteWorkItemsWithTaskType
{
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	// Set up the initial state of the database
	NSInteger numberOfItems = ((arc4random()%5)+1)*10;
	NSInteger numberThatShouldBeDeleted = 0;
	NSString *typeToDelete = @"typeToDelete";
	
	for (int i=0; i<numberOfItems; i++) {
		ZLInternalWorkItem *workItem = [self createTestWorkItem];
		
		if ((arc4random()%2)==0) {
			workItem.taskType = typeToDelete;
			numberThatShouldBeDeleted++;
		} else {
			workItem.taskType = @"typeToNotDelete";
		}
		
		[ZLWorkItemDatabase addNewWorkItem:workItem];
	}
	
	[ZLWorkItemDatabase deleteWorkItemsWithTaskType:typeToDelete];
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	XCTAssertEqual(numberOfItems-numberThatShouldBeDeleted, finalIDs.count, @"There should be %i of items in the database after the operation but there are %i", (int)(numberOfItems-numberThatShouldBeDeleted), (int)finalIDs.count);
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?", kZLWorkItemDatabaseTableName, kZLTaskTypeColumnKey];
		FMResultSet *set = [db executeQuery:query, typeToDelete];
		
		XCTAssertFalse([set next], @"There should be no rows that have taskType %i after the operation", (int)typeToDelete);
		
		[db closeOpenResultSets];
		[db close];
	}];
	
}

- (void)testChangePriorityOfTaskType
{
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	// Set up the initial database state
	NSString *typeToChange = @"typeToChange";
	NSInteger newMajorPriority = 4;
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] init];
		workItem.majorPriority = arc4random()%5;
		workItem.minorPriority = arc4random()%5;
		
		workItem.state = ZLWorkItemStateReady;
		[ZLWorkItemDatabase addNewWorkItem:workItem];
		
		if ((arc4random()%2)==0) {
			workItem.taskType = typeToChange;
		} else {
			workItem.taskType = @"typeToNotChange";
		}
	}
	
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	[ZLWorkItemDatabase changePriorityOfTaskType:typeToChange newMajorPriority:newMajorPriority];
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@=?", kZLWorkItemDatabaseTableName, kZLTaskTypeColumnKey];
		FMResultSet *set = [db executeQuery:query, typeToChange];
		
		while ([set next]) {
			XCTAssertEqual([set intForColumn:kZLMajorPriorityColumnKey], newMajorPriority, @"All rows with taskType %i should have a majorPriority of %i but this one has majorPriority of %i instead", (int)typeToChange, (int)newMajorPriority, [set intForColumn:kZLMajorPriorityColumnKey]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	// Make sure the database state is the same before as it is after
	XCTAssertEqual(initialIDs.count, finalIDs.count, @"This method should not have changed the database at all. However, the initial count %i is not equal to the final count %i of IDs", (int)initialIDs.count, (int)finalIDs.count);
	
	for (NSNumber *initialID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialID], @"Every ID that was initially in the database should still be there afterwards, but %@ is not", initialID);
	}
	for (NSNumber *finalID in finalIDs) {
		XCTAssertTrue([initialIDs containsObject:finalID], @"All the final IDs should match up to an initialID %@ is not", finalID);
	}
}

- (void)testRestartHoldingTasks
{
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	// Set up the initial database state
	NSString *readyType = @"ready";
	NSString *executingType = @"executing";
	NSString *holdType = @"hold";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] init];
		workItem.retryCount = arc4random_uniform(100)+1;
		
		int random = arc4random_uniform(3);
		if (random == 0) {
			workItem.state = ZLWorkItemStateReady;
			workItem.taskType = readyType;
		} else if (random == 1) {
			workItem.state = ZLWorkItemStateExecuting;
			workItem.taskType = executingType;
		} else if (random == 2) {
			workItem.state = ZLWorkItemStateHold;
			workItem.taskType = holdType;
		}
		
		[ZLWorkItemDatabase addNewWorkItem:workItem];
	}
	
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	[ZLWorkItemDatabase restartHoldingTasks];
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@", kZLWorkItemDatabaseTableName];
		FMResultSet *set = [db executeQuery:query];
		
		while ([set next]) {
			NSString *taskType = [set stringForColumn:kZLTaskTypeColumnKey];
			int state = [set intForColumn:kZLStateColumnKey];
			int retryCount = [set intForColumn:kZLRetryCountColumnKey];
			
			
			if ([taskType isEqualToString:readyType]) {
				XCTAssertEqual(state, ZLWorkItemStateReady);
				XCTAssertNotEqual(retryCount, 0);
			} else if ([taskType isEqualToString:executingType]) {
				XCTAssertEqual(state, ZLWorkItemStateExecuting);
				XCTAssertNotEqual(retryCount, 0);
			} else if ([taskType isEqualToString:holdType]) {
				XCTAssertEqual(state, ZLWorkItemStateReady);
				XCTAssertEqual(retryCount, 0);
			} else {
				XCTFail(@"Unrecognized type %@", taskType);
			}
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	// Make sure the database state is the same before as it is after
	XCTAssertEqual(initialIDs.count, finalIDs.count, @"This method should not have changed the database at all. However, the initial count %i is not equal to the final count %i of IDs", (int)initialIDs.count, (int)finalIDs.count);
	
	for (NSNumber *initialID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialID], @"Every ID that was initially in the database should still be there afterwards, but %@ is not", initialID);
	}
	for (NSNumber *finalID in finalIDs) {
		XCTAssertTrue([initialIDs containsObject:finalID], @"All the final IDs should match up to an initialID %@ is not", finalID);
	}
}

- (void)testRestartExecutingTasks
{
	FMDatabaseQueue *queue = [ZLWorkItemDatabase sharedQueue];
	// Set up the initial database state
	NSString *readyType = @"ready";
	NSString *executingType = @"executing";
	NSString *holdType = @"hold";
	
	for (int i=0; i<50; i++) {
		ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] init];
		workItem.retryCount = arc4random_uniform(100)+1;
		
		int random = arc4random_uniform(3);
		if (random == 0) {
			workItem.state = ZLWorkItemStateReady;
			workItem.taskType = readyType;
		} else if (random == 1) {
			workItem.state = ZLWorkItemStateExecuting;
			workItem.taskType = executingType;
		} else if (random == 2) {
			workItem.state = ZLWorkItemStateHold;
			workItem.taskType = holdType;
		}
		
		[ZLWorkItemDatabase addNewWorkItem:workItem];
	}
	
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	[ZLWorkItemDatabase restartExecutingTasks];
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@", kZLWorkItemDatabaseTableName];
		FMResultSet *set = [db executeQuery:query];
		
		while ([set next]) {
			NSString *taskType = [set stringForColumn:kZLTaskTypeColumnKey];
			int state = [set intForColumn:kZLStateColumnKey];
			int retryCount = [set intForColumn:kZLRetryCountColumnKey];
			
			
			if ([taskType isEqualToString:readyType]) {
				XCTAssertEqual(state, ZLWorkItemStateReady);
				XCTAssertNotEqual(retryCount, 0);
			} else if ([taskType isEqualToString:executingType]) {
				XCTAssertEqual(state, ZLWorkItemStateReady);
				XCTAssertNotEqual(retryCount, 0);
			} else if ([taskType isEqualToString:holdType]) {
				XCTAssertEqual(state, ZLWorkItemStateHold);
				XCTAssertNotEqual(retryCount, 0);
			} else {
				XCTFail(@"Unrecognized type %@", taskType);
			}
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:queue];
	
	// Make sure the database state is the same before as it is after
	XCTAssertEqual(initialIDs.count, finalIDs.count, @"This method should not have changed the database at all. However, the initial count %i is not equal to the final count %i of IDs", (int)initialIDs.count, (int)finalIDs.count);
	
	for (NSNumber *initialID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialID], @"Every ID that was initially in the database should still be there afterwards, but %@ is not", initialID);
	}
	for (NSNumber *finalID in finalIDs) {
		XCTAssertTrue([initialIDs containsObject:finalID], @"All the final IDs should match up to an initialID %@ is not", finalID);
	}
}

#pragma mark - Test Information

- (void)testCountOfWorkItemsWithTaskTypeNoItemsInDatabase
{
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	NSInteger count = [ZLWorkItemDatabase countOfWorkItemsWithTaskType:@"anyType"];
	
	XCTAssertEqual(count, 0, @"We didn't put an items in the database so we should get zero for this test.");
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	XCTAssertEqual(initialIDs.count, finalIDs.count, @"This method should not have changed the database at all. However, the initial count %i is not equal to the final count %i of IDs", (int)initialIDs.count, (int)finalIDs.count);
	
	for (NSNumber *initialID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialID], @"Every ID that was initially in the database should still be there afterwards, but %@ is not", initialID);
	}
	for (NSNumber *finalID in finalIDs) {
		XCTAssertTrue([initialIDs containsObject:finalID], @"All the final IDs should match up to an initialID %@ is not", finalID);
	}
}

- (void)testCountOfWorkItemsWithTaskTypeMultipleItemsInDatabaseNoItemsOfTaskType
{
	// Set up the initial values
	
	ZLInternalWorkItem *testWorkItem = [[ZLInternalWorkItem alloc] init];
	testWorkItem.taskType = @"anyType";
	[ZLWorkItemDatabase addNewWorkItem:testWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:testWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:testWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:testWorkItem];
	
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	NSInteger count = [ZLWorkItemDatabase countOfWorkItemsWithTaskType:@"notTheSameType"];
	
	XCTAssertEqual(count, 0, @"We put no items of type ZLInternalWorkItemTaskGetBundle so we should get zero for this method but we got %i", (int)count);
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	XCTAssertEqual(initialIDs.count, finalIDs.count, @"This method should not have changed the database at all. However, the initial count %i is not equal to the final count %i of IDs", (int)initialIDs.count, (int)finalIDs.count);
	
	for (NSNumber *initialID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialID], @"Every ID that was initially in the database should still be there afterwards, but %@ is not", initialID);
	}
	for (NSNumber *finalID in finalIDs) {
		XCTAssertTrue([initialIDs containsObject:finalID], @"All the final IDs should match up to an initialID %@ is not", finalID);
	}
}

- (void)testCountOfWorkitemsWithTaskTypeMultipleItemsInDatabaseMultipleItemsOfTaskType
{
	NSString *bundleType = @"bundleType";
	NSString *parseType = @"parseType";
	// Set up the initial values
	NSInteger actualNumber = 7;
	ZLInternalWorkItem *bundleWorkItem = [[ZLInternalWorkItem alloc] init];
	bundleWorkItem.taskType = bundleType;
	
	ZLInternalWorkItem *versionWorkItem = [[ZLInternalWorkItem alloc] init];
	versionWorkItem.taskType = parseType;
	
	[ZLWorkItemDatabase addNewWorkItem:bundleWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:bundleWorkItem];
	[ZLWorkItemDatabase addNewWorkItem:bundleWorkItem];
	
	for (int i=0; i<actualNumber;i++) {
		[ZLWorkItemDatabase addNewWorkItem:versionWorkItem];
	}
	
	NSArray *initialIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	NSInteger count = [ZLWorkItemDatabase countOfWorkItemsWithTaskType:parseType];
	
	XCTAssertEqual(actualNumber, count, @"The number of ZLInternalWorkItemTaskParseVersion workItems we put in %i should equal the count %i", (int)actualNumber, (int)count);
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	XCTAssertEqual(initialIDs.count, finalIDs.count, @"This method should not have changed the database at all. However, the initial count %i is not equal to the final count %i of IDs", (int)initialIDs.count, (int)finalIDs.count);
	
	for (NSNumber *initialID in initialIDs) {
		XCTAssertTrue([finalIDs containsObject:initialID], @"Every ID that was initially in the database should still be there afterwards, but %@ is not", initialID);
	}
	for (NSNumber *finalID in finalIDs) {
		XCTAssertTrue([initialIDs containsObject:finalID], @"All the final IDs should match up to an initialID %@ is not", finalID);
	}
}

#pragma mark - Test Reset

- (void)testResetDatabase
{
	ZLInternalWorkItem *testWorkItem = [self createTestWorkItem];
	NSInteger count = arc4random()%20;
	count++;
	
	for (int i=0; i<count; i++) {
		[ZLWorkItemDatabase addNewWorkItem:testWorkItem];
	}
	
	[ZLWorkItemDatabase resetDatabase];
	
	NSArray *finalIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	XCTAssertEqual(finalIDs.count, 0, @"The number of IDs (rows) after a reset should ALWAYS be zero. Instead it is %i", (int)finalIDs.count);
}

#pragma mark - Get State

- (void)testGetDatabaseState
{
	NSInteger numberOfItemsToPutInDatabase = arc4random()%50;
	numberOfItemsToPutInDatabase++;
	
	for (int i=0; i<numberOfItemsToPutInDatabase; i++) {
		ZLInternalWorkItem *workItem = [self createTestWorkItem];
		[ZLWorkItemDatabase addNewWorkItem:workItem];
	}
	
	NSArray *databaseState = [ZLWorkItemDatabase getDatabaseState];
	
	NSArray *recordIDs = [self getCurrentWorkItemIDsInQueue:[ZLWorkItemDatabase sharedQueue]];
	
	for (NSNumber *recordID in recordIDs) {
		ZLInternalWorkItem *workItem = [self getWorkItemFromQueue:[ZLWorkItemDatabase sharedQueue] withID:[recordID integerValue]];
		
		NSArray *results = [databaseState filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", kZLWorkItemIDColumnKey, [NSNumber numberWithInteger:workItem.recordID]]];
		
		XCTAssertEqual(results.count, 1, @"There should be one and only one dictionary for each recordID, there was %i", (int)results.count);
		NSDictionary *dictionaryForWorkItem = [results firstObject];
		
		XCTAssertTrue([[dictionaryForWorkItem objectForKey:kZLTaskTypeColumnKey] isEqualToString:workItem.taskType], @"The dbState taskType %@ does not equal the workItem taskType %@", [dictionaryForWorkItem objectForKey:kZLTaskTypeColumnKey], workItem.taskType);
		XCTAssertTrue([[dictionaryForWorkItem objectForKey:kZLTaskIDColumnKey] isEqualToString:workItem.taskID], @"The dbState taskID %@ does not match the workItem taskID %@",[dictionaryForWorkItem objectForKey:kZLTaskIDColumnKey], workItem.taskID);
		
		NSString *stringFromWorkItemData = [[NSString alloc] initWithData:workItem.data encoding:NSUTF8StringEncoding];
		
		XCTAssertTrue([[dictionaryForWorkItem objectForKey:kZLDataColumnKey] isEqualToString:stringFromWorkItemData], @"The UTF encoded string that represents the data in dbState %@ does not equal the workItem equivalent %@", [dictionaryForWorkItem objectForKey:kZLDataColumnKey], stringFromWorkItemData);
		
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLStateColumnKey] integerValue], workItem.state, @"The dbState state %@ does not equal the workItem state %i", [dictionaryForWorkItem objectForKey:kZLStateColumnKey], (int)workItem.state);
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLMajorPriorityColumnKey] integerValue], workItem.majorPriority, @"The dbState majorPriority %@ does not equal the workItem majorPriority %i", [dictionaryForWorkItem objectForKey:kZLMajorPriorityColumnKey], (int)workItem.majorPriority);
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLMinorPriorityColumnKey] integerValue], workItem.minorPriority, @"The dbState minorPriority %@ does not equal the workItem minorPriority %i", [dictionaryForWorkItem objectForKey:kZLMinorPriorityColumnKey], (int)workItem.minorPriority);
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLRetryCountColumnKey] integerValue], workItem.retryCount, @"The dbState retryCount %@ does not equal the workItem retryCount %i", [dictionaryForWorkItem objectForKey:kZLRetryCountColumnKey], (int)workItem.retryCount);
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLTimeCreatedColumnKey] doubleValue], workItem.timeCreated, @"The dbState timeCreated %@ does not equal the workItem timeCreated %i", [dictionaryForWorkItem objectForKey:kZLTimeCreatedColumnKey], (int)workItem.timeCreated);
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLRequiresIntenetColumnKey] boolValue], workItem.requiresInternet, @"The dbState requiresInternet does not equal the workItem requiresInternet");
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLMaxNumberOfRetriesKey] integerValue], workItem.maxNumberOfRetries);
		XCTAssertEqual([[dictionaryForWorkItem objectForKey:kZLShouldHoldAfterMaxRetriesKey] boolValue], workItem.shouldHoldAfterMaxRetries);
		
	}
}

#pragma mark - Helpers

- (ZLInternalWorkItem *)createTestWorkItem
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
	
	NSInteger maxRetry = arc4random_uniform(100);
	BOOL shouldRestart = arc4random_uniform(2);
	
	
	if (arc4random()%2 == 0) {
		testRequiresInternet = YES;
	}
	
	// Execute the method
	ZLInternalWorkItem *workItem = [[ZLInternalWorkItem alloc] init];
	workItem.taskType = testTaskType;
	workItem.taskID = testTaskID;
	workItem.state = testState;
	workItem.data = testData;
	workItem.majorPriority = testMajorPriority;
	workItem.minorPriority = testMinorPriority;
	workItem.retryCount = testRetryCount;
	workItem.timeCreated = testTimeCreated;
	workItem.requiresInternet = testRequiresInternet;
	workItem.maxNumberOfRetries = maxRetry;
	
	workItem.shouldHoldAfterMaxRetries = shouldRestart;
	
	return workItem;
}

- (NSArray *)getCurrentWorkItemIDsInQueue:(FMDatabaseQueue *)queue
{
	__block NSArray *workItemIDs;
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@", kZLWorkItemDatabaseTableName];
		FMResultSet *set = [db executeQuery:query];
		
		NSMutableArray *mutableIDArray = [NSMutableArray new];
		
		while ([set next]) {
			[mutableIDArray addObject:[NSNumber numberWithInt:[set intForColumn:kZLWorkItemIDColumnKey]]];
		}
		
		workItemIDs = [mutableIDArray copy];
		[db closeOpenResultSets];
		[db close];
	}];
	return workItemIDs;
}

- (ZLInternalWorkItem *)getWorkItemFromQueue:(FMDatabaseQueue *)queue withID:(NSInteger)recordID
{
	__block ZLInternalWorkItem *anyWorkItem = nil;
	
	[queue inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == %i", kZLWorkItemDatabaseTableName, kZLWorkItemIDColumnKey, (int)recordID];
		FMResultSet *resultSet = [db executeQuery:query];
		
		if ([resultSet next]) {
			anyWorkItem = [[ZLInternalWorkItem alloc] init];
			anyWorkItem.recordID = [resultSet intForColumn:kZLWorkItemIDColumnKey];
			anyWorkItem.taskType = [resultSet stringForColumn:kZLTaskTypeColumnKey];
			anyWorkItem.taskID = [resultSet stringForColumn:kZLTaskIDColumnKey];
			anyWorkItem.state = [resultSet intForColumn:kZLStateColumnKey];
			anyWorkItem.data = [resultSet dataForColumn:kZLDataColumnKey];
			anyWorkItem.majorPriority = [resultSet intForColumn:kZLMajorPriorityColumnKey];
			anyWorkItem.minorPriority = [resultSet intForColumn:kZLMinorPriorityColumnKey];
			anyWorkItem.retryCount = [resultSet intForColumn:kZLRetryCountColumnKey];
			anyWorkItem.timeCreated = [resultSet doubleForColumn:kZLTimeCreatedColumnKey];
			anyWorkItem.requiresInternet = [resultSet boolForColumn:kZLRequiresIntenetColumnKey];
			anyWorkItem.maxNumberOfRetries = [resultSet intForColumn:kZLMaxNumberOfRetriesKey];
			anyWorkItem.shouldHoldAfterMaxRetries = [resultSet boolForColumn:kZLShouldHoldAfterMaxRetriesKey];
		}
		[db closeOpenResultSets];
		[db close];
	}];
	
	return anyWorkItem;
}

@end
