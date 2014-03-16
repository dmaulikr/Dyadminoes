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

@interface MyScene () <FieldNodeDelegate>
@end

  // TODO: put board cells on their own sprite nodes
  // TODO: board cells need coordinates

  // after do board coordinates
  // TODO: put initial dyadmino on board
  // TODO: board nodes expand outward, don't establish them at first
  // TODO: check nodes to ensure that dyadminoes do not conflict on board, do not finish hovering if there's a conflict

  // easy fixes
  // FIXME: pivot touch should be measured against pc face, not dyadmino center;
  // establish this in selectDyadmino method, and then calculate distance in touchesMoved
  // to decide whether to pivot on that move; distance between pc face and dyadmino center is 21.1
  // (can probably calculate this from texture image)
  // FIXME: zPosition is based on parent node, add sprites to board when in play.
  // (otherwise, a hovering board dyadmino might still be below a resting rack dyadmino)

  // FIXME: make sure board dyadmino returns to its original spot and orientation if ended in rack;
  // this might only happen right now because legality isn't being checked
  // FIXME: make second tap of double tap to rotate hovering dyadmino times out after certain amount of time

  // leisurely TODOs
  // TODO: have animation between rotation frames
  // TODO: make bouncier animations
  // TODO: make dyadmino sent home shrink then reappear in rack
  // TODO: pivot guides
  // TODO: background cells more colourful

  // leave alone for now until better information about how Game Center works
  // TODO: make so that player, not dyadmino, knows about pcMode

@implementation MyScene {
  
    // sprites and nodes
  Rack *_rackField;
  Rack *_swapField;
  Board *_boardField;
  TopBar *_topBar;
  SKNode *_touchNode;

    // touches
  UITouch *_currentTouch;
  CGPoint _beganTouchLocation;
  CGPoint _currentTouchLocation;
  CGPoint _touchOffsetVector;
  CGPoint _boardShiftedAfterEachTouch;
  
    // bools and modes
  BOOL _swapMode;
  BOOL _rackExchangeInProgress;
  BOOL _dyadminoSnappedIntoMovement;
  BOOL _swapFieldActionInProgress;
  BOOL _boardBeingMoved;
  
    // pointers
  Dyadmino *_currentlyTouchedDyadmino;
  Dyadmino *_recentRackDyadmino;
  Dyadmino *_hoveringButNotTouchedDyadmino;
  SKSpriteNode *_buttonPressed;

    // hover and pivot properties
  BOOL _pivotInProgress;
  CFTimeInterval _hoverTime;
  
    // temporary
  SKLabelNode *_testLabelNode;
  
    // eventually move this to GameEngine, so it can add to dyadmino
  SKNode *_pivotGuide;
}

#pragma mark - init methods

-(id)initWithSize:(CGSize)size {
  if (self = [super initWithSize:size]) {
    self.name = @"myScene";
    self.ourGameEngine = [GameEngine new];
    self.myPlayer = [self.ourGameEngine getAssignedAsPlayer];
    _rackExchangeInProgress = NO;
    _buttonPressed = nil;
  }
  return self;
}

-(void)didMoveToView:(SKView *)view {
  [self layoutBoard];
  [self layoutSwapField];
  [self layoutTopBar];
  [self layoutOrRefreshRackFieldAndDyadminoes];
}

#pragma mark - layout methods

-(void)layoutBoard {
  self.backgroundColor = [SKColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];

  _boardField = [[Board alloc] initWithColor:kSkyBlue
                                        andSize:CGSizeMake(self.frame.size.width * 2.f, self.frame.size.height * 2.f)
                                 andAnchorPoint:CGPointZero
                                    andPosition:CGPointZero
                                   andZPosition:kZPositionBoard];
  [self addChild:_boardField];
  [_boardField layoutBoardCellsAndSnapPoints];
}

