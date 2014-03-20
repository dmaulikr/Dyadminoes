//
//  Board.m
//  Dyadminoes
//
//  Created by Bennett Lin on 3/15/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "Board.h"
#import "SnapPoint.h"
#import "Cell.h"
#import "Dyadmino.h"

@interface Board ()

@property (strong, nonatomic) NSMutableSet *allCells;

@end

@implementation Board

-(id)initWithColor:(UIColor *)color andSize:(CGSize)size
    andAnchorPoint:(CGPoint)anchorPoint
   andHomePosition:(CGPoint)homePosition
      andZPosition:(CGFloat)zPosition {
  self = [super init];
  if (self) {
    
    self.name = @"board";
    self.color = color;
    self.size = size;
    self.anchorPoint = anchorPoint;
    self.homePosition = homePosition;
    self.position = self.homePosition;
    self.zPosition = zPosition;

      // instantiate node and cell arrays to be searched
    self.snapPointsTwelveOClock = [NSMutableSet new];
    self.snapPointsTwoOClock = [NSMutableSet new];
    self.snapPointsTenOClock = [NSMutableSet new];
    self.occupiedCells = [NSMutableSet new];
  }
  return self;
}

-(void)layoutBoardCellsAndSnapPointsOfDyadminoes:(NSMutableSet *)boardDyadminoes {

  [self determineOutermostCellsBasedOnDyadminoes:boardDyadminoes];
  
    // formula is y <= cellsTop - (x / 2) and y >= cellsBottom - (x / 2)
    // use this to get the range to iterate over y, and to keep the board square
  
  for (NSInteger xHex = self.cellsLeft; xHex <= self.cellsRight; xHex++) {
    for (NSInteger yHex = self.cellsBottom - self.cellsRight / 2; yHex <= self.cellsTop - self.cellsLeft / 2; yHex++) {

      if (xHex >= self.cellsLeft && xHex <= self.cellsRight &&
          yHex <= self.cellsTop - (xHex / 2.f) && yHex >= self.cellsBottom - (xHex / 2.f)) {
        [self addCellWithXHex:xHex andYHex:yHex];
      }
    }
  }
  [self determineBoardBounds];
}

#pragma mark - cell methods

-(Cell *)addCellWithXHex:(NSInteger)xHex andYHex:(NSInteger)yHex {
    // to save time, initial layout adds cells directly,
    // without checking to see if they're already in allCells
  
  Cell *cell = [[Cell alloc] initWithBoard:self
                                     andTexture:[SKTexture textureWithImageNamed:@"blankSpace"]
                                    andHexCoord:[self hexCoordFromX:xHex andY:yHex]];
  cell.color = [SKColor orangeColor];
  cell.colorBlendFactor = 0.5f;
  cell.hidden = NO;
  [self addChild:cell];
  [cell addSnapPointsToBoard];
  return cell;
}

-(Cell *)findCellWithXHex:(NSInteger)xHex andYHex:(NSInteger)yHex {
  for (Cell *cell in self.allCells) {
    if (cell.hexCoord.x == xHex && cell.hexCoord.y == yHex) {
      return cell;
    }
  }
  return nil;
}

-(Cell *)acknowledgeOrAddCellWithXHex:(NSInteger)xHex andYHex:(NSInteger)yHex {
    // this method only gets called during play, after initial layout
    // it first checks to see if cell exists in allCells array
    // if not, it instantiates it

    // first check to see if cell already exists
  Cell *cell = [self findCellWithXHex:xHex andYHex:yHex];
  
    // if cell does not exist, create and add it
  if (!cell) {
    cell = [[Cell alloc] initWithBoard:self
                                    andTexture:[SKTexture textureWithImageNamed:@"blankSpace"]
                                   andHexCoord:[self hexCoordFromX:xHex andY:yHex]];
  }
    //// do stuff here to officially acknowledge cell
  
  cell.hidden = NO;
  [self addChild:cell];
  [cell addSnapPointsToBoard];
  [self determineBoardBounds];
  return cell;
}

-(Cell *)ignoreCell:(Cell *)cell {
    // cells do *not* get deallocated or taken out of allCells array when ignored,
    // they are only removed from parent

    //// do stuff here to officially remove cell
  
  cell.hidden = YES;
  [cell removeFromParent];
  [cell removeSnapPointsFromBoard];
  [self determineBoardBounds];
  return cell;
}

#pragma mark - board span methods

-(void)determineOutermostCellsBasedOnDyadminoes:(NSMutableSet *)boardDyadminoes {
  for (Dyadmino *dyadmino in boardDyadminoes) {
    [self determineOutermostCellsBasedOnDyadmino:dyadmino];
  }
  
    // hard coded for now, will change, obviously
//  self.cellsTop = 5;
//  self.cellsRight = 4;
//  self.cellsBottom = -5;
//  self.cellsLeft = -4;
  
//  NSLog(@"board cells range is top %i, right %i, bottom %i, left %i", self.cellsTop, self.cellsRight, self.cellsBottom, self.cellsLeft);
}

