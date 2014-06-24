//
//  MyScene.h
//  Dyadminoes
//

//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
@class SceneViewController;
@class SceneEngine;
@class Player;
@class Dyadmino;
@class Match;
@class SoundEngine;

@protocol SceneDelegate;

@interface MyScene : SKScene

@property (strong, nonatomic) SoundEngine *mySoundEngine;
@property (strong, nonatomic) SceneEngine *mySceneEngine;
@property (strong, nonatomic) Match *myMatch;
//@property (strong, nonatomic) NSUndoManager *undoManager;
@property (weak, nonatomic) id <SceneDelegate> delegate;

-(void)preLoad;
-(void)handleDeviceOrientationChange:(UIDeviceOrientation)deviceOrientation;
-(void)persistAllSceneDataDyadminoes;
-(void)deviceShaken;

@end

@protocol SceneDelegate <NSObject>

-(void)backToMainMenu;

@end