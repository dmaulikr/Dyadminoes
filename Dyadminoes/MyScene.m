//
//  MyScene.m
//  Dyadminoes
//
//  Created by Bennett Lin on 1/20/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "MyScene.h"
#import "GameEngine.h"
#import "Dyadmino.h"
#import "NSObject+Helper.h"
#import "SnapPoint.h"
#import "Player.h"
#import "Rack.h"
#import "Board.h"
#import "TopBar.h"
#import "Cell.h"
#import "Button.h"
#import "Label.h"

@interface MyScene () <FieldNodeDelegate, DyadminoDelegate, BoardDelegate>

@end

@implementation MyScene {
  
    // sprites and nodes
  Rack *_rackField;
  Rack *_swapField;
  Board *_boardField;
  SKSpriteNode *_boardCover;
  TopBar *_topBar;
  SKNode *_touchNode;

    // touches
  UITouch *_currentTouch;
  CGPoint _beganTouchLocation;
  CGPoint _currentTouchLocation;
  CGPoint _touchOffsetVector;
  CGPoint _boardOffsetAfterTouch;
  
    // bools and modes
  BOOL _swapMode;
  BOOL _rackExchangeInProgress;
  BOOL _swapFieldActionInProgress;
  BOOL _boardBeingMoved;
  BOOL _canDoubleTap;
  CFTimeInterval _doubleTapTime;
  
    // pointers
  Dyadmino *_touchedDyadmino;
  Dyadmino *_recentRackDyadmino;
  Dyadmino *_hoveringDyadmino;
  Button *_buttonPressed;

    // hover and pivot properties
  BOOL _pivotInProgress;
  CFTimeInterval _hoverTime;
  
    // test
  BOOL _dyadminoesHidden;
}

#pragma mark - init methods

-(id)initWithSize:(CGSize)size {
  if (self = [super initWithSize:size]) {
    self.backgroundColor = kSkyBlue;
    self.name = @"scene";
    self.ourGameEngine = [GameEngine new];
    self.myPlayer = [self.ourGameEngine getAssignedAsPlayer];
    _rackExchangeInProgress = NO;
    _buttonPressed = nil;
  }
  return self;
}

-(void)didMoveToView:(SKView *)view {
  [self layoutBoard];
  [self layoutBoardCover];
  [self populateBoardWithCells];
  [self populateBoardWithDyadminoes];
  [self layoutSwapField];
  [self layoutTopBar];
  [self layoutOrRefreshRackFieldAndDyadminoes];
}

#pragma mark - layout methods

-(void)layoutBoard {
  CGSize size = CGSizeMake(self.frame.size.width,
                           (self.frame.size.height - kTopBarHeight - kRackHeight));
  CGPoint homePosition = CGPointMake(self.view.frame.size.width * 0.5,
                                     (self.view.frame.size.height + kRackHeight - kTopBarHeight) * 0.5);

  _boardField = [[Board alloc] initWithColor:[SKColor clearColor]
                                     andSize:size
                              andAnchorPoint:CGPointMake(0.5, 0.5)
                             andHomePosition:homePosition // this is changed with board movement
                                   andOrigin:(CGPoint)homePosition // origin *never* changes
                                andZPosition:kZPositionBoard];
  _boardField.delegate = self;
  [self addChild:_boardField];
  
    // initialise this as zero
  _boardOffsetAfterTouch = CGPointZero;
}

-(void)layoutBoardCover {
    // call this method *after* board has been laid out
  _boardCover = [[SKSpriteNode alloc] initWithColor:[SKColor blackColor] size:_boardField.size];
  _boardCover.name = @"boardCover";
  _boardCover.anchorPoint = CGPointMake(0.5, 0.5);
  _boardCover.position = _boardField.homePosition;
  _boardCover.zPosition = kZPositionBoardCoverHidden;
  _boardCover.alpha = kBoardCoverAlpha;
  _boardCover.hidden = YES;
  [self addChild:_boardCover];
}

-(void)populateBoardWithCells {
    // this method only needs the board dyadminoes to determine the board's cells ranges
    /// seems to work so far with one dyadmino, will have to keep testing with more
  [_boardField layoutBoardCellsAndSnapPointsOfDyadminoes:self.ourGameEngine.dyadminoesOnBoard];
}

-(void)populateBoardWithDyadminoes {
  for (Dyadmino *dyadmino in self.ourGameEngine.dyadminoesOnBoard) {
    dyadmino.delegate = self;
    
      // this is for the first dyadmino, which doesn't have a boardNode
    if (!dyadmino.homeNode) {
      for (SnapPoint *snapPoint in _boardField.snapPointsTwelveOClock) {
        if ( snapPoint.myCell.hexCoord.x == 0 && snapPoint.myCell.hexCoord.y == 0) {
          dyadmino.homeNode = snapPoint;
        }
      }
    }
    
      //------------------------------------------------------------------------
    
      // update cells
    [_boardField updateCellsForDyadmino:dyadmino placedOnBoardNode:dyadmino.homeNode];
    dyadmino.position = dyadmino.homeNode.position;
    [dyadmino orientBySnapNode:dyadmino.homeNode];
    [dyadmino selectAndPositionSprites];
    [_boardField addChild:dyadmino];
  }
}

-(void)layoutSwapField {
    // initial instantiation of swap field sprite
  _swapField = [[Rack alloc] initWithBoard:_boardField
                                 andColour:kGold
                                   andSize:CGSizeMake(self.frame.size.width, kRackHeight)
                            andAnchorPoint:CGPointZero
                               andPosition:CGPointZero
                              andZPosition:kZPositionSwapField];
  _swapField.name = @"swap";
  [self addChild:_swapField];
  
    // initially sets swap mode
  _swapMode = NO;
  _swapField.hidden = YES;
}