-(void)layoutSwapField {
    // initial instantiation of swap field sprite
  _swapField = [[Rack alloc] initWithFieldNodeType:kFieldNodeSwap
                                              andColour:kGold
                                                andSize:CGSizeMake(self.frame.size.width, kRackHeight)
                                         andAnchorPoint:CGPointZero
                                            andPosition:CGPointZero
                                           andZPosition:kZPositionSwapField
                                               andBoard:_boardField];
  _swapField.delegate = self;
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
  [_topBar populateWithButtons];
  [_topBar populateWithLabels];
  [self addChild:_topBar];
  [self updatePileCountLabel];
}

-(void)layoutOrRefreshRackFieldAndDyadminoes {
  if (!_rackField) {
    _rackField = [[Rack alloc] initWithFieldNodeType:kFieldNodeRack
                                                andColour:kFieldPurple
                                                  andSize:CGSizeMake(self.frame.size.width, kRackHeight)
                                           andAnchorPoint:CGPointZero
                                              andPosition:CGPointZero
                                             andZPosition:kZPositionRackField
                                                 andBoard:_boardField];
    _rackField.delegate = self;
    [self addChild:_rackField];
  }
  [_rackField layoutOrRefreshNodesWithCount:self.myPlayer.dyadminoesInRack.count];
  [_rackField repositionDyadminoes:self.myPlayer.dyadminoesInRack];
}

