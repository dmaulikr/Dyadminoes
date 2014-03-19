//
//  Cell.m
//  Dyadminoes
//
//  Created by Bennett Lin on 3/16/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "Cell.h"
#import "SnapPoint.h"
#import "Board.h"

@interface Cell ()

@property (strong, nonatomic) SnapPoint *boardSnapPointTwelveOClock;
@property (strong, nonatomic) SnapPoint *boardSnapPointTwoOClock;
@property (strong, nonatomic) SnapPoint *boardSnapPointTenOClock;

@end


@implementation Cell

-(id)initWithBoard:(Board *)board andTexture:(SKTexture *)texture andHexCoord:(HexCoord)hexCoord {
  self = [super init];
  if (self) {
    self.board = board;
    self.texture = texture;
    self.hexCoord = hexCoord;
    self.name = [NSString stringWithFormat:@"cell %li-%li", (long)self.hexCoord.x, (long)self.hexCoord.y];
    self.zPosition = kZPositionBoardCell;
    self.alpha = 0.6f;
    
      // establish cell size
    CGFloat paddingBetweenCells = 5.f;
    CGFloat ySize = kDyadminoFaceRadius * 2 - paddingBetweenCells;
    CGFloat widthToHeightRatio = self.texture.size.width / self.texture.size.height;
    CGFloat xSize = widthToHeightRatio * ySize;
    self.size = CGSizeMake(xSize, ySize);
    
      // establish cell position
    CGFloat yOffset = kDyadminoFaceRadius; // to make node between two faces the center
    CGFloat cellWidth = self.size.width;
    CGFloat cellHeight = self.size.height;
    CGFloat newX = self.hexCoord.x * (0.75 * cellWidth + paddingBetweenCells);
    CGFloat newY = (self.hexCoord.y + self.hexCoord.x * 0.5) * (cellHeight + paddingBetweenCells) - yOffset;
    self.position = CGPointMake(newX, newY);

    [self createSnapPoints];

      //// for testing purposes
    NSString *boardXYString = [NSString stringWithFormat:@"%li, %li", (long)self.hexCoord.x, (long)self.hexCoord.y];
    SKLabelNode *labelNode = [[SKLabelNode alloc] init];
    labelNode.name = boardXYString;
    labelNode.text = boardXYString;
    labelNode.fontColor = [SKColor whiteColor];
    
    if (self.hexCoord.x == 0 || self.hexCoord.y == 0 || self.hexCoord.x + self.hexCoord.y == 0)
      labelNode.fontColor = [SKColor yellowColor];
    
    if (self.hexCoord.x == 0 && (self.hexCoord.y == 0 || self.hexCoord.y == 1))
      labelNode.fontColor = [SKColor greenColor];
    
    labelNode.fontSize = 14.f;
    labelNode.alpha = 0.7f;
    labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentModeCenter;
    [self addChild:labelNode];
      ////
  }
  return self;
}

-(void)createSnapPoints {
  CGFloat faceOffset = kDyadminoFaceRadius;
  
    // based on a 30-60-90 degree triangle
  CGFloat faceOffsetX = faceOffset * 0.5 * kSquareRootOfThree;
  CGFloat faceOffsetY = faceOffset * 0.5;
  
  self.boardSnapPointTwelveOClock = [[SnapPoint alloc] initWithSnapPointType:kSnapPointBoardTwelveOClock];
  self.boardSnapPointTwoOClock = [[SnapPoint alloc] initWithSnapPointType:kSnapPointBoardTwoOClock];
  self.boardSnapPointTenOClock = [[SnapPoint alloc] initWithSnapPointType:kSnapPointBoardTenOClock];
  
  self.boardSnapPointTwelveOClock.position = [self addToThisPoint:self.position
                                                        thisPoint:CGPointMake(0.f, faceOffset)];
  self.boardSnapPointTwoOClock.position = [self addToThisPoint:self.position
                                                     thisPoint:CGPointMake(faceOffsetX, faceOffsetY)];
  self.boardSnapPointTenOClock.position = [self addToThisPoint:self.position
                                                     thisPoint:CGPointMake(-faceOffsetX, faceOffsetY)];
  
  self.boardSnapPointTwelveOClock.name = @"snap 12";
  self.boardSnapPointTwoOClock.name = @"snap 2";
  self.boardSnapPointTenOClock.name = @"snap 10";
  self.boardSnapPointTwelveOClock.myCell = self;
  self.boardSnapPointTwoOClock.myCell = self;
  self.boardSnapPointTenOClock.myCell = self;
}

-(void)addSnapPointsToBoard {
  if (![self.board.snapPointsTwelveOClock containsObject:self.boardSnapPointTwelveOClock]) {
    [self.board.snapPointsTwelveOClock addObject:self.boardSnapPointTwelveOClock];
  }
  if (![self.board.snapPointsTwoOClock containsObject:self.boardSnapPointTwoOClock]) {
    [self.board.snapPointsTwoOClock addObject:self.boardSnapPointTwoOClock];
  }
  if (![self.board.snapPointsTenOClock containsObject:self.boardSnapPointTenOClock]) {
    [self.board.snapPointsTenOClock addObject:self.boardSnapPointTenOClock];
  }
}

-(void)removeSnapPointsFromBoard {
  if ([self.board.snapPointsTwelveOClock containsObject:self.boardSnapPointTwelveOClock]) {
    [self.board.snapPointsTwelveOClock removeObject:self.boardSnapPointTwelveOClock];
  }
  if ([self.board.snapPointsTwelveOClock containsObject:self.boardSnapPointTwelveOClock]) {
    [self.board.snapPointsTwoOClock removeObject:self.boardSnapPointTwoOClock];
  }
  if ([self.board.snapPointsTwelveOClock containsObject:self.boardSnapPointTwelveOClock]) {
    [self.board.snapPointsTenOClock removeObject:self.boardSnapPointTenOClock];
  }
}

@end
