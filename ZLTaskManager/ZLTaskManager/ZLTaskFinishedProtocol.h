//
//  ZLTaskFinishedProtocol.h
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZLTaskWorker;
@protocol ZLTaskFinishedProtocol <NSObject>

- (void)taskWorker:(ZLTaskWorker *)taskWorker finishedSuccessfully:(BOOL)wasSuccessful;

@end