-(void)layoutTopBar {
    // background
  _topBar = [[TopBar alloc] initWithColor:kDarkBlue
                                  andSize:CGSizeMake(self.frame.size.width, kTopBarHeight)
                           andAnchorPoint:CGPointZero
                              andPosition:CGPointMake(0, self.frame.size.height - kTopBarHeight)
                             andZPosition:kZPositionTopBar];
  _topBar.name = @"topBar";
  [_topBar populateWithButtons];
  [_topBar populateWithLabels];
  [self addChild:_topBar];
  [self updatePileCountLabel];
}

-(void)layoutOrRefreshRackFieldAndDyadminoes {
  if (!_rackField) {
    _rackField = [[Rack alloc] initWithBoard:_boardField
                                   andColour:kFieldPurple
                                     andSize:CGSizeMake(self.frame.size.width, kRackHeight)
                              andAnchorPoint:CGPointZero
                                 andPosition:CGPointZero
                                andZPosition:kZPositionRackField];
    _rackField.name = @"rack";
    [self addChild:_rackField];
  }
  [_rackField layoutOrRefreshNodesWithCount:self.myPlayer.dyadminoesInRack.count];
  [_rackField repositionDyadminoes:self.myPlayer.dyadminoesInRack];
  
  for (Dyadmino *dyadmino in self.myPlayer.dyadminoesInRack) {
    dyadmino.delegate = self;
  }
}

-(void)handleDeviceOrientationChange:(UIDeviceOrientation)deviceOrientation {
    ////
}