#pragma mark - touch methods

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  
    // this ensures no more than one touch at a time
  if (!_currentTouch) {
    _currentTouch = [touches anyObject];
  } else {
    return;
  }
    
  if (_swapFieldActionInProgress) {
    return;
  }
  
    // get touch location and touched node
  _beganTouchLocation = [self findTouchLocationFromTouches:touches];
  _currentTouchLocation = _beganTouchLocation;
  _touchNode = [self nodeAtPoint:_currentTouchLocation];
  NSLog(@"touchNode is %@ and has parent %@", _touchNode.name, _touchNode.parent.name);
  
    //--------------------------------------------------------------------------

    // if it's a dyadmino, dyadmino will not be nil
  Dyadmino *dyadmino = [self selectDyadminoFromTouchNode:_touchNode
                                           andTouchPoint:_currentTouchLocation];
  
    // if pivot not in progress, or pivot in progress but dyadmino is not close enough
  if (!_pivotInProgress || (_pivotInProgress && !dyadmino)) {
    
      // if board is touched, then it's being moved
    if (_touchNode.parent == _boardField && ![_touchNode isKindOfClass:[Dyadmino class]]) {
      _boardBeingMoved = YES;
      _boardShiftedAfterEachTouch = [self fromThisPoint:_beganTouchLocation subtractThisPoint:_boardField.position];
      return;
    }
  }
  
    // if it's a button, take care of it when touch ended
  if ([_topBar.buttonNodes containsObject:_touchNode]) {
    _buttonPressed = (SKSpriteNode *)_touchNode;
      // TODO: make distinction of button pressed better, of course
    _buttonPressed.alpha = 0.3f;
    return;
  }
    //--------------------------------------------------------------------------
  
    // otherwise, if it's a dyadmino
  if (dyadmino && !dyadmino.isRotating && !_currentlyTouchedDyadmino) {
    
    [dyadmino startTouchThenHoverResize];
    [self handleBeginTouchOfDyadmino:dyadmino];
  }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  
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
  
    // for both board and dyadmino movement
  _currentTouchLocation = [self findTouchLocationFromTouches:touches];
  
    // if board being moved, handle and return
  if (_boardBeingMoved) {
    _boardField.position = [self fromThisPoint:_currentTouchLocation subtractThisPoint:_boardShiftedAfterEachTouch];
    _boardShiftedAfterEachTouch = [self fromThisPoint:_currentTouchLocation subtractThisPoint:_boardField.position];
    return;
  }

    // nothing happens if there is no current dyadmino
  if (!_currentlyTouchedDyadmino) {
    return;
  }
  
  if (_swapFieldActionInProgress) {
    return;
  }
  
    //--------------------------------------------------------------------------
  
    // continue to reset hover count
  if ([_currentlyTouchedDyadmino isHovering]) {
    [_currentlyTouchedDyadmino keepHovering];
  }
  
    // this is the only place that sets dyadmino highlight to YES
    // dyadmino highlight is reset when sent home or finalised
  if ([_currentlyTouchedDyadmino belongsInRack] && !_swapMode) {
    [_currentlyTouchedDyadmino adjustHighlightIntoPlay];
  }
  
    //--------------------------------------------------------------------------
  
    // update currently touched dyadmino's section
  [self determineCurrentSectionOfDyadmino:_currentlyTouchedDyadmino];

    // if we're currently pivoting, just rotate and return
  if (_pivotInProgress) {
    [_currentlyTouchedDyadmino pivotBasedOnLocation:_currentTouchLocation];
    return;
  }
  
    // if it moved at all, it can no longer flip
  _currentlyTouchedDyadmino.canFlip = NO;
  
    // if rack dyadmino is moved to board, send home recentRack dyadmino
  if ([_currentlyTouchedDyadmino belongsInRack] &&
      [_currentlyTouchedDyadmino isOnBoard] &&
      _currentlyTouchedDyadmino != _recentRackDyadmino) {
    [self sendDyadminoHome:_recentRackDyadmino byPoppingIn:YES];
  }
  
    //--------------------------------------------------------------------------
  
    // A. determine whether to snap out, or keep moving if already snapped out
    // refer to proper snap node
  SnapPoint *snapPoint;
  if ([_currentlyTouchedDyadmino belongsInRack] || [_currentlyTouchedDyadmino belongsInSwap]) {
    snapPoint = _currentlyTouchedDyadmino.tempBoardNode;
  } else {
    snapPoint = _currentlyTouchedDyadmino.homeNode;
  }
  
  CGPoint reverseOffsetPoint = [self fromThisPoint:_currentTouchLocation subtractThisPoint:_touchOffsetVector];
  
  if (_dyadminoSnappedIntoMovement ||
      (!_dyadminoSnappedIntoMovement && [self getDistanceFromThisPoint:reverseOffsetPoint
      toThisPoint:snapPoint.position] > kDistanceForSnapOut)) {
      // if so, do initial setup; its current node now has no dyadmino, and it can no longer rotate
    _dyadminoSnappedIntoMovement = YES;

      // now move it
    if (_currentlyTouchedDyadmino.parent == _boardField) {
      _currentlyTouchedDyadmino.position =
        [self fromThisPoint:reverseOffsetPoint subtractThisPoint:_boardField.position];
    } else {
      _currentlyTouchedDyadmino.position = reverseOffsetPoint;
    }
    
    //--------------------------------------------------------------------------
    
      // if it's a rack dyadmino, then while movement is within rack, rearrange dyadminoes
    if (([_currentlyTouchedDyadmino belongsInRack] || [_currentlyTouchedDyadmino belongsInSwap]) &&
        ([_currentlyTouchedDyadmino isInRack] || [_currentlyTouchedDyadmino isOrBelongsInSwap])) {
      SnapPoint *rackNode = [self findSnapPointClosestToDyadmino:_currentlyTouchedDyadmino];
      
      [_rackField handleRackExchangeOfTouchedDyadmino:_currentlyTouchedDyadmino
                                             withDyadminoes:(NSMutableArray *)self.myPlayer.dyadminoesInRack
                                         andClosestRackNode:rackNode];
    }
  }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

    // this ensures no more than one touch at a time
  UITouch *thisTouch = [touches anyObject];
  if (thisTouch != _currentTouch) {
    return;
  }
  _currentTouch = nil;
  
  if (_swapFieldActionInProgress) {
    return;
  }
  
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
  }
  
    // nothing happens if there is no current dyadmino
  if (!_currentlyTouchedDyadmino) {
    return;
  }
    //--------------------------------------------------------------------------
  
  [self determineCurrentSectionOfDyadmino:_currentlyTouchedDyadmino];
  Dyadmino *dyadmino = [self assignCurrentDyadminoToPointer];
  
    // cleanup
  _pivotInProgress = NO;
  _touchOffsetVector = CGPointZero;
  _dyadminoSnappedIntoMovement = NO;

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
    } else if ([dyadmino isInTopBar]) {
      if (dyadmino.tempBoardNode) {
        [dyadmino goFromTopBarToTempBoardNode];
      } else {
        [self sendDyadminoHome:dyadmino byPoppingIn:NO];
      }
           
        // otherwise, prepare it for hover
    } else {
      _hoveringButNotTouchedDyadmino = dyadmino;
      [_hoveringButNotTouchedDyadmino startHovering];
      [self prepareTouchEndedDyadminoForHover];
    }
  }
}

