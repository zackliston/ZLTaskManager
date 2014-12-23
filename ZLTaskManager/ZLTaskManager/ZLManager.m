//
//  ZLManager.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import "ZLManager.h"
#import "ZLTaskManager.h"
#import "ZLInternalWorkItem.h"
#import "ZLTaskWorker.h"

@implementation ZLManager

- (void)dealloc
{
    [[ZLTaskManager sharedInstance] removeRegisteredManagerForAllTaskTypes:self];
}

- (ZLTaskWorker *)taskWorkerForWorkItem:(ZLInternalWorkItem *)workItem
{
    [NSException raise:NSInternalInconsistencyException format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

- (void)workItemDidFail:(ZLInternalWorkItem *)workItem
{
    return;
}

@end
