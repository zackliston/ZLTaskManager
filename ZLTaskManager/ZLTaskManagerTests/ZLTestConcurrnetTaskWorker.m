//
//  ZLTestConcurrnetTaskWorker.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLTestConcurrnetTaskWorker.h"

@implementation ZLTestConcurrnetTaskWorker {
	NSTimeInterval _waitTime;
	
}

- (id)initWithConcurrentWaitTime:(NSTimeInterval)wait
{
	self = [super init];
	if (self) {
		_waitTime = wait;
		self.isConcurrent = YES;
	}
	return self;
}
- (void)start
{
	self.isFinished = NO;
	self.isExecuting = YES;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		self.isExecuting = YES;
		[NSThread sleepForTimeInterval:_waitTime];
		[self moreStuff];
	});
}

- (void)moreStuff
{
	self.isExecuting = NO;
	self.isFinished = YES;
}


@end
