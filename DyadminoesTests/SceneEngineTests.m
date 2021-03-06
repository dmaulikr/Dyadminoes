//
//  DyadminoesTests.m
//  DyadminoesTests
//
//  Created by Bennett Lin on 1/20/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SceneEngine.h"

@interface SceneEngineTests : XCTestCase

@end

@implementation SceneEngineTests

-(void)setUp {
  [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

-(void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}

-(void)testIsSingleton {
  SceneEngine *engine1 = [SceneEngine sharedSceneEngine];
  SceneEngine *engine2 = [SceneEngine sharedSceneEngine];
  XCTAssertEqualObjects(engine1, engine2, @"Scene engine is not a singleton.");
}

-(void)testPileCountAfterInstantiation {
  SceneEngine *sceneEngine = [SceneEngine sharedSceneEngine];
  XCTAssertTrue([sceneEngine.allDyadminoes count] == kPileCount, @"Pile count should be 66.");
}

@end
