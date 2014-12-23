//
//  ZLTaskWorker.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZLTaskFinishedProtocol.h"

@class ZLInternalWorkItem;

@interface ZLTaskWorker : NSOperation

@property (nonatomic, assign) BOOL taskFailed;
@property (nonatomic, assign) BOOL isFinalAttempt;

@property (nonatomic, weak, readonly) id<ZLTaskFinishedProtocol>taskFinishedDelegate;
@property (nonatomic, strong, readonly) ZLInternalWorkItem *workItem;

- (void)setupWithWorkItem:(ZLInternalWorkItem *)workItem;
- (void)setTaskFinishedDelegate:(id<ZLTaskFinishedProtocol>)taskFinishedDelegate;

- (void)setIsExecuting:(BOOL)isExecuting;
- (void)setIsFinished:(BOOL)isFinished;
- (void)setIsConcurrent:(BOOL)isConcurrent;

- (void)taskFinishedWasSuccessful:(BOOL)wasSuccessful;

@end