#pragma mark - touch methods

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /// 1. first, easy checks to determine whether to even register the touch
  
    // this ensures no more than one touch at a time
  if (!_currentTouch) {
    _currentTouch = [touches anyObject];
  } else {
    NSLog(@"current touch is not nil");
    return;
  }
    
  if (_swapFieldActionInProgress) {
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 2. next, register the touch and decide what to do with it
  
    // get touch location and touched node
  _beganTouchLocation = [self findTouchLocationFromTouches:touches];
  _currentTouchLocation = _beganTouchLocation;
  _touchNode = [self nodeAtPoint:_currentTouchLocation];
  NSLog(@"touched node is %@", _touchNode.name);

    //--------------------------------------------------------------------------
    /// 3a. button pressed
  
    // if it's a button, take care of it when touch ended
  if ([_topBar.allButtons containsObject:_touchNode]) {
    _buttonPressed = (Button *)_touchNode;
      // TODO: make distinction of button pressed better, of course
    _buttonPressed.alpha = 0.3f;
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 3b. dyadmino touched
  
  Dyadmino *dyadmino = [self selectDyadminoFromTouchNode:_touchNode
                                           andTouchPoint:_currentTouchLocation];
  
  if (dyadmino && !dyadmino.isRotating && !_touchedDyadmino) {
    _touchedDyadmino = dyadmino;
    [self beginTouchOrPivotOfDyadmino:dyadmino];
  }
  
    //--------------------------------------------------------------------------
    /// 3c. board about to be moved
  
    // if pivot not in progress, or pivot in progress but dyadmino is not close enough
    // then the board is touched and being moved
  if (!_pivotInProgress || (_pivotInProgress && !_touchedDyadmino)) {
    if (_touchNode == _boardField || _touchNode == _boardCover ||
        (_touchNode.parent == _boardField && ![_touchNode isKindOfClass:[Dyadmino class]]) ||
        [_touchNode.parent isKindOfClass:[Cell class]]) { // this one is necessary only for testing purposes
      _boardBeingMoved = YES;
      return;
    }
  }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    /// 1. easy checks to determine whether to register the touch moved
  
    // this ensures no more than one touch at a time
  UITouch *thisTouch = [touches anyObject];
  if (thisTouch != _currentTouch) {
    return;
  }
  
    // if the touch started on a button, do nothing and return
  if (_buttonPressed) {
    SKNode *node = [self nodeAtPoint:[self findTouchLocationFromTouches:touches]];

    if (node == _buttonPressed) {
      _buttonPressed.alpha = 0.3f;
      return;
    } else {
      _buttonPressed.alpha = 1.f;
      return;
    }
  }
  
    // register no touches moved while swap field is being toggled
  if (_swapFieldActionInProgress) {
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 2. next, update the touch location

  _currentTouchLocation = [self findTouchLocationFromTouches:touches];
  
    //--------------------------------------------------------------------------
    /// 3a. board is being moved
  
    // if board is being moved, handle and return
  if (_boardBeingMoved) {
    [self moveBoard];
      //testing purposes
//    NSLog(@"board wants to be %.1f, %.1f", newPosition.x, newPosition.y);
//    NSLog(@"bounds must be within top %.1f, right %.1f, bottom %.1f, left %.1f",
//          _boardField.highestYPos, _boardField.highestXPos, _boardField.lowestYPos, _boardField.lowestXPos);
//    NSLog(@"board home position is %.1f, %.1f", _boardField.homePosition.x, _boardField.homePosition.y);
//    NSLog(@"board position is %.1f, %.1f", _boardField.position.x, _boardField.position.y);
//    NSLog(@"board origin of course is %.1f, %.1f", self.view.frame.size.width * 0.5,
//          (self.view.frame.size.height + kRackHeight - kTopBarHeight) * 0.5);
//    NSLog(@"boardField position x is %.1f, lowest x possible is %.1f", _boardField.position.x, _boardField.lowestXPos);
    return;
  }
  
    // check this *after* checking board move
    if (!_touchedDyadmino) {
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 3b part i: dyadmino is being moved, take care of the prepwork
  
    // update currently touched dyadmino's section
  [self determineCurrentSectionOfDyadmino:_touchedDyadmino];
  
    // if it moved at all, it can no longer flip
  _touchedDyadmino.canFlip = NO;
  
    // if rack dyadmino is moved to board, send home recentRack dyadmino
  if (_recentRackDyadmino && _touchedDyadmino != _recentRackDyadmino &&
      [_touchedDyadmino belongsInRack] && [_touchedDyadmino isOnBoard]) {
    [self sendDyadminoHome:_recentRackDyadmino byPoppingIn:YES];
  }
  
    // continue to reset hover count
  if ([_touchedDyadmino isHovering]) {
    [_touchedDyadmino keepHovering];
  }
  
    // take care of highlighting as it moves between rack and dyadmino
  if ([_touchedDyadmino belongsInRack] && !_swapMode && !_pivotInProgress) {
    /*
      this is the only place that sets dyadmino highlight to YES
      dyadmino highlight is reset when sent home or finalised
     */
      CGPoint dyadminoOffsetPosition = [self addToThisPoint:_currentTouchLocation thisPoint:_touchOffsetVector];
      [_touchedDyadmino adjustHighlightGivenDyadminoOffsetPosition:dyadminoOffsetPosition];
  }
  
    //--------------------------------------------------------------------------
    /// 3b part ii: pivot or move
  
    // if we're currently pivoting, just rotate and return
  if (_pivotInProgress) {
    [self handlePivotOfDyadmino:_hoveringDyadmino];
    return;
  }
  
  
    // this ensures that pivot guides are not hidden if rack exchange
  if (_touchedDyadmino == _hoveringDyadmino && !_touchedDyadmino.isRotating) {
    [_boardField hideAllPivotGuides];
  }
  
    // move the dyadmino!
  _touchedDyadmino.position =
    [self getOffsetForTouchPoint:_currentTouchLocation forDyadmino:_touchedDyadmino];
  
  //--------------------------------------------------------------------------
  /// 3c. dyadmino is just being exchanged in rack
  
    // if it's a rack dyadmino, then while movement is within rack, rearrange dyadminoes
  if (([_touchedDyadmino belongsInRack] && [_touchedDyadmino isInRack]) ||
      [_touchedDyadmino isOrBelongsInSwap]) {
    
    SnapPoint *rackNode = [self findSnapPointClosestToDyadmino:_touchedDyadmino];
    
    [_rackField handleRackExchangeOfTouchedDyadmino:_touchedDyadmino
                                           withDyadminoes:(NSMutableArray *)self.myPlayer.dyadminoesInRack
                                       andClosestRackNode:rackNode];
  }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    /// 1. first check whether to even register the touch ended

    // this ensures no more than one touch at a time
  UITouch *thisTouch = [touches anyObject];
  if (thisTouch != _currentTouch) {
    return;
  }
  _currentTouch = nil;
  
  if (_swapFieldActionInProgress) {
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 2a and b. handle button pressed or board moved
  
    // handle button that was pressed, ensure that touch is still on button when it ends
  if (_buttonPressed) {
    SKNode *node = [self nodeAtPoint:[self findTouchLocationFromTouches:touches]];
    if (node == _buttonPressed) {
      [self handleButtonPressed];
    }
    _buttonPressed.alpha = 1.f;
    _buttonPressed = nil;
    return;
  }
  
    // board no longer being moved
  if (_boardBeingMoved) {
    _boardBeingMoved = NO;
    _boardField.homePosition = _boardField.position;
  }
  
    // check this *after* checking board move
  if (!_touchedDyadmino) {
    return;
  }
    //--------------------------------------------------------------------------
    /// 2c. handle touched dyadmino
  
  [self determineCurrentSectionOfDyadmino:_touchedDyadmino];
  Dyadmino *dyadmino = [self assignTouchEndedPointerToDyadmino:_touchedDyadmino];

  [self handleTouchEndOfDyadmino:dyadmino];
  
    // cleanup
  _pivotInProgress = NO;
  _touchOffsetVector = CGPointZero;
}

#pragma mark - board methods

-(void)moveBoard {
    // first get new board position, after applying touch offset
  CGPoint touchOffset = [self subtractFromThisPoint:_beganTouchLocation thisPoint:_currentTouchLocation];
  CGPoint newPosition = [self subtractFromThisPoint:_boardField.homePosition thisPoint:touchOffset];
  
  CGFloat newX = newPosition.x;
  CGFloat newY = newPosition.y;
  
  CGFloat swapBuffer = 0.f;
  if (_swapMode) {
    swapBuffer = kRackHeight; // the height of the swap field
  }
  
  if (newPosition.y < _boardField.lowestYPos) {
    newY = _boardField.lowestYPos;
  } else if (newPosition.y > _boardField.highestYPos + swapBuffer) {
    newY = _boardField.highestYPos + swapBuffer;
  }
  
  if (newPosition.x < _boardField.lowestXPos) {
    newX = _boardField.lowestXPos;
  } else if (newPosition.x > _boardField.highestXPos) {
    newX = _boardField.highestXPos;
  }
  
    // move board to new position
  _boardField.position = CGPointMake(newX, newY);
    // move home position to board position, after applying touch offset
  _boardField.homePosition = [self addToThisPoint:_boardField.position thisPoint:touchOffset];
}

#pragma mark - dyadmino methods

-(void)beginTouchOrPivotOfDyadmino:(Dyadmino *)dyadmino {
  [self updateCellsForRemovedDyadmino:dyadmino];
  
    // board dyadmino sends recent rack home upon touch
    // rack dyadmino will do so upon move out of rack
  if ([dyadmino isOnBoard] && [dyadmino belongsOnBoard] && dyadmino != _hoveringDyadmino) {
    [self sendDyadminoHome:_hoveringDyadmino byPoppingIn:YES];
  }
  
    // record tempReturnOrientation only if it's settled and not hovering
  if (dyadmino != _hoveringDyadmino) {
    dyadmino.tempReturnOrientation = dyadmino.orientation;
  }
  
  [dyadmino startTouchThenHoverResize];
  
  [self getReadyToMoveCurrentDyadmino:_touchedDyadmino];
  
    // if it's now about to pivot, just get pivot angle
  if (_pivotInProgress) {
    [self getReadyToPivotHoveringDyadmino:_hoveringDyadmino];
  }
  
    // if it's on the board and not already rotating, two possibilities
  if ([_touchedDyadmino isOnBoard] && !_touchedDyadmino.isRotating) {
    
      // 1. it's not hovering, so make it hover
    if (!_touchedDyadmino.canFlip) {
      _touchedDyadmino.canFlip = YES;
      _canDoubleTap = YES;
      
        // 2. it's already hovering, so tap inside to flip
    } else {
      [_touchedDyadmino animateFlip];
    }
  }

}

-(void)getReadyToMoveCurrentDyadmino:(Dyadmino *)dyadmino {
  [self determineCurrentSectionOfDyadmino:dyadmino];
  
  if ([dyadmino isInRack]) {
    _touchOffsetVector = [self subtractFromThisPoint:_beganTouchLocation thisPoint:dyadmino.position];
  } else {
    CGPoint boardOffsetPoint = [self addToThisPoint:dyadmino.position thisPoint:_boardField.position];
    _touchOffsetVector = [self subtractFromThisPoint:_beganTouchLocation thisPoint:boardOffsetPoint];
  }
  
    // reset hover count
  if ([dyadmino isHovering]) {
    [dyadmino keepHovering];
  }
  
  [dyadmino removeActionsAndEstablishNotRotating];
  
    //--------------------------------------------------------------------------
  
    // if it's still in the rack, it can still rotate
  if ([dyadmino isInRack] || [dyadmino isOrBelongsInSwap]) {
    dyadmino.canFlip = YES;
  }
  
    // various prep
  dyadmino.zPosition = kZPositionHoveredDyadmino;
}

-(void)handleTouchEndOfDyadmino:(Dyadmino *)dyadmino {
    // ensures we're not disrupting a rotating animation
  if (!dyadmino.isRotating) {
    
      // if dyadmino belongs in rack (or swap) and *isn't* on board...
    if (([dyadmino belongsInRack] || [dyadmino belongsInSwap]) && ![dyadmino isOnBoard]) {
      
        // ...flip if possible, or send it home
      if (dyadmino.canFlip) {
        [dyadmino animateFlip];
      } else {
        [self sendDyadminoHome:dyadmino byPoppingIn:NO];
      }
      
        // or if dyadmino is in top bar...
    } else if ([dyadmino isInTopBar]) {;
      
        // if it's on the board, regardless of whether it belongs in rack or on board
      if (dyadmino.tempBoardNode) {
        [self sendDyadminoToBoardNode:dyadmino];
        
          // if it's a rack dyadmino
      } else {
        [self sendDyadminoHome:dyadmino byPoppingIn:YES];
      }
      
        // or if dyadmino is in rack but belongs on board (this seems to work)
    } else if ([dyadmino belongsOnBoard] && [dyadmino isInRack]) {
      [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_boardField];
      dyadmino.position = [_boardField getOffsetFromPoint:dyadmino.position];
      [self sendDyadminoToBoardNode:dyadmino];
      
        // otherwise, prepare it for hover
    } else {
      [self prepareForHoverThisDyadmino:dyadmino];
    }
  }
}

-(void)getReadyToPivotHoveringDyadmino:(Dyadmino *)dyadmino {

  [dyadmino removeActionsAndEstablishNotRotating];
  
    // this section just determines which pc to pivot on
    // it's not relevant after dyadmino is moved
  CGPoint touchBoardOffset = [_boardField getOffsetFromPoint:_beganTouchLocation];
  dyadmino.initialPivotAngle = [self findAngleInDegreesFromThisPoint:touchBoardOffset
                                                         toThisPoint:dyadmino.position];
  
  dyadmino.prePivotDyadminoOrientation = dyadmino.orientation;
  dyadmino.initialPivotPosition = dyadmino.position;
  [_boardField determinePivotOnPCForDyadmino:dyadmino];
  [dyadmino determinePivotAroundPointBasedOnPivotOnPC:_boardField.pivotOnPC];
}

-(void)handlePivotOfDyadmino:(Dyadmino *)dyadmino {
  
  CGPoint touchBoardOffset = [_boardField getOffsetFromPoint:_currentTouchLocation];

  SKNode *pivotGuide = [_boardField determineCurrentPivotGuide];
  
  NSLog(@"pivot guide position is %.1f, %.1f, dyadmino pivot position is %.1f, %.1f", pivotGuide.position.x, pivotGuide.position.y, dyadmino.pivotAroundPoint.x, dyadmino.pivotAroundPoint.y);
  
  [_boardField pivotGuidesBasedOnTouchLocation:touchBoardOffset forDyadmino:dyadmino];
  [dyadmino pivotBasedOnTouchLocation:touchBoardOffset andPivotOnPC:_boardField.pivotOnPC];
}

-(Dyadmino *)assignTouchEndedPointerToDyadmino:(Dyadmino *)dyadmino {
    // rack dyadmino only needs pointer if it's still on board
  if ([dyadmino belongsInRack] && [dyadmino isOnBoard]) {
    _recentRackDyadmino = dyadmino;
  }

  _touchedDyadmino = nil;
  return dyadmino;
}

-(void)prepareForHoverThisDyadmino:(Dyadmino *)dyadmino {
  _hoveringDyadmino = dyadmino;
  
    // establish the closest board node, without snapping just yet
  dyadmino.tempBoardNode = [self findSnapPointClosestToDyadmino:dyadmino];

    // update cells for placement
  NSLog(@"update cells for placed dyadmino");
  [self updateCellsForPlacedDyadmino:dyadmino];
  
    // start hovering
  [dyadmino removeActionsAndEstablishNotRotating];
  [dyadmino startHovering];
  [_boardField hidePivotGuideAndShowPrePivotGuideForDyadmino:dyadmino];
}

-(void)sendDyadminoHome:(Dyadmino *)dyadmino byPoppingIn:(BOOL)poppingIn {
  
      // reposition if dyadmino is rack dyadmino
  if (dyadmino.parent == _boardField && [dyadmino belongsInRack]) {
    CGPoint newPosition = [self addToThisPoint:dyadmino.position thisPoint:_boardField.position];
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_rackField];
    dyadmino.position = newPosition;
  }

  [self updateCellsForRemovedDyadmino:dyadmino];
  
  [dyadmino endTouchThenHoverResize];
    // this makes nil tempBoardNode
  [dyadmino goHomeByPoppingIn:poppingIn];

    // this ensures that pivot guide doesn't disappear if rack exchange
  if (dyadmino == _hoveringDyadmino) {
    [_boardField hideAllPivotGuides];
  }
  
    // make nil all pointers
  if (dyadmino == _recentRackDyadmino && [_recentRackDyadmino isInRack]) {
    _recentRackDyadmino = nil;
  }
  if (dyadmino == _hoveringDyadmino) {
    _hoveringDyadmino = nil;
  }
  
    // this ensures that dyadmino is properly oriented and positioned before
    // re-updating the cells of its original home node
  if ([dyadmino belongsOnBoard]) {
    [self updateCellsForPlacedDyadmino:dyadmino];
  }
}

-(void)sendDyadminoToBoardNode:(Dyadmino *)dyadmino {
  [self updateCellsForPlacedDyadmino:dyadmino];
  [dyadmino goToBoardNode];
}

#pragma mark - button methods

-(void)handleButtonPressed {
  
      /// swap button
  if (_buttonPressed == _topBar.swapButton) {
    if (!_swapMode) {
      [self toggleSwapField];
    }
    
      /// togglePC button
  } else if (_buttonPressed == _topBar.togglePCModeButton) {
    [self.ourGameEngine toggleBetweenLetterAndNumberMode];
    
      /// play button
  } else if (_buttonPressed == _topBar.playDyadminoButton) {
    [self playDyadmino:_recentRackDyadmino];
    
      /// cancel button
  } else if (_buttonPressed == _topBar.cancelButton) {
      // if in swap mode, cancel swap
    if (_swapMode) {
      [self cancelSwappedDyadminoes];
      [self toggleSwapField];
      
        // else send dyadmino home
    } else if (_hoveringDyadmino) {
      [self sendDyadminoHome:_hoveringDyadmino byPoppingIn:NO];

        // recent rack dyadmino is sent home
    } else if (_recentRackDyadmino) {
      [self sendDyadminoHome:_recentRackDyadmino byPoppingIn:YES];
    }
    
      /// done button
  } else if (_buttonPressed == _topBar.doneTurnButton) {
    if (!_swapMode) {
      [self finalisePlayerTurn];
    } else if (_swapMode) {
      if ([self finaliseSwap]) {
        [self toggleSwapField];
      }
    }
    
      /// debug button
  } else if (_buttonPressed == _topBar.debugButton) {
    [self debugButtonPressed];
  }
}

-(void)toggleSwapField {
    // TODO: move animations at some point
    // FIXME: make better animation
    // otherwise toggle
  if (_swapMode) { // swap mode on, so turn off
    _swapFieldActionInProgress = YES;
    
    SKAction *moveAction = [SKAction moveTo:CGPointMake(0.f, 0.f) duration:kConstantTime];
    SKAction *completionAction = [SKAction runBlock:^{
      _swapFieldActionInProgress = NO;
      _swapField.hidden = YES;
      _swapMode = NO;
      [self hideBoardCover];
    }];
    SKAction *sequenceAction = [SKAction sequence:@[moveAction, completionAction]];
    [_swapField runAction:sequenceAction];
    
    if (_boardField.position.y > _boardField.highestYPos) {
      CGFloat swapBuffer = _boardField.position.y - _boardField.highestYPos;
      SKAction *moveBoardAction = [SKAction moveToY:_boardField.position.y - swapBuffer duration:kConstantTime];
      [_boardField runAction:moveBoardAction];
    }
    
  } else { // swap mode off, turn on
    _swapFieldActionInProgress = YES;
    
    _swapField.hidden = NO;
    SKAction *moveAction = [SKAction moveTo:CGPointMake(0.f, kRackHeight) duration:kConstantTime];
    SKAction *completionAction = [SKAction runBlock:^{
      _swapFieldActionInProgress = NO;
      _swapMode = YES;
      [self revealBoardCover];
    }];
    SKAction *sequenceAction = [SKAction sequence:@[moveAction, completionAction]];
    [_swapField runAction:sequenceAction];
    SKAction *moveBoardAction = [SKAction moveToY:_boardField.position.y + kRackHeight duration:kConstantTime];
    [_boardField runAction:moveBoardAction];
  }
}

-(void)cancelSwappedDyadminoes {
  for (Dyadmino *dyadmino in self.myPlayer.dyadminoesInRack) {
    if (dyadmino.belongsInSwap) {
      dyadmino.belongsInSwap = NO;
      [dyadmino goHomeByPoppingIn:NO];
    }
  }
}

#pragma mark - engine interaction methods

-(BOOL)finaliseSwap {
  NSMutableArray *toPile = [NSMutableArray new];
  
  for (Dyadmino *dyadmino in self.myPlayer.dyadminoesInRack) {
    if ([dyadmino belongsInSwap]) {
      [toPile addObject:dyadmino];
    }
  }
  
    // if swapped dyadminoes is greater than pile count, cancel
  if (toPile.count > [self.ourGameEngine getCommonPileCount]) {
    [_topBar flashLabelNamed:@"message" withText:@"this is more than the pile count"];
    return NO;
    
      // else, proceed with swap
  } else {

      // first take care of views
    for (Dyadmino *dyadmino in toPile) {
      dyadmino.belongsInSwap = NO;
      
        // TODO: this should be a better animation
        // dyadmino is already a child of rackField,
        // so no need to send dyadmino home through myScene's sendDyadmino method
      [dyadmino goHomeByPoppingIn:NO];
      [dyadmino removeFromParent];
    }
    
      // then swap in the logic
    [self.ourGameEngine swapTheseDyadminoes:toPile fromPlayer:self.myPlayer];
    
    [self layoutOrRefreshRackFieldAndDyadminoes];
      // update views
    [self updatePileCountLabel];
    [_topBar flashLabelNamed:@"log" withText:@"swapped"];
    return YES;
  }
}

-(void)playDyadmino:(Dyadmino *)dyadmino {
    // establish that dyadmino is indeed a rack dyadmino placed on the board
  if ([dyadmino belongsInRack] && [dyadmino isOnBoard]) {
    
      // confirm that the dyadmino was successfully played before proceeding with anything else
    if ([self.ourGameEngine playOnBoardThisDyadmino:dyadmino fromRackOfPlayer:self.myPlayer]) {
      
        // do cleanup, dyadmino's home node is now the board node
      dyadmino.homeNode = dyadmino.tempBoardNode;
      dyadmino.tempBoardNode = nil;
      [dyadmino unhighlightOutOfPlay];
      
        // empty pointers
      _recentRackDyadmino = nil;
      _hoveringDyadmino = nil;
    }
  }
  [self layoutOrRefreshRackFieldAndDyadminoes];
}

-(void)finalisePlayerTurn {
    // no recent rack dyadmino on board
  if (!_recentRackDyadmino) {
    while ([self.ourGameEngine getCommonPileCount] >= 1 && self.myPlayer.dyadminoesInRack.count < 6) {
      [self.ourGameEngine putDyadminoFromPileIntoRackOfPlayer:self.myPlayer];
    }

  [self layoutOrRefreshRackFieldAndDyadminoes];
  
    // update views
  [self updatePileCountLabel];
  [_topBar flashLabelNamed:@"chord" withText:@"C major triad"];
  [_topBar updateLabelNamed:@"score" withText:@"score: 3"];
  [_topBar flashLabelNamed:@"log" withText:@"turn done"];
  }
}

#pragma mark - update methods

-(void)update:(CFTimeInterval)currentTime {
  
  [self updateForDoubleTap:currentTime];
  [self updateDyadmino:_hoveringDyadmino forHover:currentTime];
  
    // snap back somewhat from board bounds
    // TODO: this works, but it feels jumpy
  [self updateForBoardSnapBack];
  
  [self updateForButtons];
  
    // test
//  if ([_hoveringDyadmino isHovering]) {
//    [_topBar updateLabelNamed:@"log" withText:@"dyadmino is hovering"];
//  } else {
//    [_topBar updateLabelNamed:@"log" withText:@"dyadmino is not hovering"];
//  }
}

-(void)updateForButtons {
    // while *not* in swap mode...
  if (!_swapMode) {
    [_topBar disableButton:_topBar.cancelButton];
    
      // play button is enabled when there's a rack dyadmino on board
      // and no dyadmino is touched or hovering
    if (_recentRackDyadmino && !_touchedDyadmino && !_hoveringDyadmino) {
      [_topBar enableButton:_topBar.playDyadminoButton];
    } else {
      [_topBar disableButton:_topBar.playDyadminoButton];
    }
    
    if ((_recentRackDyadmino || _hoveringDyadmino) && ![self isFirstDyadmino:_hoveringDyadmino]) {
      [_topBar enableButton:_topBar.cancelButton];
    } else {
      [_topBar disableButton:_topBar.cancelButton];
    }
    
      // done button is enabled only when no recent rack dyadmino
      // and no dyadmino is touched or hovering
    if (!_touchedDyadmino && !_recentRackDyadmino && !_hoveringDyadmino) {
      [_topBar enableButton:_topBar.doneTurnButton];
    } else {
      [_topBar disableButton:_topBar.doneTurnButton];
    }
    
      // ...these are the criteria by which swap button is enabled
      // swap button cannot have any rack dyadminoes on board
      // FIXME: swap button also is disabled when any dyadmino has been played
    if ([_touchedDyadmino isOnBoard] || _recentRackDyadmino) {
      [_topBar disableButton:_topBar.swapButton];
    } else if (!_touchedDyadmino || [_touchedDyadmino isInRack]) {
      [_topBar enableButton:_topBar.swapButton];
    }
    
      // if in swap mode, cancel button cancels swap, done button finalises swap
  } else if (_swapMode) {
    [_topBar enableButton:_topBar.cancelButton];
    [_topBar enableButton:_topBar.doneTurnButton];
    [_topBar disableButton:_topBar.swapButton];
  }
}

-(void)updateForDoubleTap:(CFTimeInterval)currentTime {
  if (_canDoubleTap) {
    if (_doubleTapTime == 0.f) {
      _doubleTapTime = currentTime;
    }
  }
  
  if (_doubleTapTime != 0.f && currentTime > _doubleTapTime + kDoubleTapTime) {
    _canDoubleTap = NO;
    _hoveringDyadmino.canFlip = NO;
    _doubleTapTime = 0.f;
  }
}

-(void)updateForBoardSnapBack {
  if (!_currentTouch) {
    
      // tweak with this number, maybe make it dynamic so that it "snaps" more
    CGFloat thisDistance = 1.f;
    
    CGFloat swapBuffer = 0.f;
    if (_swapMode) {
      swapBuffer = kRackHeight; // the height of the swap field
    }
    
    CGFloat lowestXBuffer = _boardField.lowestXPos + kDyadminoFaceWideRadius * 0.5;
    if (_boardField.position.x < lowestXBuffer) {
      _boardField.position = CGPointMake(_boardField.position.x + thisDistance, _boardField.position.y);
      _boardField.homePosition = _boardField.position;
    }
    CGFloat lowestYBuffer = _boardField.lowestYPos + kDyadminoFaceRadius * 0.5;
    if (_boardField.position.y < lowestYBuffer) {
      _boardField.position = CGPointMake(_boardField.position.x, _boardField.position.y + thisDistance);
      _boardField.homePosition = _boardField.position;
    }
    CGFloat highestXBuffer = _boardField.highestXPos - kDyadminoFaceWideRadius * 0.5;
    if (_boardField.position.x > highestXBuffer) {
      _boardField.position = CGPointMake(_boardField.position.x - thisDistance, _boardField.position.y);
      _boardField.homePosition = _boardField.position;
    }
    CGFloat highestYBuffer = _boardField.highestYPos - kDyadminoFaceRadius * 0.5;
    if (_boardField.position.y > highestYBuffer + swapBuffer) {
      _boardField.position = CGPointMake(_boardField.position.x, _boardField.position.y - thisDistance);
      _boardField.homePosition = _boardField.position;
    }
  }
}

-(void)updateDyadmino:(Dyadmino *)dyadmino forHover:(CFTimeInterval)currentTime {
  if ([dyadmino isHovering]) {
    if (_hoverTime == 0.f) {
      _hoverTime = currentTime;
    }
  }
  
    // reset hover time if continues to hover
  if ([dyadmino continuesToHover]) {
    _hoverTime = currentTime;
    dyadmino.hoveringStatus = kDyadminoHovering;
  }
  
  if (_hoverTime != 0.f && currentTime > _hoverTime + kAnimateHoverTime) {
    _hoverTime = 0.f;
    
      // finish status
    [dyadmino setToHomeZPosition];
    
    [dyadmino finishHovering];
//    dyadmino.tempReturnOrientation = dyadmino.orientation;
  }
  
    // if finished hovering
  if ([dyadmino isOnBoard] &&
      [dyadmino isFinishedHovering] &&
      _touchedDyadmino != dyadmino) {
    
      // finish hovering only if placement is legal
    PhysicalPlacementResult placementResult =
    [_boardField validatePlacingDyadmino:dyadmino
                             onBoardNode:dyadmino.tempBoardNode];
    
      // handle placement results:
    
      // no error
    if (placementResult == kNoError) {
      if ([dyadmino belongsOnBoard]) {
          // this is the only place where a board dyadmino's tempBoardNode becomes its new homeNode
        dyadmino.homeNode = dyadmino.tempBoardNode;
      }
      [_boardField hideAllPivotGuides];
      [dyadmino animateEaseIntoNodeAfterHover];
      _hoveringDyadmino = nil;
     
        // lone dyadmino
    } else if (placementResult == kErrorLoneDyadmino) {
      [_topBar flashLabelNamed:@"message" withText:@"no lone dyadminoes!"];
      [dyadmino keepHovering];
      
        // stacked dyadminoes
    } else if (placementResult == kErrorStackedDyadminoes) {
      [_topBar flashLabelNamed:@"message" withText:@"can't stack dyadminoes!"];
      [dyadmino keepHovering];
    }
  }
}

#pragma mark - label methods

-(void)updatePileCountLabel {
  [_topBar updateLabelNamed:@"pileCount"
                   withText:[NSString stringWithFormat:@"in pile: %lu",
                             (unsigned long)[self.ourGameEngine getCommonPileCount]]];
}

#pragma mark - board cover methods

-(void)revealBoardCover {
    // TODO: make this animated
  _boardCover.hidden = NO;
  _boardCover.zPosition = kZPositionBoardCover;
}

-(void)hideBoardCover {
  _boardCover.hidden = YES;
  _boardCover.zPosition = kZPositionBoardCoverHidden;
}

#pragma mark - board interaction methods

-(void)updateCellsForPlacedDyadmino:(Dyadmino *)dyadmino {
  if (dyadmino.tempBoardNode) {
    [_boardField updateCellsForDyadmino:dyadmino placedOnBoardNode:dyadmino.tempBoardNode];
  } else {
    [_boardField updateCellsForDyadmino:dyadmino placedOnBoardNode:dyadmino.homeNode];
  }
}

-(void)updateCellsForRemovedDyadmino:(Dyadmino *)dyadmino {
  if (dyadmino.tempBoardNode) {
    [_boardField updateCellsForDyadmino:dyadmino removedFromBoardNode:dyadmino.tempBoardNode];
  } else {
    [_boardField updateCellsForDyadmino:dyadmino removedFromBoardNode:dyadmino.homeNode];
  }
}

#pragma mark - touch helper methods

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  [self touchesEnded:touches withEvent:event];
}

-(CGPoint)findTouchLocationFromTouches:(NSSet *)touches {
  CGPoint uiTouchLocation = [[touches anyObject] locationInView:self.view];
  return CGPointMake(uiTouchLocation.x, self.frame.size.height - uiTouchLocation.y);
}

#pragma mark - dyadmino helper methods

-(void)determineCurrentSectionOfDyadmino:(Dyadmino *)dyadmino {
    // this the ONLY place that determines current section of dyadmino
    // this is the ONLY place that sets dyadmino's belongsInSwap to YES
  
    // if it's pivoting, it's on the board, period
    // it's also on board, if not in swap and above rack and below top bar
  if (_pivotInProgress || (!_swapMode && _currentTouchLocation.y - _touchOffsetVector.y >= kRackHeight &&
      _currentTouchLocation.y - _touchOffsetVector.y < self.frame.size.height - kTopBarHeight)) {
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_boardField];
    dyadmino.isInTopBar = NO;
    
      // it's in swap
  } else if (_swapMode && _currentTouchLocation.y - _touchOffsetVector.y > kRackHeight) {
    dyadmino.belongsInSwap = YES;
    dyadmino.isInTopBar = NO;

    // if in rack field, doesn't matter if it's in swap
  } else if (_currentTouchLocation.y - _touchOffsetVector.y <= kRackHeight) {
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_rackField];
    dyadmino.belongsInSwap = NO;
    dyadmino.isInTopBar = NO;

      // else it's in the top bar, but this is a clumsy workaround, so be careful!
  } else if (!_swapMode && _currentTouchLocation.y - _touchOffsetVector.y >=
             self.frame.size.height - kTopBarHeight) {
//    NSLog(@"dyadmino is in top bar");
    dyadmino.isInTopBar = YES;
  }
}