#pragma mark - touch procedure methods

-(void)handleBeginTouchOfDyadmino:(Dyadmino *)dyadmino {
  _currentlyTouchedDyadmino = dyadmino;
  [self determineCurrentSectionOfDyadmino:_currentlyTouchedDyadmino];
  
  if (dyadmino.parent == _rackField) {
    _touchOffsetVector = [self fromThisPoint:_beganTouchLocation
                           subtractThisPoint:_currentlyTouchedDyadmino.position];
  } else {
    CGPoint boardOffsetPoint = [self addThisPoint:_currentlyTouchedDyadmino.position toThisPoint:_boardField.position];
    _touchOffsetVector = [self fromThisPoint:_beganTouchLocation subtractThisPoint:boardOffsetPoint];
  }
  
    // reset hover count
  if ([_currentlyTouchedDyadmino isHovering]) {
    [_currentlyTouchedDyadmino keepHovering];
  }
  
  [_currentlyTouchedDyadmino removeActionsAndEstablishNotRotating];
  
    //--------------------------------------------------------------------------
  
    // if it's still in the rack, it can still rotate
  if ([_currentlyTouchedDyadmino isInRack] || [_currentlyTouchedDyadmino isOrBelongsInSwap]) {
    _currentlyTouchedDyadmino.canFlip = YES;
  }
  
    // various prep
  _currentlyTouchedDyadmino.zPosition = kZPositionHoveredDyadmino;
  
    //--------------------------------------------------------------------------
  
    // if it's now about to pivot, just get pivot angle
  if (_pivotInProgress) {
    _currentlyTouchedDyadmino.initialPivotAngle = [self findAngleInDegreesFromThisPoint:_currentTouchLocation
                                                                            toThisPoint:_currentlyTouchedDyadmino.position];
    [_currentlyTouchedDyadmino determinePivotOnPC];
    return;
  }
  
    // if it's on the board and not already rotating, two possibilities
  if ([_currentlyTouchedDyadmino isOnBoard] && !_currentlyTouchedDyadmino.isRotating) {
    
      // 1. it's not hovering, so make it hover
    if (!_currentlyTouchedDyadmino.canFlip) {
      _currentlyTouchedDyadmino.canFlip = YES;
      
        // 2. it's already hovering, so tap inside to flip
    } else {
      [_currentlyTouchedDyadmino animateFlip];
    }
  }
}

-(Dyadmino *)assignCurrentDyadminoToPointer {
    // rack dyadmino only needs pointer if it's still on board
  if ([_currentlyTouchedDyadmino belongsInRack] && [_currentlyTouchedDyadmino isOnBoard]) {
    _recentRackDyadmino = _currentlyTouchedDyadmino;
  }
  
  Dyadmino *dyadmino = _currentlyTouchedDyadmino;
  _currentlyTouchedDyadmino = nil;
  return dyadmino;
}