-(void)determineOutermostCellsBasedOnDyadmino:(Dyadmino *)dyadmino {
    /// test this
  
  NSInteger cellsTop = 0;
  NSInteger cellsRight = 0;
  NSInteger cellsBottom = 0;
  NSInteger cellsLeft = 0;
  
    // check hexCoords of both cells of dyadmino
  HexCoord hexCoord[2] = {dyadmino.homeNode.myCell.hexCoord,
    [self getHexCoordOfOtherCellGivenDyadmino:dyadmino andBoardNode:dyadmino.homeNode]};
  
  for (int i = 0; i < 2; i++) {
    NSInteger xHex = hexCoord[i].x;
    NSInteger yHex = hexCoord[i].y;
    
      // check x span
    if (xHex > cellsRight) {
      cellsRight = xHex;
    } else if (xHex < cellsLeft) {
      cellsLeft = xHex;
    }
    
      // check y span
    if (yHex > cellsTop - (xHex / 2.f)) {
      cellsTop = yHex;
    } else if (yHex < cellsBottom - (xHex / 2.f)) {
      cellsBottom = yHex;
    }
  }
  
    // this creates four cells plus one buffer cell beyond outermost dyadmino
  self.cellsTop = cellsTop + 5;
  self.cellsRight = cellsRight + 5;
  self.cellsBottom = cellsBottom - 5;
  self.cellsLeft = cellsLeft - 5;
}

-(void)determineBoardBounds {
    // this gets called after every method that adds cells or removes them
  
    //// this will determine bounds
  
//  hardcode just to test
  self.boundsBottom = 280.f;
  self.boundsRight = 180.f;
  self.boundsLeft = 140.f;
  self.boundsTop  = 320.f;

//  NSLog(@"board size is %.1f, %.1f", self.size.width, self.size.height);
  CGFloat tempTop = self.cellsTop * kDyadminoFaceRadius * 2;
  CGFloat tempRight = self.cellsRight * kDyadminoFaceRadius * 2;
  CGFloat tempBottom = -self.cellsBottom * kDyadminoFaceRadius * 2;
  CGFloat tempLeft = -self.cellsLeft * kDyadminoFaceRadius * 2;
  
//  NSLog(@"bounds by cell size is top %.1f, right %.1f, bottom %.1f, left %.1f",
//        tempTop, tempRight, tempBottom, tempLeft);
  
  if (tempTop < self.size.height * 0.5) {
    tempTop = self.size.height * 0.5;
  }
  if (tempRight < self.size.width * 0.5) {
    tempRight = self.size.width * 0.5;
  }
  if (tempBottom < self.size.height * 0.5) {
    tempBottom = self.size.height * 0.5;
  }
  if (tempLeft < self.size.width * 0.5) {
    tempLeft = self.size.width * 0.5;
  }
  
//  self.boundsTop = tempTop;
//  self.boundsRight = tempRight;
//  self.boundsBottom = tempBottom;
//  self.boundsLeft = tempLeft;
  
//  NSLog(@"bounds must be top %.1f, right %.1f, bottom %.1f, left %.1f", self.boundsTop, self.boundsRight, self.boundsBottom, self.boundsLeft);
}

#pragma mark - distance methods

-(CGPoint)getOffsetFromPoint:(CGPoint)point {
  return [self subtractFromThisPoint:point thisPoint:self.position];
}

-(CGPoint)getOffsetForPoint:(CGPoint)point withTouchOffset:(CGPoint)touchOffset {
  CGPoint offsetPoint = [self subtractFromThisPoint:point thisPoint:touchOffset];
  return [self subtractFromThisPoint:offsetPoint thisPoint:self.position];
}

#pragma mark - cell methods

-(void)updateCellsForDyadmino:(Dyadmino *)dyadmino placedOnBoardNode:(SnapPoint *)snapPoint {
    // this assumes dyadmino is properly oriented for this boardNode
  
    // this gets the cells based on dyadmino orientation and board node
  Cell *bottomCell = snapPoint.myCell;
  HexCoord topCellHexCoord = [self getHexCoordOfOtherCellGivenDyadmino:dyadmino andBoardNode:snapPoint];
  Cell *topCell = [self getCellWithHexCoord:topCellHexCoord];

  NSArray *cells = @[topCell, bottomCell];
  NSInteger pcs[2] = {dyadmino.pc1, dyadmino.pc2};
  
  for (int i = 0; i < 2; i++) {
    Cell *cell = cells[i];
    
      // only assign if cell doesn't have a dyadmino recorded
    if (!cell.myDyadmino) {
      
      // assign dyadmino to cell
      cell.myDyadmino = dyadmino;
      
      // assign pc to cell based on dyadmino orientation
      switch (dyadmino.orientation) {
        case kPC1atTwelveOClock:
        case kPC1atTwoOClock:
        case kPC1atTenOClock:
          cell.myPC = pcs[i];
          break;
        case kPC1atSixOClock:
        case kPC1atEightOClock:
        case kPC1atFourOClock:
          cell.myPC = pcs[(i + 1) % 2];
          break;
      }
        // add to board's array of occupied cells to search
      [self.occupiedCells addObject:cell];
      
        /// testing purposes
      [cell updatePCLabel];
    }
  }
  NSLog(@"cells placed on board");
}