-(CGPoint)getOffsetForTouchPoint:(CGPoint)touchPoint forDyadmino:(Dyadmino *)dyadmino {
  CGPoint touchOffset;
  if (dyadmino.parent == _boardField) {
    touchOffset = [_boardField getOffsetForPoint:touchPoint withTouchOffset:_touchOffsetVector];
  } else {
    touchOffset = [self subtractFromThisPoint:touchPoint thisPoint:_touchOffsetVector];
  }
  return touchOffset;
}

-(Dyadmino *)selectDyadminoFromTouchNode:(SKNode *)touchNode andTouchPoint:(CGPoint)touchPoint {
    // also establishes if pivot is in progress; touchOffset isn't relevant for this method

    // if we're in hovering mode...
  if ([_hoveringDyadmino isHovering]) {
    NSLog(@"we're in hovering mode");
    
      // accommodate if it's on board
    CGPoint touchBoardOffset = [_boardField getOffsetFromPoint:touchPoint];

      // if touch point is close enough, just rotate
    if ([self getDistanceFromThisPoint:touchBoardOffset toThisPoint:_hoveringDyadmino.position] <
        kDistanceForTouchingHoveringDyadmino) {
      NSLog(@"hovering, not touched, so just rotate");
      return _hoveringDyadmino;
 
        // otherwise, we're pivoting, so establish that
    } else if ([self getDistanceFromThisPoint:touchBoardOffset toThisPoint:_hoveringDyadmino.position] <
            kMaxDistanceForPivot) {
      NSLog(@"establish pivot in progress");
      _pivotInProgress = YES;
      _hoveringDyadmino.canFlip = NO;
      return _hoveringDyadmino;
    }
//    NSLog(@"board moved");
  }
  
  NSLog(@"we're NOT in hovering mode");
    //--------------------------------------------------------------------------
  
    // otherwise, first restriction is that the node being touched is the dyadmino
  Dyadmino *dyadmino;
  if ([touchNode isKindOfClass:[Dyadmino class]]) {
    dyadmino = (Dyadmino *)touchNode;
  } else if ([touchNode.parent isKindOfClass:[Dyadmino class]]) {
    dyadmino = (Dyadmino *)touchNode.parent;
  } else if ([touchNode.parent.parent isKindOfClass:[Dyadmino class]]) {
    dyadmino = (Dyadmino *)touchNode.parent.parent;
  } else {
    return nil;
  }
    
    // second restriction is that touch point is close enough based on following criteria:
    // if dyadmino is on board, not hovering and thus locked in a node, and we're not in swap mode...
  [self determineCurrentSectionOfDyadmino:dyadmino];

  if ([dyadmino isOnBoard] && !_swapMode) {

      // accommodate the fact that dyadmino's position is now relative to board
    CGPoint relativeToBoardPoint = [_boardField getOffsetFromPoint:touchPoint];
    if ([self getDistanceFromThisPoint:relativeToBoardPoint toThisPoint:dyadmino.position] <
        kDistanceForTouchingRestingDyadmino) {
      return dyadmino;
    }
      // if dyadmino is in rack...
  } else if ([dyadmino isInRack] || [dyadmino isOrBelongsInSwap]) {
    if ([self getDistanceFromThisPoint:touchPoint toThisPoint:dyadmino.position] <
        _rackField.xIncrementInRack) {
      return dyadmino;
    }
  }
  
    // otherwise, dyadmino is not close enough
  return nil;
}