-(void)prepareTouchEndedDyadminoForHover {
  
  if ([_hoveringButNotTouchedDyadmino isOnBoard]) {
    
      // establish the closest board node, without snapping just yet
    SnapPoint *boardNode = [self findSnapPointClosestToDyadmino:_hoveringButNotTouchedDyadmino];
    
      // if valid placement
    if ([self validateLegalityOfDyadmino:_hoveringButNotTouchedDyadmino onBoardNode:boardNode]) {
      _hoveringButNotTouchedDyadmino.tempBoardNode = boardNode;
      
        // change to new board node if it's a board dyadmino
      if ([_hoveringButNotTouchedDyadmino belongsOnBoard]) {
        _hoveringButNotTouchedDyadmino.homeNode = boardNode;
      }
      
        //      [_hoveringButNotTouchedDyadmino prepareStateForHoverWithBoardNode:boardNode];
      [_hoveringButNotTouchedDyadmino removeActionsAndEstablishNotRotating];
      [_hoveringButNotTouchedDyadmino startHovering];
      
    } else {
        // method to return to original place
    }
    
      // if it's in the top bar or the rack (doesn't matter whether it's a board or rack dyadmino)
  } else {
    
      // if it can still rotate, do so
    
    [self sendDyadminoHome:_hoveringButNotTouchedDyadmino byPoppingIn:NO];
  }
}

#pragma mark - button methods

-(void)handleButtonPressed {
  
    // swap dyadminoes
  if (_buttonPressed == _topBar.swapButton) {
    if (!_swapMode) {
      [self toggleSwapField];
    }
    
  } else if (_buttonPressed == _topBar.togglePCModeButton) {
    [self toggleBetweenLetterAndNumberMode];
    
  } else if (_buttonPressed == _topBar.playDyadminoButton) {
    [self playDyadmino];
    
  } else if (_buttonPressed == _topBar.cancelButton) {
    if (_swapMode) {
      [self cancelSwappedDyadminoes];
      [self toggleSwapField];
    }
    
  } else if (_buttonPressed == _topBar.doneTurnButton) {
    if (!_swapMode) {
      [self finalisePlayerTurn];
    } else if (_swapMode) {
      if ([self finaliseSwap]) {
        [self toggleSwapField];
      }
    }
    
  } else if (_buttonPressed == _topBar.logButton) {
    [self logRecentAndCurrentDyadminoes];
  }
}

-(void)toggleBetweenLetterAndNumberMode {
  
    // FIXME: will this affect other player's view of dyadminoes?
  for (Dyadmino *dyadmino in self.ourGameEngine.allDyadminoes) {
    if (dyadmino.pcMode == kPCModeLetter) {
      dyadmino.pcMode = kPCModeNumber;
    } else {
      dyadmino.pcMode = kPCModeLetter;
    }
    [dyadmino selectAndPositionSprites];
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
      [_boardField hideBoardCover];
    }];
    SKAction *sequenceAction = [SKAction sequence:@[moveAction, completionAction]];
    [_swapField runAction:sequenceAction];
    
  } else { // swap mode off, turn on
    _swapFieldActionInProgress = YES;
    
    _swapField.hidden = NO;
    SKAction *moveAction = [SKAction moveTo:CGPointMake(0.f, kRackHeight) duration:kConstantTime];
    SKAction *completionAction = [SKAction runBlock:^{
      _swapFieldActionInProgress = NO;
      _swapMode = YES;
      [_boardField revealBoardCover];
    }];
    SKAction *sequenceAction = [SKAction sequence:@[moveAction, completionAction]];
    [_swapField runAction:sequenceAction];
  }
}

#pragma mark - engine methods

-(BOOL)validateLegalityOfDyadmino:(Dyadmino *)dyadmino onBoardNode:(SnapPoint *)boardNode {
    // FIXME: obviously, this must work
  if ([dyadmino belongsInRack]) {
      // (as long as it doesn't conflict with other dyadminoes, not important if it scores points)
  } else {
      // (doesn't conflict with other dyadminoes, *and* doesn't break musical rules)
  }
  return YES;
}