-(void)updateCellsForDyadmino:(Dyadmino *)dyadmino removedFromBoardNode:(SnapPoint *)snapPoint {
  
  NSLog(@"dyadmino is %@, snapPoint is %@", dyadmino.name, snapPoint.name);
  
    // this gets the cells based on dyadmino orientation and board node
  Cell *bottomCell = snapPoint.myCell;
  HexCoord topCellHexCoord = [self getHexCoordOfOtherCellGivenDyadmino:dyadmino andBoardNode:snapPoint];
  Cell *topCell = [self getCellWithHexCoord:topCellHexCoord];
  
  NSArray *cells = @[topCell, bottomCell];
  
  for (int i = 0; i < 2; i++) {
    Cell *cell = cells[i];

    NSLog(@"cell.myDyadmino is %@", cell.myDyadmino.name);
    
      // only remove if cell dyadmino is dyadmino
    if (cell.myDyadmino == dyadmino) {
      cell.myDyadmino = nil;
      cell.myPC = -1;
      
      NSLog(@"cell.myDyadmino is %@", cell.myDyadmino.name);
      
      [self.occupiedCells removeObject:cell];
      
        /// testing purposes
      [cell updatePCLabel];
    }
  }
  NSLog(@"cells removed from board");
}

-(HexCoord)getHexCoordOfOtherCellGivenDyadmino:(Dyadmino *)dyadmino andBoardNode:(SnapPoint *)snapPoint {
  NSInteger xHex = snapPoint.myCell.hexCoord.x;
  NSInteger yHex = snapPoint.myCell.hexCoord.y;
  
  switch (dyadmino.orientation) {
    case kPC1atTwelveOClock:
    case kPC1atSixOClock:
      yHex++;
      break;
    case kPC1atTwoOClock:
    case kPC1atEightOClock:
      xHex++;
      break;
    case kPC1atFourOClock:
    case kPC1atTenOClock:
      xHex--;
      yHex++;
      break;
  }
  return [self hexCoordFromX:xHex andY:yHex];
}

-(Cell *)getCellWithHexCoord:(HexCoord)hexCoord {
  for (Cell *cell in self.children) {
    if (cell.hexCoord.x == hexCoord.x && cell.hexCoord.y == hexCoord.y) {
      return cell;
    }
  }
  return nil;
}

#pragma mark - legality methods

-(PhysicalPlacementResult)validatePlacingDyadmino:(Dyadmino *)dyadmino onBoardNode:(SnapPoint *)snapPoint {
    // if it's the first dyadmino, placement anywhere is fine
  if (self.occupiedCells.count <= 2) {
    return kNoError;
  }

      // this gets the cells based on dyadmino orientation and board node
  Cell *bottomCell = snapPoint.myCell;
  HexCoord topCellHexCoord = [self getHexCoordOfOtherCellGivenDyadmino:dyadmino andBoardNode:snapPoint];
  Cell *topCell = [self getCellWithHexCoord:topCellHexCoord];
  
    // if either cell has a dyadmino, then it's not legal
  if ((topCell.myDyadmino && topCell.myDyadmino != dyadmino) ||
      (bottomCell.myDyadmino && bottomCell.myDyadmino != dyadmino)) {
    return kErrorStackedDyadminoes;
  }
  
    // now this checks if either cell has a neighbour cell occupied by another dyadmino
  NSArray *cells = @[topCell, bottomCell];
  for (Cell *dyadminoCell in cells) {
    if ([self cell:dyadminoCell hasNeighbourCellNotOccupiedByDyadmino:dyadmino]) {
      return kNoError;
    };
  }
    // otherwise, it's a lone dyadmino
  return kErrorLoneDyadmino;
}

-(BOOL)cell:(Cell *)dyadminoCell hasNeighbourCellNotOccupiedByDyadmino:(Dyadmino *)dyadmino {
  NSInteger xHex = dyadminoCell.hexCoord.x;
  NSInteger yHex = dyadminoCell.hexCoord.y;
    // this includes cell and its eight surrounding cells (thinking in terms of square grid)
  for (int i = xHex - 1; i <= xHex + 1; i++) {
    for (int j = yHex - 1; j <= yHex + 1; j++) {
        // this excludes cell itself and the two far cells
      if (!(i == xHex && j == yHex) &&
          !(i == xHex - 1 && j == yHex - 1) &&
          !(i == xHex + 1 && j == yHex + 1)) {
        
        Cell *neighbourCell = [self getCellWithHexCoord:[self hexCoordFromX:i andY:j]];
        if (neighbourCell.myDyadmino && neighbourCell.myDyadmino != dyadmino) {
          return YES;
        }
      }
    }
  }
  return NO;
}

@end
