//
//  Cell.h
//  Dyadminoes
//
//  Created by Bennett Lin on 3/16/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#import "NSObject+Helper.h"
@class Board;
@class Dyadmino;
@class SnapPoint;

@interface Cell : NSObject

@property (nonatomic) SKTexture *cellNodeTexture;
@property (nonatomic) CGPoint cellNodePosition;
@property (nonatomic) CGSize cellNodeSize;

@property (strong, nonatomic) NSString *name;

@property (strong, nonatomic) SnapPoint *boardSnapPointTwelveOClock;
@property (strong, nonatomic) SnapPoint *boardSnapPointTwoOClock;
@property (strong, nonatomic) SnapPoint *boardSnapPointTenOClock;

@property (strong, nonatomic) SKSpriteNode *cellNode;
@property (strong, nonatomic) Board *board;
@property (nonatomic) HexCoord hexCoord;
@property (strong, nonatomic) Dyadmino *myDyadmino;
@property (nonatomic) NSInteger myPC; // signed integer because myPC is -1 if no PC

@property (strong, nonatomic) SKLabelNode *hexCoordLabel;
@property (strong, nonatomic) SKLabelNode *pcLabel;

@property (nonatomic) BOOL currentlyColouringNeighbouringCells;

  // called to instantiate new cell
-(id)initWithBoard:(Board *)board
        andTexture:(SKTexture *)texture
       andHexCoord:(HexCoord)hexCoord
      andHexOrigin:(CGVector)hexOrigin;

  // called to reuse dequeued cell
-(void)reuseCellWithHexCoord:(HexCoord)hexCoord andHexOrigin:(CGVector)hexOrigin;

  // called before dismissing scene
-(void)resetForNewMatch;

#pragma mark - snap point methods

-(void)addSnapPointsToBoard;
-(void)removeSnapPointsFromBoard;

#pragma mark - cell view helper methods

-(void)resizeCell:(BOOL)resize withHexOrigin:(CGVector)hexOrigin;
-(void)addColourWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;

#pragma mark - testing methods

-(void)updatePCLabel;

@end