-(void)cancelSwappedDyadminoes {
  for (Dyadmino *dyadmino in self.myPlayer.dyadminoesInRack) {
    if (dyadmino.belongsInSwap) {
      dyadmino.belongsInSwap = NO;
      [dyadmino goHomeByPoppingIn:NO];
    }
  }
}

-(BOOL)finaliseSwap {
  NSMutableArray *toPile = [NSMutableArray new];
  
  for (Dyadmino *dyadmino in self.myPlayer.dyadminoesInRack) {
    if ([dyadmino belongsInSwap]) {
      [toPile addObject:dyadmino];
    }
  }
  
    // if swapped dyadminoes is greater than pile count, cancel
  if (toPile.count > [self.ourGameEngine getCommonPileCount]) {
    [self updateMessageLabelWithString:@"This is more than the pile count"];
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
    [self updateMessageLabelWithString:@"swapped!"];
    return YES;
  }
}

-(void)playDyadmino {
    // establish that dyadmino is indeed a rack dyadmino placed on the board
  if ([_recentRackDyadmino belongsInRack] && [_recentRackDyadmino isOnBoard]) {
    
      // confirm that the dyadmino was successfully played before proceeding with anything else
    if ([self.ourGameEngine playOnBoardThisDyadmino:_recentRackDyadmino fromRackOfPlayer:self.myPlayer]) {
      
        // do cleanup, dyadmino's home node is now the board node
      _recentRackDyadmino.homeNode = _recentRackDyadmino.tempBoardNode;
      [_recentRackDyadmino unhighlightOutOfPlay];
      _recentRackDyadmino = nil;
      _hoveringButNotTouchedDyadmino = nil;
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
  [self updateMessageLabelWithString:@"done"];
  }
}

#pragma mark - update and reset methods

-(void)update:(CFTimeInterval)currentTime {
  
  if ([_hoveringButNotTouchedDyadmino isHovering]) {
    if (_hoverTime == 0.f) {
      _hoverTime = currentTime;
    }
  }
  
    // reset hover time if continues to hover
  if ([_hoveringButNotTouchedDyadmino continuesToHover]) {
    _hoverTime = currentTime;
    _hoveringButNotTouchedDyadmino.hoveringStatus = kDyadminoHovering;
  }
  
  if (_hoverTime != 0.f && currentTime > _hoverTime + kAnimateHoverTime) {
    _hoverTime = 0.f;
    
      // finish status
    [_hoveringButNotTouchedDyadmino setToHomeZPosition];
    [_hoveringButNotTouchedDyadmino finishHovering];
    _hoveringButNotTouchedDyadmino.tempReturnOrientation = _hoveringButNotTouchedDyadmino.orientation;
  }
  

    // ease into node after hovering
  if ([_hoveringButNotTouchedDyadmino isOnBoard] &&
      [_hoveringButNotTouchedDyadmino isFinishedHovering] &&
      _currentlyTouchedDyadmino != _hoveringButNotTouchedDyadmino) {
    [_hoveringButNotTouchedDyadmino animateEaseIntoNodeAfterHover];
    _hoveringButNotTouchedDyadmino = nil;
  }
    //--------------------------------------------------------------------------

    // handle buttons
    // TODO: if button enabling and disabling are animated, change this
  
    // while *not* in swap mode...
  if (!_swapMode) {
    [_topBar disableButton:_topBar.cancelButton];
    
        // these are the criteria by which play and done button is enabled
    if ([_recentRackDyadmino belongsInRack] && [_recentRackDyadmino isOnBoard] &&
        ![_hoveringButNotTouchedDyadmino isHovering] &&
        (_currentlyTouchedDyadmino == nil || [_currentlyTouchedDyadmino isInRack])) {
      [_topBar enableButton:_topBar.playDyadminoButton];
      [_topBar disableButton:_topBar.doneTurnButton];
    } else {
      [_topBar disableButton:_topBar.playDyadminoButton];
      [_topBar enableButton:_topBar.doneTurnButton];
    }
    
      // ...these are the criteria by which swap button is enabled
      // swap button cannot have any rack dyadminoes on board
    if ([_currentlyTouchedDyadmino isOnBoard] || _recentRackDyadmino) {
      [_topBar disableButton:_topBar.swapButton];
    } else if (!_currentlyTouchedDyadmino || [_currentlyTouchedDyadmino isInRack]) {
      [_topBar enableButton:_topBar.swapButton];
    }
    
      // if in swap mode, cancel button cancels swap, done button finalises swap
  } else if (_swapMode) {
    [_topBar enableButton:_topBar.cancelButton];
    [_topBar enableButton:_topBar.doneTurnButton];
    [_topBar disableButton:_topBar.swapButton];
  }
}

-(void)updatePileCountLabel {
  _topBar.pileCountLabel.text = [NSString stringWithFormat:@"pile %lu", (unsigned long)[self.ourGameEngine getCommonPileCount]];
}

-(void)sendDyadminoHome:(Dyadmino *)dyadmino byPoppingIn:(BOOL)poppingIn {
  
  [dyadmino goHomeByPoppingIn:poppingIn];
  [dyadmino endTouchThenHoverResize];
  
  [self determineCurrentSectionOfDyadmino:dyadmino];
  
  [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_rackField];
  if (dyadmino == _recentRackDyadmino && [_recentRackDyadmino isInRack]) {
    _recentRackDyadmino = nil;
  }
}

-(void)updateLogLabelWithString:(NSString *)string {
  _topBar.logLabel.text = string;
}

-(void)updateMessageLabelWithString:(NSString *)string {
  [_topBar.messageLabel removeAllActions];
  _topBar.messageLabel.text = string;
  SKAction *wait = [SKAction waitForDuration:2.f];
  SKAction *fadeColor = [SKAction colorizeWithColor:[UIColor clearColor] colorBlendFactor:1.f duration:0.5f];
  SKAction *finishAnimation = [SKAction runBlock:^{
    _topBar.messageLabel.text = @"";
    _topBar.messageLabel.color = [UIColor whiteColor];
  }];
  SKAction *sequence = [SKAction sequence:@[wait, fadeColor, finishAnimation]];
  [_topBar.messageLabel runAction:sequence];
}

#pragma mark - helper methods

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  [self touchesEnded:touches withEvent:event];
}

