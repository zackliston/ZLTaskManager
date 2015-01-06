//
//  ZLWorkItemDatabase.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLWorkItemDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
#import "ZLWorkItemDatabaseConstants.h"
#import "ZLInternalWorkItem.h"

static FMDatabaseQueue *_sharedQueue = nil;

@implementation ZLWorkItemDatabase

#pragma mark - Initialization

+ (FMDatabaseQueue *)sharedQueue
{
	if (!_sharedQueue) {
		NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
		NSString *path = [[NSString alloc] initWithString:[cachesDirectory stringByAppendingPathComponent:kZLWorkItemDatabaseLocation]];
		
		_sharedQueue = [[FMDatabaseQueue alloc] initWithPath:path flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE];
		
		[_sharedQueue inDatabase:^(FMDatabase *db) {
			[db open];
			[self createTablesForDatabase:db];
			[db closeOpenResultSets];
			[db close];
		}];
		[_sharedQueue close];
	}
	
	return _sharedQueue;
}

#pragma mark - Public Methods
#pragma mark Getting WorkItems

+ (ZLInternalWorkItem *)getNextWorkItemForTaskTypes:(NSArray *)types
{
	__block ZLInternalWorkItem *nextWorkItem = nil;
	
	if (!types || types.count == 0) {
		return nextWorkItem;
	}
	
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *stringWithCorrectNumberOfQuestionMarks = [self createQueryStringForArray:types];
		NSString *getNextQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == %i AND %@ IN %@ ORDER BY %@ DESC, %@ DESC, %@, %@ LIMIT 1", kZLWorkItemDatabaseTableName, kZLStateColumnKey, (int)ZLWorkItemStateReady, kZLTaskTypeColumnKey, stringWithCorrectNumberOfQuestionMarks, kZLMajorPriorityColumnKey, kZLMinorPriorityColumnKey, kZLRetryCountColumnKey, kZLTimeCreatedColumnKey];
		
		FMResultSet *resultSet = [db executeQuery:getNextQuery withArgumentsInArray:types];
		
		if ([resultSet next]) {
			nextWorkItem = [[ZLInternalWorkItem alloc] initWithResultSet:resultSet];
		}
		
		if ([db hadError]) {
			NSLog(@"Error getting the next workItem %@", [db lastErrorMessage]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	return nextWorkItem;
}

+ (ZLInternalWorkItem *)getNextWorkItemForNoInternetForTaskTypes:(NSArray *)types
{
	__block ZLInternalWorkItem *nextWorkItem = nil;
	
	if (!types || types.count == 0) {
		return nextWorkItem;
	}
	
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *stringWithCorrectNumberOfQuestionMarks = [self createQueryStringForArray:types];
		NSString *getNextQuery = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == %i AND %@ == %i AND %@ IN %@ ORDER BY %@ DESC, %@ DESC, %@, %@ LIMIT 1", kZLWorkItemDatabaseTableName, kZLStateColumnKey, (int)ZLWorkItemStateReady, kZLRequiresIntenetColumnKey, (int)NO, kZLTaskTypeColumnKey, stringWithCorrectNumberOfQuestionMarks, kZLMajorPriorityColumnKey, kZLMinorPriorityColumnKey, kZLRetryCountColumnKey, kZLTimeCreatedColumnKey];
		
		FMResultSet *resultSet = [db executeQuery:getNextQuery withArgumentsInArray:types];
		
		if ([resultSet next]) {
			nextWorkItem = [[ZLInternalWorkItem alloc] initWithResultSet:resultSet];
		}
		
		if ([db hadError]) {
			NSLog(@"Error getting the next workItem %@", [db lastErrorMessage]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	return nextWorkItem;
}

#pragma mark Manipulating WorkItems

+ (BOOL)addNewWorkItem:(ZLInternalWorkItem *)workItem
{
	__block BOOL success = NO;
	
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *insertString = [NSString stringWithFormat:@"insert into %@ (%@, %@, %@, %@, %@, %@, %@, %@, %@, %@, %@) values(?,?,?,?,?,?,?,?,?,?,?)", kZLWorkItemDatabaseTableName, kZLTaskTypeColumnKey, kZLTaskIDColumnKey, kZLStateColumnKey, kZLDataColumnKey, kZLMajorPriorityColumnKey, kZLMinorPriorityColumnKey, kZLRetryCountColumnKey, kZLTimeCreatedColumnKey, kZLRequiresIntenetColumnKey, kZLMaxNumberOfRetriesKey, kZLShouldHoldAfterMaxRetriesKey];
		
		[db executeUpdate:insertString, workItem.taskType, workItem.taskID, [NSNumber numberWithInteger:workItem.state], workItem.data, [NSNumber numberWithInteger:workItem.majorPriority], [NSNumber numberWithInteger:workItem.minorPriority], [NSNumber numberWithInteger:workItem.retryCount], [NSNumber numberWithDouble:workItem.timeCreated], [NSNumber numberWithBool:workItem.requiresInternet], [NSNumber numberWithInteger:workItem.maxNumberOfRetries], [NSNumber numberWithBool:workItem.shouldHoldAfterMaxRetries]];
		
		if ([db hadError]) {
			NSLog(@"Error adding workItem with taskID %@ %@", workItem.taskID, [db lastErrorMessage]);
			success = NO;
		} else {
			success = YES;
		}
		[db closeOpenResultSets];
		[db close];
	}];
	
	return success;
}

+ (BOOL)updateWorkItem:(ZLInternalWorkItem *)workItem
{
	// First, make sure that the WorkItem actually exists in the database
	__block BOOL workItemDoesExists = NO;
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ == %i", kZLWorkItemDatabaseTableName, kZLWorkItemIDColumnKey, (int)workItem.recordID];
		FMResultSet *resultSet = [db executeQuery:query];
		
		workItemDoesExists = [resultSet next];
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	if (!workItemDoesExists) {
		return workItemDoesExists;
	}
	
	__block BOOL hadError = NO;
	// Now actually update the row
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *updateCommand = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=?, %@=? WHERE %@=?", kZLWorkItemDatabaseTableName, kZLTaskTypeColumnKey, kZLTaskIDColumnKey, kZLDataColumnKey, kZLStateColumnKey, kZLMajorPriorityColumnKey, kZLMinorPriorityColumnKey, kZLRetryCountColumnKey, kZLTimeCreatedColumnKey, kZLRequiresIntenetColumnKey, kZLMaxNumberOfRetriesKey, kZLShouldHoldAfterMaxRetriesKey, kZLWorkItemIDColumnKey];
		
		[db executeUpdate:updateCommand, workItem.taskType, workItem.taskID, workItem.data, [NSNumber numberWithInteger:workItem.state], [NSNumber numberWithInteger:workItem.majorPriority], [NSNumber numberWithInteger:workItem.minorPriority], [NSNumber numberWithInteger:workItem.retryCount], [NSNumber numberWithDouble:workItem.timeCreated], [NSNumber numberWithBool:workItem.requiresInternet], [NSNumber numberWithInteger:workItem.maxNumberOfRetries], [NSNumber numberWithBool:workItem.shouldHoldAfterMaxRetries], [NSNumber numberWithInteger:workItem.recordID]];
		
		if (db.hadError) {
			hadError = YES;
			NSLog(@"Error updating WorkItem with recordID %i %@", (int)workItem.recordID, [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	return !hadError;
}

+ (void)deleteWorkItem:(ZLInternalWorkItem *)workItem
{
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		
		NSString *deleteCommand = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = %i", kZLWorkItemDatabaseTableName, kZLWorkItemIDColumnKey, (int)workItem.recordID];
		[db executeUpdate:deleteCommand];
		
		if (db.hadError) {
			NSLog(@"Error deleting WorkItem with recordID %i %@", (int)workItem.recordID, [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
}

#pragma mark Manipulating Groups of WorkItems

+ (void)deleteWorkItemsWithTaskType:(NSString *)taskType
{
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		
		NSString *deleteCommand = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@=?", kZLWorkItemDatabaseTableName, kZLTaskTypeColumnKey];
		[db executeUpdate:deleteCommand, taskType];
		
		if (db.hadError) {
			NSLog(@"Error deleting WorkItems with taskType %@ %@", taskType, [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
}

+ (void)changePriorityOfTaskType:(NSString *)taskType newMajorPriority:(NSInteger)newMajorPriority
{
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *updateCommand = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?", kZLWorkItemDatabaseTableName, kZLMajorPriorityColumnKey, kZLTaskTypeColumnKey];
		
		[db executeUpdate:updateCommand, [NSNumber numberWithInteger:newMajorPriority], taskType];
		
		if (db.hadError) {
			NSLog(@"Error changing priority of WorkItems with taskType %@ to majorPriority %i %@", taskType, (int)newMajorPriority, [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
}

+ (void)restartHoldingTasks
{
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *updateCommand = [NSString stringWithFormat:@"UPDATE %@ SET %@=?, %@=? WHERE %@=?", kZLWorkItemDatabaseTableName, kZLStateColumnKey, kZLRetryCountColumnKey, kZLStateColumnKey];
		
		[db executeUpdate:updateCommand, [NSNumber numberWithInteger:ZLWorkItemStateReady], [NSNumber numberWithInteger:0], [NSNumber numberWithInteger:ZLWorkItemStateHold]];
		
		if (db.hadError) {
			NSLog(@"Error restarting holding tasks %@", [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
}

+ (void)restartExecutingTasks
{
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *updateCommand = [NSString stringWithFormat:@"UPDATE %@ SET %@=? WHERE %@=?", kZLWorkItemDatabaseTableName, kZLStateColumnKey, kZLStateColumnKey];
		
		[db executeUpdate:updateCommand, [NSNumber numberWithInteger:ZLWorkItemStateReady], [NSNumber numberWithInteger:ZLWorkItemStateExecuting]];
		
		if (db.hadError) {
			NSLog(@"Error restarting holding tasks %@", [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
}

#pragma mark Information

+ (NSInteger)countOfWorkItemsWithTaskType:(NSString *)taskType
{
	__block NSInteger count = 0;
	
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *countQueryString = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@=?", kZLWorkItemDatabaseTableName, kZLTaskTypeColumnKey];
		
		FMResultSet *resultSet = [db executeQuery:countQueryString, taskType];
		
		while ([resultSet next]) {
			count = [resultSet intForColumnIndex:0];
		}
		
		if (db.hadError) {
			NSLog(@"Error counting WorkItems with taskType %@ %@", taskType, [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	return count;
}

+ (NSInteger)countOfWorkItemsNotHolding
{
	__block NSInteger count = 0;
	
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *countQueryString = [NSString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE %@!=?", kZLWorkItemDatabaseTableName, kZLStateColumnKey];
		
		FMResultSet *resultSet = [db executeQuery:countQueryString, [NSNumber numberWithInteger:ZLWorkItemStateHold]];
		
		while ([resultSet next]) {
			count = [resultSet intForColumnIndex:0];
		}
		
		if (db.hadError) {
			NSLog(@"Error counting WorkItems %@", [db lastError]);
		}
		
		[db closeOpenResultSets];
		[db close];
	}];
	
	return count;
}

#pragma mark - Wipe Database

+ (void)resetDatabase
{
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *deleteCommand = [NSString stringWithFormat:@"DELETE FROM %@", kZLWorkItemDatabaseTableName];
		
		[db executeUpdate:deleteCommand];
		
		if (db.hadError) {
			NSLog(@"Error resetting database %@", [db lastError]);
		}
		[db closeOpenResultSets];
		[db close];
	}];
}

#pragma mark - Database State

+ (NSArray *)getDatabaseState
{
	__block NSMutableArray *mutableState = [NSMutableArray new];
	
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *selectCommand = [NSString stringWithFormat:@"SELECT * FROM %@", kZLWorkItemDatabaseTableName];
		
		FMResultSet *resultSet = [db executeQuery:selectCommand];
		
		while ([resultSet next]) {
			NSMutableDictionary *dictionaryRepresentationOfRow = [NSMutableDictionary new];
			
			id taskType = ([resultSet stringForColumn:kZLTaskTypeColumnKey]) ? [resultSet stringForColumn:kZLTaskTypeColumnKey] : [NSNull null];
			id taskId = ([resultSet stringForColumn:kZLTaskIDColumnKey]) ? [resultSet stringForColumn:kZLTaskIDColumnKey] : [NSNull null];
			
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithInt:[resultSet intForColumn:kZLWorkItemIDColumnKey]] forKey:kZLWorkItemIDColumnKey];
			[dictionaryRepresentationOfRow setObject:taskType forKey:kZLTaskTypeColumnKey];
			[dictionaryRepresentationOfRow setObject:taskId forKey:kZLTaskIDColumnKey];
			
			NSString *stringRepresentationOfData = [[NSString alloc] initWithData:[resultSet dataForColumn:kZLDataColumnKey] encoding:NSUTF8StringEncoding];
			[dictionaryRepresentationOfRow setObject:stringRepresentationOfData forKey:kZLDataColumnKey];
			
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithInt:[resultSet intForColumn:kZLStateColumnKey]] forKey:kZLStateColumnKey];
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithInt:[resultSet intForColumn:kZLMajorPriorityColumnKey]] forKey:kZLMajorPriorityColumnKey];
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithInt:[resultSet intForColumn:kZLMinorPriorityColumnKey]] forKey:kZLMinorPriorityColumnKey];
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithInt:[resultSet intForColumn:kZLRetryCountColumnKey]] forKey:kZLRetryCountColumnKey];
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithDouble:[resultSet doubleForColumn:kZLTimeCreatedColumnKey]] forKey:kZLTimeCreatedColumnKey];
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithBool:[resultSet boolForColumn:kZLRequiresIntenetColumnKey]] forKey:kZLRequiresIntenetColumnKey];
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithInt:[resultSet intForColumn:kZLMaxNumberOfRetriesKey]] forKey:kZLMaxNumberOfRetriesKey];
			[dictionaryRepresentationOfRow setObject:[NSNumber numberWithBool:[resultSet boolForColumn:kZLShouldHoldAfterMaxRetriesKey]] forKey:kZLShouldHoldAfterMaxRetriesKey];
			[mutableState addObject:[dictionaryRepresentationOfRow copy]];
		}
		
		if (db.hadError) {
			NSLog(@"Error getting state from database %@", [db lastError]);
		}
		[db closeOpenResultSets];
		[db close];
	}];
	
	
	return [mutableState copy];
}

#pragma mark - Helpers

+ (void)createTablesForDatabase:(FMDatabase *)database
{
	NSString *tableCreateCommand = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ("
									" %@ INTEGER PRIMARY KEY AUTOINCREMENT,"
									" %@ TEXT, "
									" %@ TEXT,"
									" %@ INTEGER,"
									" %@ BLOB,"
									" %@ INTEGER,"
									" %@ INTEGER,"
									" %@ INTEGER,"
									" %@ INTEGER,"
									" %@ INTEGER,"
									" %@ INTEGER,"
									" %@ INTEGER )", kZLWorkItemDatabaseTableName, kZLWorkItemIDColumnKey, kZLTaskTypeColumnKey, kZLTaskIDColumnKey, kZLStateColumnKey, kZLDataColumnKey, kZLMajorPriorityColumnKey, kZLMinorPriorityColumnKey, kZLRetryCountColumnKey, kZLTimeCreatedColumnKey, kZLRequiresIntenetColumnKey, kZLMaxNumberOfRetriesKey, kZLShouldHoldAfterMaxRetriesKey];
	
	[database open];
	BOOL success = [database executeUpdate:tableCreateCommand];
	
	if (!success) {
		NSLog(@"Error creating database %@", [database lastError]);
	}
}

+ (NSString *)createQueryStringForArray:(NSArray *)array
{
	NSString *query = @"(";
	for (int i=1; i<array.count; i++) {
		query = [query stringByAppendingString:@"?,"];
	}
	query = [query stringByAppendingString:@"?)"];
	
	return query;
}

#pragma mark - Testing Helpers. Not for use in development

+ (void)resetForTest
{
	[[self sharedQueue] inDatabase:^(FMDatabase *db) {
		[db open];
		NSString *deleteCommand = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", kZLWorkItemDatabaseTableName];
		
		[db executeUpdate:deleteCommand];
		[db closeOpenResultSets];
		[db close];
	}];
	
	_sharedQueue = nil;
}

@end
