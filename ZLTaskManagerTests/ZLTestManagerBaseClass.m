//
//  ZLTestManagerBaseClass.m
//  ZLTaskManager
//
//  Created by Zack Liston on 12/23/14.
//  Copyright (c) 2014 Zack Liston. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZLManager.h"

@interface ZLTestManagerBaseClass : XCTestCase

@end

@implementation ZLTestManagerBaseClass

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBaseCaseThrowsExceptionIfNotOverridden
{
    ZLManager *baseManager = [[ZLManager alloc] init];
    
    @try {
        [baseManager taskWorkerForWorkItem:nil];
        XCTFail(@"An internal inconsistency exception should have been thrown since the BaseClass does not implement this method.");
    }
    @catch (NSException *exception) {
        XCTAssertTrue([NSInternalInconsistencyException isEqualToString:exception.name], @"Exception should be of type InternalInconsistencyException but is %@ instead", exception.name);
    }
    @finally {
        
    }
}

@end