-(CGPoint)findTouchLocationFromTouches:(NSSet *)touches {
  CGPoint uiTouchLocation = [[touches anyObject] locationInView:self.view];
  return CGPointMake(uiTouchLocation.x, self.frame.size.height - uiTouchLocation.y);
}

-(void)determineCurrentSectionOfDyadmino:(Dyadmino *)dyadmino {
    // this the ONLY place that determines current section of dyadmino
    // this is the ONLY place that sets dyadmino's belongsInSwap to YES

    // if dyadmino is in swap, its parent is the rack, and stays as such
  if (_swapMode && _currentTouchLocation.y - _touchOffsetVector.y > kRackHeight) {
    dyadmino.belongsInSwap = YES;
    dyadmino.isInTopBar = NO;

    // if in rack field, doesn't matter if it's in swap
  } else if (_currentTouchLocation.y - _touchOffsetVector.y <= kRackHeight) {
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_rackField];
    dyadmino.belongsInSwap = NO;
    dyadmino.isInTopBar = NO;

      // if not in swap, it's in board when above rack and below top bar
  } else if (!_swapMode && _currentTouchLocation.y - _touchOffsetVector.y >= kRackHeight &&
      _currentTouchLocation.y - _touchOffsetVector.y < self.frame.size.height - kTopBarHeight) {
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_boardField];
    dyadmino.isInTopBar = NO;
    
      // else it's in the top bar
  } else if (!_swapMode && _currentTouchLocation.y - _touchOffsetVector.y >= self.frame.size.height - kTopBarHeight) {
    
      // this is a clumsy workaround...
    dyadmino.isInTopBar = YES;
  }
}