-(SnapPoint *)findSnapPointClosestToDyadmino:(Dyadmino *)dyadmino {
  id arrayOrSetToSearch;
  
if (!_swapMode && [dyadmino isOnBoard]) {
    if (dyadmino.orientation == kPC1atTwelveOClock || dyadmino.orientation == kPC1atSixOClock) {
      arrayOrSetToSearch = _boardField.snapPointsTwelveOClock;
    } else if (dyadmino.orientation == kPC1atTwoOClock || dyadmino.orientation == kPC1atEightOClock) {
      arrayOrSetToSearch = _boardField.snapPointsTwoOClock;
    } else if (dyadmino.orientation == kPC1atFourOClock || dyadmino.orientation == kPC1atTenOClock) {
      arrayOrSetToSearch = _boardField.snapPointsTenOClock;
    }
    
  } else if ([dyadmino isInRack] || [dyadmino isOrBelongsInSwap]) {
    arrayOrSetToSearch = _rackField.rackNodes;
  }
  
    // get the closest snapPoint
  SnapPoint *closestSnapPoint;
  CGFloat shortestDistance = self.frame.size.height;
  
  for (SnapPoint *snapPoint in arrayOrSetToSearch) {
    CGFloat thisDistance = [self getDistanceFromThisPoint:dyadmino.position
                                              toThisPoint:snapPoint.position];
    if (thisDistance < shortestDistance) {
      shortestDistance = thisDistance;
      closestSnapPoint = snapPoint;
    }
  }
  return closestSnapPoint;
}

