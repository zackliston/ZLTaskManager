//
//  ZLTaskWorker.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLTaskWorker.h"
#import "ZLInternalWorkItem.h"

@implementation ZLTaskWorker {
	BOOL _isExecuting;
	BOOL _isFinished;
	BOOL _isConcurrent;
	BOOL _hasCalledTaskFinished;
}

@synthesize workItem = _workItem;
@synthesize taskFinishedDelegate = _taskFinishedDelegate;

#pragma mark - Getters/Setters

- (BOOL)isConcurrent {
	return _isConcurrent;
}

- (void)setIsConcurrent:(BOOL)isConcurrent
{
	if (_isConcurrent != isConcurrent) {
		[self willChangeValueForKey:@"isConcurrent"];
		_isConcurrent = isConcurrent;
		[self didChangeValueForKey:@"isConcurrent"];
	}
}

- (BOOL)isExecuting
{
	if (_isConcurrent) {
		return _isExecuting;
	} else {
		return [super isExecuting];
	}
}

- (void)setIsExecuting:(BOOL)isExecuting
{
	if (_isExecuting != isExecuting) {
		[self willChangeValueForKey:@"isExecuting"];
		_isExecuting = isExecuting;
		[self didChangeValueForKey:@"isExecuting"];
	}
}

- (BOOL)isFinished
{
	if (_isConcurrent) {
		return _isFinished;
	} else {
		return [super isFinished];
	}
}

- (void)setIsFinished:(BOOL)isFinished
{
	if (_isFinished != isFinished) {
		[self willChangeValueForKey:@"isFinished"];
		_isFinished = isFinished;
		[self didChangeValueForKey:@"isFinished"];
	}
}

#pragma mark - Setup

- (void)setupWithWorkItem:(ZLInternalWorkItem *)workItem
{
	_workItem = workItem;
	
	if (_workItem.retryCount >= _workItem.maxNumberOfRetries-1) {
		self.isFinalAttempt = YES;
	} else {
		self.isFinalAttempt = NO;
	}
}

- (void)setTaskFinishedDelegate:(id<ZLTaskFinishedProtocol>)taskFinishedDelegate
{
	_taskFinishedDelegate = taskFinishedDelegate;
}

#pragma mark - Task Lifecycle

- (void)taskFinishedWasSuccessful:(BOOL)wasSuccessful
{
	if (!_hasCalledTaskFinished) {
		_hasCalledTaskFinished = YES;
		[self.taskFinishedDelegate taskWorker:self finishedSuccessfully:wasSuccessful];
	}
	
	if (self.isConcurrent) {
		self.isExecuting = NO;
		self.isFinished = YES;
	}
}



@end
