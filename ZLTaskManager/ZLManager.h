//
//  ZLManager.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZLInternalWorkItem;
@class ZLTaskWorker;

@interface ZLManager : NSObject

- (ZLTaskWorker *)taskWorkerForWorkItem:(ZLInternalWorkItem *)workItem;
- (void)workItemDidFail:(ZLInternalWorkItem *)workItem;

@end