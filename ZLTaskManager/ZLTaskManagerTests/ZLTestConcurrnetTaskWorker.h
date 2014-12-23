//
//  ZLTestConcurrnetTaskWorker.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLTaskWorker.h"

@interface ZLTestConcurrnetTaskWorker : ZLTaskWorker

- (id)initWithConcurrentWaitTime:(NSTimeInterval)wait;

@end