-(void)removeDyadmino:(Dyadmino *)dyadmino fromParentAndAddToNewParent:(SKSpriteNode *)newParent {
  if (dyadmino && newParent && dyadmino.parent != newParent) {
    [dyadmino removeFromParent];
    [newParent addChild:dyadmino];
  }
}

#pragma mark - delegate methods

-(BOOL)isFirstDyadmino:(Dyadmino *)dyadmino {
  if (self.ourGameEngine.dyadminoesOnBoard.count == 1 &&
      dyadmino == [self.ourGameEngine.dyadminoesOnBoard anyObject]) {
    return YES;
  } else {
    return NO;
  }
}

#pragma mark - debugging methods

-(void)debugButtonPressed {

  if (!_dyadminoesHidden) {
    for (Dyadmino *dyadmino in _boardField.children) {
      if ([dyadmino isKindOfClass:[Dyadmino class]])
      dyadmino.hidden = YES;
    }
    _dyadminoesHidden = YES;
  } else {
    for (Dyadmino *dyadmino in _boardField.children) {
      if ([dyadmino isKindOfClass:[Dyadmino class]])
      dyadmino.hidden = NO;
    }
    _dyadminoesHidden = NO;
  }

  NSLog(@"number of dyadminoes on board is %i, number of occupied cells is %i", self.ourGameEngine.dyadminoesOnBoard.count, _boardField.occupiedCells.count);
  
  NSLog(@"touched dyadmino %@, recent rack dyadmino %@, hovering dyadmino %@", _touchedDyadmino.name, _recentRackDyadmino.name, _hoveringDyadmino.name);
  
}

@end