-(Dyadmino *)selectDyadminoFromTouchNode:(SKNode *)touchNode andTouchPoint:(CGPoint)touchPoint {
    // pointer to determine last dyadmino, depending on
    // whether moving board dyadmino while rack dyadmino is in play

    // if we're in hovering mode...
  if ([_hoveringButNotTouchedDyadmino isHovering]) {
    
      // accommodate if it's on board
    CGPoint relativeToBoardPoint = touchPoint;
    if (_hoveringButNotTouchedDyadmino.parent == _boardField) {
      relativeToBoardPoint = [self fromThisPoint:touchPoint subtractThisPoint:_boardField.position];
    }
    
      // if touch point is close enough, just rotate
    if ([self getDistanceFromThisPoint:relativeToBoardPoint toThisPoint:_hoveringButNotTouchedDyadmino.position] <
        kDistanceForTouchingHoveringDyadmino) {
      return _hoveringButNotTouchedDyadmino;
 
        // otherwise, we're pivoting, so establish that
    } else if ([self getDistanceFromThisPoint:relativeToBoardPoint toThisPoint:_hoveringButNotTouchedDyadmino.position] <
            kMaxDistanceForPivot) {
      _pivotInProgress = YES;
      
      _hoveringButNotTouchedDyadmino.prePivotDyadminoOrientation = _hoveringButNotTouchedDyadmino.orientation;
        // this is reset to zero only after eased into place
      if (CGPointEqualToPoint(_hoveringButNotTouchedDyadmino.prePivotPosition, CGPointZero)) {
        _hoveringButNotTouchedDyadmino.prePivotPosition = _hoveringButNotTouchedDyadmino.position;
      }
      
      [_hoveringButNotTouchedDyadmino removeActionsAndEstablishNotRotating];
      return _hoveringButNotTouchedDyadmino;
    }
  }
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
    CGPoint relativeToBoardPoint = [self fromThisPoint:touchPoint subtractThisPoint:_boardField.position];
    if ([self getDistanceFromThisPoint:relativeToBoardPoint toThisPoint:dyadmino.position] <
        kDistanceForTouchingLockedDyadmino) {
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

#pragma mark - debugging methods

-(void)logRecentAndCurrentDyadminoes {
  NSString *hoveringString = [NSString stringWithFormat:@"hovering not touched %@", [_hoveringButNotTouchedDyadmino logThisDyadmino]];
  NSString *recentRackString = [NSString stringWithFormat:@"recent rack %@", [_recentRackDyadmino logThisDyadmino]];
  NSString *currentString = [NSString stringWithFormat:@"current %@", [_currentlyTouchedDyadmino logThisDyadmino]];
  NSLog(@"%@, %@, %@", hoveringString, currentString, recentRackString);
  
  for (Dyadmino *dyadmino in self.myPlayer.dyadminoesInRack) {
    NSLog(@"%@ has homeNode %@, tempReturn %@, is child of %@, belongs in swap %i, and is at %.2f, %.2f and child of %@", dyadmino.name, dyadmino.homeNode.name, dyadmino.tempBoardNode.name, dyadmino.parent.name, dyadmino.belongsInSwap,
          dyadmino.position.x, dyadmino.position.y, dyadmino.parent.name);
  }
  
  NSLog(@"rack dyadmino on board is at %.2f, %.2f and child of %@", _recentRackDyadmino.position.x, _recentRackDyadmino.position.y, _recentRackDyadmino.parent.name);
  
  _boardField.position = CGPointZero;
  _boardShiftedAfterEachTouch = CGPointZero;
  
  if (_recentRackDyadmino) {
    [_recentRackDyadmino.pivotGuide removeFromParent];
    [_recentRackDyadmino addChild:_recentRackDyadmino.pivotGuide];
  }
}

@end
