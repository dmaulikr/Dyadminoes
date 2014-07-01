//
//  MyScene.m
//  Dyadminoes
//
//  Created by Bennett Lin on 1/20/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "MyScene.h"
#import "SceneViewController.h"
#import "SceneEngine.h"
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
#import "Match.h"
#import "DataDyadmino.h"
#import "SoundEngine.h"

#define kBackgroundBoardColour [SKColor darkGrayColor]
//#define kBackgroundBoardColour [SKColor colorWithPatternImage:[UIImage imageNamed:@"MaryFloral.jpeg"]]

@interface MyScene () <FieldNodeDelegate, DyadminoDelegate, BoardDelegate, UIAlertViewDelegate, UIActionSheetDelegate, MatchDelegate>

  // the dyadminoes that the player sees
@property (strong, nonatomic) NSArray *playerRackDyadminoes;
@property (strong, nonatomic) NSSet *boardDyadminoes;

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
  CGPoint _endTouchLocationToMeasureDoubleTap;
  CGPoint _touchOffsetVector;
  
    // bools and modes
  BOOL _swapMode;
  BOOL _rackExchangeInProgress;
  BOOL _swapFieldActionInProgress;
  BOOL _boardToBeMovedOrBeingMoved;
  BOOL _boardBeingCorrectedWithinBounds;
  BOOL _canDoubleTapForBoardZoom;
  BOOL _canDoubleTapForDyadminoFlip;
  BOOL _hoveringDyadminoToStayFixedWhileBoardMoves;
  BOOL _boardJustShiftedNotCorrected;
  BOOL _boardZoomedOut;
  
  SnapPoint *_uponTouchDyadminoNode;
  DyadminoOrientation _uponTouchDyadminoOrientation;
  
  SKSpriteNode *_soundedDyadminoFace;
  NSUInteger _hoveringDyadminoBeingCorrected;
  NSUInteger _hoveringDyadminoFinishedCorrecting;
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
  
  Player *_myPlayer;
}

#pragma mark - init methods

-(id)initWithSize:(CGSize)size {
  if (self = [super initWithSize:size]) {
//    self.backgroundColor = [SKColor clearColor];
    self.backgroundColor = kBackgroundBoardColour;
//    self.backgroundColor = [SKColor colorWithPatternImage:[UIImage imageNamed:@"page4.png"]];
    self.name = @"scene";
    self.mySoundEngine = [[SoundEngine alloc] init];
    self.mySceneEngine = [[SceneEngine alloc] init];
//    self.undoManager = [[NSUndoManager alloc] init];
  
    _rackExchangeInProgress = NO;
    _buttonPressed = nil;
    _hoveringDyadminoBeingCorrected = 0;
    _hoveringDyadminoFinishedCorrecting = 1;
    _boardZoomedOut = NO;
  }
  return self;
}

-(void)preLoad {
//  NSLog(@"preload called from scene");
  _myPlayer = self.myMatch.currentPlayer;
  [self addChild:self.mySoundEngine];
  [self populateRackArray];
  [self populateBoardSet];
}

-(void)didMoveToView:(SKView *)view {
//  NSLog(@"did move to view");
  [self layoutBoard];
//  NSLog(@"board laid out");
  [self layoutBoardCover];

    // this only needs the board dyadminoes to determine the board's cells ranges
    // this populates the board cells
  
  NSLog(@"layoutboard cells called from did move to view");
  [_boardField layoutBoardCellsAndSnapPointsOfDyadminoes:self.boardDyadminoes];
//  [_boardField reloadBackgroundImage];
//  NSLog(@"cells and snap points laid out");
  
  [self populateBoardWithDyadminoes];
//  NSLog(@"board populated with dyadminoes");
  [self layoutSwapField];
//  NSLog(@"swap field laid out");
  [self layoutTopBar];
//  NSLog(@"top bar laid out");
  [self layoutOrRefreshRackFieldAndDyadminoes];
//  NSLog(@"rack field and dyadminoes laid out and refreshed");
  [self handleDeviceOrientationChange:[UIDevice currentDevice].orientation];
}

#pragma mark - layout methods

-(void)populateRackArray {
    // keep player's order and orientation of dyadminoes until turn is submitted
  
  NSMutableArray *tempDyadminoArray = [[NSMutableArray alloc] initWithCapacity:_myPlayer.dataDyadminoesThisTurn.count];
  
  for (DataDyadmino *dataDyad in _myPlayer.dataDyadminoesThisTurn) {
      // only add if it's not in the holding container
      // if it is, then don't add because holding container is added to board set instead
    if (![self.myMatch.holdingContainer containsObject:dataDyad]) {
      Dyadmino *dyadmino = (Dyadmino *)self.mySceneEngine.allDyadminoes[dataDyad.myID - 1];
      dyadmino.myHexCoord = dataDyad.myHexCoord;
      dyadmino.orientation = dataDyad.myOrientation;
      dyadmino.myRackOrder = dataDyad.myRackOrder;
//      NSLog(@"this rack order is %i", dyadmino.myRackOrder);
        // not the best place to set tempReturnOrientation for dyadmino
      dyadmino.tempReturnOrientation = dyadmino.orientation;
      
      [dyadmino selectAndPositionSprites];
      [tempDyadminoArray addObject:dyadmino];
    }
  }
  
    // make sure dyadminoes are sorted
  NSSortDescriptor *sortByRackOrder = [[NSSortDescriptor alloc] initWithKey:@"myRackOrder" ascending:YES];
  self.playerRackDyadminoes = [tempDyadminoArray sortedArrayUsingDescriptors:@[sortByRackOrder]];
}

-(void)populateBoardSet {

    // figure out what the last turn was, and who played it, to set highlighting and animation
  NSDictionary *lastTurn = (NSDictionary *)[self.myMatch.turns lastObject];
  Player *lastPlayer = (Player *)[lastTurn valueForKey:@"player"];
  NSArray *lastContainer = (NSArray *)[lastTurn valueForKey:@"container"];
    // animate last played only if current player does not have dyadminoes in holding container
  BOOL animateLastPlayedDyadminoes = self.myMatch.holdingContainer.count == 0 ? YES : NO;
  
    // board must enumerate over both board and holding container dyadminoes
  NSMutableSet *tempDataEnumerationSet = [NSMutableSet setWithSet:self.myMatch.board];
  [tempDataEnumerationSet addObjectsFromArray:self.myMatch.holdingContainer];
  
  NSMutableSet *tempSet = [[NSMutableSet alloc] initWithCapacity:tempDataEnumerationSet.count];
  
  for (DataDyadmino *dataDyad in tempDataEnumerationSet) {
    Dyadmino *dyadmino = (Dyadmino *)self.mySceneEngine.allDyadminoes[dataDyad.myID - 1];
    dyadmino.myHexCoord = dataDyad.myHexCoord;
    dyadmino.orientation = dataDyad.myOrientation;
    dyadmino.myRackOrder = -1; // signifies it's not in rack
      // not the best place to set tempReturnOrientation here either
    dyadmino.tempReturnOrientation = dyadmino.orientation;
    
      // highlighting and animation
    
      // either animate last played dyadminoes, or highlight dyadminoes currently in holding container
    if (animateLastPlayedDyadminoes) {
      if ([lastContainer containsObject:dataDyad]) {
        [dyadmino animateDyadminoesRecentlyPlayed:(lastPlayer == _myPlayer)];
      }
    } else {
      if ([self.myMatch.holdingContainer containsObject:dataDyad]) {
        [dyadmino highlightBoardDyadmino];
      }
    }
    
    if (![tempSet containsObject:dyadmino]) {
      
      [dyadmino selectAndPositionSprites];
      [tempSet addObject:dyadmino];
    }
  }
  self.boardDyadminoes = [NSSet setWithSet:tempSet];
}

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

-(void)populateBoardWithDyadminoes {
  for (Dyadmino *dyadmino in self.boardDyadminoes) {
    dyadmino.delegate = self;
    
//    NSLog(@"dyadmino coord is %i, %i", dyadmino.myHexCoord.x, dyadmino.myHexCoord.y);
    
      // this is for the first dyadmino, which doesn't have a boardNode
      // and also other dyadminoes when reloading
    if (!dyadmino.homeNode) {
      NSMutableSet *snapPointsToSearch;
      switch (dyadmino.orientation) {
        case kPC1atTwelveOClock:
        case kPC1atSixOClock:
          snapPointsToSearch = _boardField.snapPointsTwelveOClock;
          break;
        case kPC1atTwoOClock:
        case kPC1atEightOClock:
          snapPointsToSearch = _boardField.snapPointsTwoOClock;
          break;
        case kPC1atFourOClock:
        case kPC1atTenOClock:
          snapPointsToSearch = _boardField.snapPointsTenOClock;
          break;
        default:
          break;
      }
      
      for (SnapPoint *snapPoint in snapPointsToSearch) {
        if ( snapPoint.myCell.hexCoord.x == dyadmino.myHexCoord.x && snapPoint.myCell.hexCoord.y == dyadmino.myHexCoord.y) {
          dyadmino.homeNode = snapPoint;
          dyadmino.tempBoardNode = dyadmino.homeNode;
        }
      }
    }
    
      //------------------------------------------------------------------------
    
      // update cells
    [self updateCellsForPlacedDyadmino:dyadmino andColour:YES];
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
  _topBar = [[TopBar alloc] initWithColor:kBarBrown
                                  andSize:CGSizeMake(self.frame.size.width, kTopBarHeight)
                           andAnchorPoint:CGPointZero
                              andPosition:CGPointMake(0, self.frame.size.height - kTopBarHeight)
                             andZPosition:kZPositionTopBar];
  _topBar.name = @"topBar";
  [_topBar populateWithButtons];
  [_topBar populateWithLabels];
  [self addChild:_topBar];
  [self updateLabels];
  [self updateButtonsForStaticState];
  
  _topBar.pileDyadminoesLabel.hidden = YES;
  _topBar.boardDyadminoesLabel.hidden = YES;
  _topBar.holdingContainerLabel.hidden = YES;
  _topBar.swapContainerLabel.hidden = YES;
}

-(void)layoutOrRefreshRackFieldAndDyadminoes {
  
  if (!_rackField) {
    _rackField = [[Rack alloc] initWithBoard:_boardField
                                   andColour:kPianoBlack
                                     andSize:CGSizeMake(self.frame.size.width, kRackHeight)
                              andAnchorPoint:CGPointZero
                                 andPosition:CGPointZero
                                andZPosition:kZPositionRackField];
    _rackField.delegate = self;
    _rackField.name = @"rack";
    [self addChild:_rackField];
  }
  [_rackField layoutOrRefreshNodesWithCount:self.playerRackDyadminoes.count];
  [_rackField repositionDyadminoes:self.playerRackDyadminoes withAnimation:NO];
  
  for (Dyadmino *dyadmino in self.playerRackDyadminoes) {
    dyadmino.delegate = self;
  }
}

-(void)handleDeviceOrientationChange:(UIDeviceOrientation)deviceOrientation {
  if ([self.mySceneEngine rotateDyadminoesBasedOnDeviceOrientation:deviceOrientation]) {
    [self.mySoundEngine soundDeviceOrientation];
  }
  
  [_topBar rotateButtonsBasedOnDeviceOrientation:deviceOrientation];
}

-(void)handlePinchGestureWithScale:(CGFloat)scale andVelocity:(CGFloat)velocity {
  NSLog(@"pinch scale %.2f, velocity %.2f", scale, velocity);
    // tweak these numbers
  if ((scale < .8f && !_boardZoomedOut) || (scale > 1.25f && _boardZoomedOut)) {
    [self toggleBoardZoom];
  }
}

#pragma mark - touch methods

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /// 1. first, make sure there's only one current touch
  
  if (!_currentTouch) {
    _currentTouch = [touches anyObject];
  } else {
    
      // handles ending previous touch
    [self endTouchFromTouches:nil];
    _currentTouch = [touches anyObject];
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
  NSLog(@"%@, zPosition %.2f", _touchNode.name, _touchNode.zPosition);
  NSLog(@"distance between double taps is %.2f", [self getDistanceFromThisPoint:_beganTouchLocation toThisPoint:_endTouchLocationToMeasureDoubleTap]);

    //--------------------------------------------------------------------------
    /// 3a. button pressed
  
    // if it's a button, take care of it when touch ended
  if ([_topBar.allButtons containsObject:_touchNode]) {
    
      // sound of button tapped
    [self.mySoundEngine soundButton:YES];
    _buttonPressed = (Button *)_touchNode;
      // TODO: make distinction of button pressed better, of course
    _buttonPressed.alpha = 0.3f;
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 3b. dyadmino touched
  
  Dyadmino *dyadmino = [self selectDyadminoFromTouchPoint:_currentTouchLocation];
  
  if (!_boardZoomedOut && ![dyadmino isInRack]) {
  
    if (!_canDoubleTapForDyadminoFlip && ![dyadmino isRotating]) {
      
          // register sound if dyadmino tapped
      if ((dyadmino && !_swapMode && !_pivotInProgress) || [dyadmino isInRack]) { // not sure if not being in swapMode is necessary
        [self.mySoundEngine soundTouchedDyadmino:dyadmino plucked:YES];
        
          // register sound if face tapped
      } else {
        SKSpriteNode *face = [self selectFaceFromTouchPoint:_currentTouchLocation];
        if (face && face.parent != _hoveringDyadmino) {
          [self.mySoundEngine soundTouchedDyadminoFace:face plucked:YES];
          _soundedDyadminoFace = face;
        }
      }
    }
  }
  
  if (dyadmino && !dyadmino.isRotating && !_touchedDyadmino && (!_boardZoomedOut || [dyadmino isInRack])) {
    _touchedDyadmino = dyadmino;
//    NSLog(@"begin touch or pivot of dyadmino");
    [self beginTouchOrPivotOfDyadmino:dyadmino];
  
    //--------------------------------------------------------------------------
    /// 3c. board about to be moved
  
    // if pivot not in progress, or pivot in progress but dyadmino is not close enough
    // then the board is touched and being moved
  } else if (!_pivotInProgress || (_pivotInProgress && !_touchedDyadmino)) {
    if (_touchNode == _boardField || _touchNode == _boardCover ||
        (_touchNode.parent == _boardField && (![_touchNode isKindOfClass:[Dyadmino class]] || _boardZoomedOut)) ||
        (_touchNode.parent.parent == _boardField && (![_touchNode.parent isKindOfClass:[Dyadmino class]] || _boardZoomedOut))) { // cell label, this one is necessary only for testing purposes
      
      if (_canDoubleTapForBoardZoom && !_hoveringDyadmino) {
        if ([self getDistanceFromThisPoint:_beganTouchLocation toThisPoint:_endTouchLocationToMeasureDoubleTap] < kDistanceToDoubleTap) {
          [self toggleBoardZoom];
        }
      }
      NSLog(@"board to be moved or being moved");
      _boardToBeMovedOrBeingMoved = YES;
      _canDoubleTapForBoardZoom = YES;
      
        // check to see if hovering dyadmino should stay with board or not
      if (_hoveringDyadmino) {
        [_boardField hideAllPivotGuides];
        _hoveringDyadminoToStayFixedWhileBoardMoves = NO;
        if ([_boardField validatePlacingDyadmino:_hoveringDyadmino onBoardNode:_hoveringDyadmino.tempBoardNode] != kNoError) {
          _hoveringDyadminoToStayFixedWhileBoardMoves = YES;
          NSLog(@"update cells for removed called from touches began");
          [self updateCellsForRemovedDyadmino:_hoveringDyadmino andColour:NO];
        }
      }

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
    _buttonPressed.alpha = (node == _buttonPressed) ? 0.3f : 1.f;
    return;
  }
  
    // register no touches moved while swap field is being toggled
  if (_swapFieldActionInProgress) {
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 2. next, update the touch location

  _currentTouchLocation = [self findTouchLocationFromTouches:touches];
  
    // if touch hits a dyadmino face, sound and continue...
  if (!_boardToBeMovedOrBeingMoved && !_touchedDyadmino) {
    SKSpriteNode *face = [self selectFaceFromTouchPoint:_currentTouchLocation];
    
    if (face && face.parent != _hoveringDyadmino) {
      if (!_soundedDyadminoFace) {
        [self.mySoundEngine soundTouchedDyadminoFace:face plucked:NO];
        _soundedDyadminoFace = face;
      } else {
        
      }
    } else {
      _soundedDyadminoFace = nil;
    }
  }
  
    //--------------------------------------------------------------------------
    /// 3a. board is being moved
  
    // if board is being moved, handle and return
  if (_boardToBeMovedOrBeingMoved) {
    [self moveBoard];
    return;
  }
  
    // check this *after* checking board move
    if (!_touchedDyadmino) {
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 3b part i: dyadmino is being moved, take care of the prepwork
  
    // update currently touched dyadmino's section
//  NSLog(@"determine current section from touches moved");
  [self determineCurrentSectionOfDyadmino:_touchedDyadmino];
  
    // if it moved beyond certain distance, it can no longer flip
  if ([self getDistanceFromThisPoint:_touchedDyadmino.position toThisPoint:_touchedDyadmino.homeNode.position] > kDistanceAfterCannotRotate) {
    _touchedDyadmino.canFlip = NO;
  }
  
    // touched dyadmino is now on board
  if ([_touchedDyadmino belongsInRack] && [_touchedDyadmino isOnBoard]) {
    
      // zoom back in
    if (_boardZoomedOut) {
      [self toggleBoardZoom];
    }
    
      // if rack dyadmino is moved to board, send home recentRack dyadmino
    if (_recentRackDyadmino && _touchedDyadmino != _recentRackDyadmino) {
      
      [self changeColoursAroundDyadmino:_recentRackDyadmino withSign:-1];
//      NSLog(@"send dyadmino home if rack dyadmino is moved to board");
      [self sendDyadminoHome:_recentRackDyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];
      
        // or same thing with hovering dyadmino (it will only ever be one or the other)
    } else if (_hoveringDyadmino && _touchedDyadmino != _hoveringDyadmino) {
//      NSLog(@"send dyadmino home if hovering dyadmino");
      [self sendDyadminoHome:_hoveringDyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];
    }
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
    
    self.playerRackDyadminoes = [_rackField handleRackExchangeOfTouchedDyadmino:_touchedDyadmino
                                     withDyadminoes:self.playerRackDyadminoes
                                 andClosestRackNode:rackNode];
  }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    /// 1. first check whether to even register the touch ended

    // this ensures no more than one touch at a time
  UITouch *thisTouch = [touches anyObject];
  _endTouchLocationToMeasureDoubleTap = [self findTouchLocationFromTouches:touches];
  
  if (thisTouch != _currentTouch) {
    return;
  }

  _currentTouch = nil;
  [self endTouchFromTouches:touches];
}

-(void)endTouchFromTouches:(NSSet *)touches {
  if (_swapFieldActionInProgress) {
    return;
  }
  
    //--------------------------------------------------------------------------
    /// 2a and b. handle button pressed or board moved
  
    // handle button that was pressed, ensure that touch is still on button when it ends
  if (_buttonPressed && touches) {
    SKNode *node = [self nodeAtPoint:[self findTouchLocationFromTouches:touches]];
    if (node == _buttonPressed) {
      
        // sound of button release
      [self.mySoundEngine soundButton:NO];
      [self handleButtonPressed];
    }
    _buttonPressed.alpha = 1.f;
    _buttonPressed = nil;
    return;
  }
  
    // board no longer being moved
  if (_boardToBeMovedOrBeingMoved) {
    _boardToBeMovedOrBeingMoved = NO;
    
      // take care of hovering dyadmino
    if (_hoveringDyadminoToStayFixedWhileBoardMoves) {
      _hoveringDyadmino.tempBoardNode = [self findSnapPointClosestToDyadmino:_hoveringDyadmino];
      [self updateCellsForPlacedDyadmino:_hoveringDyadmino andColour:NO];
    }
    
    _boardField.homePosition = _boardField.position;
  }
  
    // check this *after* checking board move
  if (!_touchedDyadmino) {
    return;
  }
    //--------------------------------------------------------------------------
    /// 2c. handle touched dyadmino
//  NSLog(@"determine currect section from end touch from touches");
  [self determineCurrentSectionOfDyadmino:_touchedDyadmino];
  Dyadmino *dyadmino = [self assignTouchEndedPointerToDyadmino:_touchedDyadmino];
  
  [self handleTouchEndOfDyadmino:dyadmino];
  
    // cleanup
  _pivotInProgress = NO;
  _touchOffsetVector = CGPointZero;
  _soundedDyadminoFace = nil;
}

#pragma mark - board methods

-(void)moveBoard {
  
    // if board isn't being corrected within bounds
  if (!_boardBeingCorrectedWithinBounds) {
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
    } else if (newPosition.y > (_boardField.highestYPos + swapBuffer)) {
      newY = _boardField.highestYPos + swapBuffer;
    }
    
    if (newPosition.x < _boardField.lowestXPos) {
      newX = _boardField.lowestXPos;
    } else if (newPosition.x > _boardField.highestXPos) {
      newX = _boardField.highestXPos;
    }
    
    CGPoint adjustedNewPosition = CGPointMake(newX, newY);
    
    if (_hoveringDyadminoToStayFixedWhileBoardMoves) {
      _hoveringDyadmino.position = [self addToThisPoint:_hoveringDyadmino.position
                                              thisPoint:[self subtractFromThisPoint:_boardField.position
                                                                          thisPoint:adjustedNewPosition]];
    }
    
      // move board to new position
    _boardField.position = adjustedNewPosition;
    
      // move home position to board position, after applying touch offset
    _boardField.homePosition = [self addToThisPoint:_boardField.position thisPoint:touchOffset];
  }
}

-(void)toggleBoardZoom {
  NSLog(@"board zoomed");
  if (_hoveringDyadmino) {
    [self sendDyadminoHome:_hoveringDyadmino byPoppingIn:YES andUpdatingBoardBounds:NO];
  }
  
  _boardZoomedOut = _boardZoomedOut ? NO : YES;
  [_boardField repositionCellsAndDyadminoesForZoomOut:_boardZoomedOut];
  
  for (Dyadmino *dyadmino in self.boardDyadminoes) {
    dyadmino.isZoomResized = dyadmino.isZoomResized ? NO : YES;
    dyadmino.position = dyadmino.tempBoardNode.position;
    [dyadmino selectAndPositionSprites];
  }
  if (_recentRackDyadmino) {
    _recentRackDyadmino.isZoomResized = _recentRackDyadmino.isZoomResized ? NO : YES;
    [_recentRackDyadmino selectAndPositionSprites];
    _recentRackDyadmino.position = _recentRackDyadmino.tempBoardNode.position;
  }
  
  [self.mySoundEngine soundBoardZoom];
}

#pragma mark - dyadmino methods

-(void)beginTouchOrPivotOfDyadmino:(Dyadmino *)dyadmino {
  
  if ([dyadmino isOnBoard]) {
    NSLog(@"update cells for removed dyadmino from begin touch");
    if (dyadmino != _hoveringDyadmino && ![dyadmino isRotating]) {
      [self updateCellsForRemovedDyadmino:dyadmino andColour:YES];
    } else {
      [self updateCellsForRemovedDyadmino:dyadmino andColour:NO];
    }
  }
  
    // record tempReturnOrientation only if it's settled and not hovering
  if (dyadmino != _hoveringDyadmino) {
    dyadmino.tempReturnOrientation = dyadmino.orientation;
    
      // board dyadmino sends recent rack dyadmino home upon touch
      // rack dyadmino will do so upon move out of rack
    if (_hoveringDyadmino && [dyadmino isOnBoard]) {
      NSLog(@"send dyadmino home if hovering dyadmino");
      [self sendDyadminoHome:_hoveringDyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];
    }
  }
  
  [dyadmino startTouchThenHoverResize];
  
  [self getReadyToMoveCurrentDyadmino:_touchedDyadmino];
  
    // if it's now about to pivot, just get pivot angle
  if (_pivotInProgress) {
    [self getReadyToPivotHoveringDyadmino:_hoveringDyadmino];
  }
  
    // if it's on the board and not already rotating, two possibilities
  if ([_touchedDyadmino isOnBoard] && !_touchedDyadmino.isRotating) {
    
    _uponTouchDyadminoNode = dyadmino.tempBoardNode;
    _uponTouchDyadminoOrientation = dyadmino.orientation;
    
      // 1. it's not hovering, so make it hover
    if (!_touchedDyadmino.canFlip) {
      _touchedDyadmino.canFlip = YES;
      _canDoubleTapForDyadminoFlip = YES;
      
        // 2. it's already hovering, so tap inside to flip
    } else {
      [_touchedDyadmino animateFlip];
    }
  }
}

-(void)getReadyToMoveCurrentDyadmino:(Dyadmino *)dyadmino {
//  NSLog(@"determine current section from get ready to move");
//  [self determineCurrentSectionOfDyadmino:dyadmino];
  
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
//      NSLog(@"touch ended of dyadmino belong in rack");
        // ...flip if possible, or send it home
      if (dyadmino.canFlip) {
        [dyadmino animateFlip];
      } else {
//        NSLog(@"handle touch end of dyadmino and send dyadmino home");
        if (dyadmino == _recentRackDyadmino) {
          [self sendDyadminoHome:dyadmino byPoppingIn:NO andUpdatingBoardBounds:YES];
        } else { // dyadmino never left rack, or is hovering
          [self sendDyadminoHome:dyadmino byPoppingIn:NO andUpdatingBoardBounds:NO];
        }
        [self soundDyadminoSettleClick];
      }
      
        // or if dyadmino is in top bar...
    } else if ([dyadmino isInTopBar]) {;
      
        // if it's a board dyadmino
//      NSLog(@"touch ended, and dyadmino is in top bar");
      if ([dyadmino.homeNode isBoardNode]) {
//        NSLog(@"its home node is board node, send dyadmino home");
        dyadmino.tempBoardNode = nil;
        [self sendDyadminoHome:dyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];
        
          // if it's a rack dyadmino (even if it was just recently on the board)
      } else {
        [self sendDyadminoHome:dyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];
      }
      
        // or if dyadmino is in rack but belongs on board (this seems to work)
    } else if ([dyadmino belongsOnBoard] && [dyadmino isInRack]) {
      dyadmino.tempBoardNode = nil;
      [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_boardField];
      dyadmino.position = [_boardField getOffsetFromPoint:dyadmino.position];
      [self sendDyadminoHome:dyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];
      
        // otherwise, prepare it for hover
    } else {
      [self prepareForHoverThisDyadmino:dyadmino];
    }
  }
}

-(void)prepareForHoverThisDyadmino:(Dyadmino *)dyadmino {
  _hoveringDyadmino = dyadmino;
  
    // establish the closest board node, without snapping just yet
  dyadmino.tempBoardNode = [self findSnapPointClosestToDyadmino:dyadmino];

    // update cells for placement
  [self updateCellsForPlacedDyadmino:dyadmino andColour:NO];
  
    // start hovering
  [dyadmino removeActionsAndEstablishNotRotating];
  
//  NSLog(@"prepare for hover, check");
  [self checkWhetherToEaseOrKeepHovering:dyadmino afterTouchJustEnded:YES];
  
//  NSLog(@"prepare for hover");
  if (dyadmino.isHovering || dyadmino.continuesToHover) {
//    NSLog(@"dyadmino hovering status is %i", dyadmino.hoveringStatus);
    if (!_canDoubleTapForDyadminoFlip && ![dyadmino isRotating]) {
      [_boardField hidePivotGuideAndShowPrePivotGuideForDyadmino:dyadmino];
    }
  }
}

-(void)sendDyadminoHome:(Dyadmino *)dyadmino byPoppingIn:(BOOL)poppingIn andUpdatingBoardBounds:(BOOL)updateBoardBounds {
  
      // reposition if dyadmino is rack dyadmino
  if (dyadmino.parent == _boardField && [dyadmino belongsInRack]) {
    CGPoint newPosition = [self addToThisPoint:dyadmino.position thisPoint:_boardField.position];
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_rackField];
    dyadmino.position = newPosition;
  }
  
  if (dyadmino == _recentRackDyadmino) {
    [self updateCellsForRemovedDyadmino:dyadmino andColour:YES];
  } else { // otherwise it's a hovering dyadmino
//  NSLog(@"update cells for removed dyadmino called from send dyadmino home");
    [self updateCellsForRemovedDyadmino:dyadmino andColour:NO];
  }
  
    // this is one of two places where board bounds are updated
    // the other is when dyadmino is eased into board node
  if (updateBoardBounds) {
    NSLog(@"update board bounds from send dyadmino home");
    [self updateBoardBoundsWithLayoutCells:YES];
  }
  
  [dyadmino endTouchThenHoverResize];
    // this makes nil tempBoardNode
  
  if ([dyadmino belongsInRack]) {
    _uponTouchDyadminoNode = nil;
    [dyadmino goHomeToRackByPoppingIn:poppingIn];
  } else {
    dyadmino.tempBoardNode = dyadmino.homeNode;
    [dyadmino goHomeToBoardByPoppingIn:poppingIn];
  }

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
    dyadmino.orientation = dyadmino.tempReturnOrientation;
    [self updateCellsForPlacedDyadmino:dyadmino andColour:NO];
  }
}

-(void)sendDyadminoToBoardNode:(Dyadmino *)dyadmino {
    // cells will be updated in callback
  [dyadmino animatePopBackIntoBoardNode];
  if (dyadmino == _hoveringDyadmino) {
    _hoveringDyadmino = nil;
  }
}

-(void)handlePivotOfDyadmino:(Dyadmino *)dyadmino {
  
  CGPoint touchBoardOffset = [_boardField getOffsetFromPoint:_currentTouchLocation];
  
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
  [_boardField pivotGuidesBasedOnTouchLocation:touchBoardOffset forDyadmino:dyadmino];
}

#pragma mark - view controller methods

-(void)goBackToMainViewController {
  [self.delegate backToMainMenu];
}

#pragma mark - button methods

-(void)deviceShaken {
  [self.mySoundEngine soundPCToggle];
  [self.mySceneEngine toggleBetweenLetterAndNumberMode];
}

-(void)handleButtonPressed {
  
      /// games button
  if (_buttonPressed == _topBar.gamesButton) {
    [self goBackToMainViewController];
    
      /// swap button
  } else if (_buttonPressed == _topBar.swapButton) {
    if (!_swapMode) {
      [self toggleSwapField];
      _swapMode = YES;
      [self updateButtonsForStaticState];
      [self.myMatch resetHoldingContainerAndUndo];
    }
    
//      /// togglePC button
//  } else if (_buttonPressed == _topBar.togglePCModeButton) {
//    [self.mySceneEngine toggleBetweenLetterAndNumberMode];
    
      /// play button
  } else if (_buttonPressed == _topBar.playDyadminoButton) {
    [self playDyadmino:_recentRackDyadmino];
    
      /// cancel button
  } else if (_buttonPressed == _topBar.cancelButton) {
      // if in swap mode, cancel swap
    if (_swapMode) {
      [self toggleSwapField];
      [self cancelSwappedDyadminoes];
      [self updateButtonsForStaticState];
      [self.myMatch resetHoldingContainerAndUndo];
      
        // else send dyadmino home
    } else if (_hoveringDyadmino) {
      NSLog(@"send dyadmino home if hovering dyadmino and cancel button pressed");
      [self sendDyadminoHome:_hoveringDyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];

        // recent rack dyadmino is sent home
    } else if (_recentRackDyadmino) {
      NSLog(@"send dyadmino home if recent rack dyadmino and cancel button pressed");
      [self sendDyadminoHome:_recentRackDyadmino byPoppingIn:YES andUpdatingBoardBounds:YES];
    }
    
      /// done button
  } else if (_buttonPressed == _topBar.doneTurnButton) {
    if (!_swapMode) {
      [self finalisePlayerTurn];
    } else if (_swapMode) {
      if ([self finaliseSwap]) {
        [self toggleSwapField];
        _swapMode = NO;
        [self updateLabels];
        [self updateButtonsForStaticState];
      }
    }
    
      /// debug button
  } else if (_buttonPressed == _topBar.debugButton) {
    [self debugButtonPressed];
    
      /// resign button
  } else if (_buttonPressed == _topBar.resignButton) {
    [self handleResign];
    
      /// undo button
  } else if (_buttonPressed == _topBar.undoButton) {
    [self handleUndo];
  
      /// redo button
  } else if (_buttonPressed == _topBar.redoButton) {
    [self handleRedo];
  }
}

#pragma mark - match interaction methods

-(void)recordChangedDataForRackDyadminoes:(NSMutableArray *)rackArray {
  for (int i = 0; i < rackArray.count; i++) {
    if ([rackArray[i] isKindOfClass:[Dyadmino class]]) {
      Dyadmino *dyadmino = (Dyadmino *)rackArray[i];
      dyadmino.myRackOrder = i;
      [self persistDataForDyadmino:dyadmino];
    }
  }
}

-(void)persistDataForDyadmino:(Dyadmino *)dyadmino {
  DataDyadmino *dataDyad = [self getDataDyadminoFromDyadmino:dyadmino];
  if ([dyadmino belongsOnBoard]) {
    dataDyad.myHexCoord = dyadmino.homeNode.myCell.hexCoord;
  }
  
//  dataDyad.myHexCoord = dyadmino.myHexCoord;
  if ([dyadmino isOnBoard] && [dyadmino belongsInRack]) {
    dataDyad.myOrientation = dyadmino.tempReturnOrientation;
  } else {
    dataDyad.myOrientation = dyadmino.orientation;
  }
  dataDyad.myRackOrder = dyadmino.myRackOrder;
}

-(void)persistAllSceneDataDyadminoes {
  for (Dyadmino *dyadmino in self.playerRackDyadminoes) {
    [self persistDataForDyadmino:dyadmino];
  }
  
  for (Dyadmino *dyadmino in self.boardDyadminoes) {
    [self persistDataForDyadmino:dyadmino];
  }
}
 
-(void)handleUndo {
//  [self.myMatch undoDyadminoToHoldingContainer];
//    // get data dyadmino of undone dyadmino
//  for (Dyadmino *dyadmino in self.playerRackDyadminoes) {
//    DataDyadmino *dataDyad = [self getDataDyadminoFromDyadmino:dyadmino];
//    if ([dyadmino belongsOnBoard] && ![self.myMatch.holdingContainer containsObject:dataDyad]) {
//      [dyadmino removeFromParent];
//      [self addToPlayerRackDyadminoes:dyadmino];
//      [self layoutOrRefreshRackFieldAndDyadminoes];
//      [self sendDyadminoHome:dyadmino byPoppingIn:NO];
//    }
//  }
  
  [self updateLabels];
  [self updateButtonsForStaticState];
}

-(void)handleRedo {
//  [self.myMatch redoDyadminoToHoldingContainer];
//  for (Dyadmino *dyadmino in self.playerRackDyadminoes) {
//    DataDyadmino *dataDyad = [self getDataDyadminoFromDyadmino:dyadmino];
//    if ([dyadmino belongsInRack] && ![self.myMatch.holdingContainer containsObject:dataDyad]) {
//      [dyadmino removeFromParent];
//      [self addToPlayerRackDyadminoes:dyadmino];
//      [self layoutOrRefreshRackFieldAndDyadminoes];
//      [self sendDyadminoHome:dyadmino byPoppingIn:NO];
//    }
//  }
  
  
  [self updateLabels];
  [self updateButtonsForStaticState];
}

-(void)cancelSwappedDyadminoes {
  _swapMode = NO;
  [self.myMatch.swapContainer removeAllObjects];
  [self.myMatch resetHoldingContainerAndUndo];
  for (Dyadmino *dyadmino in self.playerRackDyadminoes) {
    if (dyadmino.belongsInSwap) {
      dyadmino.belongsInSwap = NO;
      [dyadmino goHomeToRackByPoppingIn:NO];
    }
  }
}

-(BOOL)finaliseSwap {
  NSMutableArray *toPile = [NSMutableArray new];
  
  for (Dyadmino *dyadmino in self.playerRackDyadminoes) {
    if ([dyadmino belongsInSwap]) {
      [toPile addObject:dyadmino];
    }
  }
  
    // if swapped dyadminoes is greater than pile count, cancel
  if (self.myMatch.holdingContainer.count > self.myMatch.pile.count) {
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
      [dyadmino goHomeToRackByPoppingIn:NO];
      [dyadmino removeFromParent];
    }
    
      // then swap in the logic
    [self.myMatch swapDyadminoesFromCurrentPlayer];
    
    [self populateRackArray];
    [self layoutOrRefreshRackFieldAndDyadminoes];
    [_topBar flashLabelNamed:@"log" withText:@"swapped"];
    return YES;
  }
}

-(void)playDyadmino:(Dyadmino *)dyadmino {
    // establish that dyadmino is indeed a rack dyadmino placed on the board
  if ([dyadmino belongsInRack] && [dyadmino isOnBoard]) {
    
      // confirm that the dyadmino was successfully played before proceeding with anything else
    DataDyadmino *dataDyad = [self getDataDyadminoFromDyadmino:dyadmino];
    [self.myMatch addToHoldingContainer:dataDyad];
    [self removeFromPlayerRackDyadminoes:dyadmino];
    [self addToSceneBoardDyadminoes:dyadmino];
    
      // do cleanup, dyadmino's home node is now the board node
    dyadmino.homeNode = dyadmino.tempBoardNode;
    dyadmino.myHexCoord = dyadmino.homeNode.myCell.hexCoord;
    [dyadmino highlightBoardDyadmino];
    
      // empty pointers
    _recentRackDyadmino = nil;
    _hoveringDyadmino = nil;
    
      // establish data dyadmino properties
    dataDyad.myHexCoord = dyadmino.myHexCoord;
    dataDyad.myOrientation = dyadmino.orientation;
  }
  [self layoutOrRefreshRackFieldAndDyadminoes];
  [self updateLabels];
  [self updateButtonsForStaticState];
}

-(void)finalisePlayerTurn {
    // no recent rack dyadmino on board
  if (!_recentRackDyadmino) {
    [self persistAllSceneDataDyadminoes];
    [self.myMatch recordDyadminoesFromPlayer:_myPlayer];

    [self populateRackArray];
    [self layoutOrRefreshRackFieldAndDyadminoes];
    
      // update views
    [self updateLabels];
    [_topBar flashLabelNamed:@"chord" withText:@"C major triad"];
    [_topBar updateLabelNamed:@"score" withText:@"score: 3"];
    [_topBar flashLabelNamed:@"log" withText:@"turn done"];
  }
}

-(void)handleSwitchToNextPlayer {
  
}

-(void)handleResign {
  
  NSString *resignString = @"Are you sure? This will count as a loss in Game Center.";
  
  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:resignString delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Resign" otherButtonTitles:nil, nil];
  actionSheet.actionSheetStyle = UIActionSheetStyleAutomatic;
  [actionSheet showInView:self.view];
  
  /*
  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Resign" message:@"Are you sure you want to resign?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
  [alertView show];
  */
}

-(void) handleEndGame {
  
}

#pragma mark - realtime update methods

-(void)update:(CFTimeInterval)currentTime {
  
  [self updateForDoubleTap:currentTime];
//  NSLog(@"hovering dyadmino is %@", _hoveringDyadmino.name);
  if (_hoveringDyadmino) {
//    NSLog(@"hovering dyadmino is %@", _hoveringDyadmino.name);
    [self updateDyadmino:_hoveringDyadmino forHover:currentTime];
  }
  
    // snap back somewhat from board bounds
    // TODO: this works, but it feels jumpy
  [self updateForBoardBeingCorrectedWithinBounds];
  [self updateForHoveringDyadminoBeingCorrectedWithinBounds];
  [self updatePivotForDyadminoMoveWithoutBoardCorrected];
  [self updateForButtons];
}

-(void)updateForButtons {
    // while *not* in swap mode...
  if (!_swapMode) {
    [_topBar disableButton:_topBar.cancelButton];
    
      // play button is enabled when there's a rack dyadmino on board
      // and no dyadmino is touched or hovering
    _recentRackDyadmino && !_touchedDyadmino && !_hoveringDyadmino ?
      [_topBar enableButton:_topBar.playDyadminoButton] :
      [_topBar disableButton:_topBar.playDyadminoButton];
    
    (_recentRackDyadmino || _hoveringDyadmino) && ![self isFirstDyadmino:_hoveringDyadmino] ?
      [_topBar enableButton:_topBar.cancelButton] :
      [_topBar disableButton:_topBar.cancelButton];
    
      // done button is enabled only when no recent rack dyadmino
      // and no dyadmino is hovering
    !_recentRackDyadmino && !_hoveringDyadmino ?
      [_topBar enableButton:_topBar.doneTurnButton] :
      [_topBar disableButton:_topBar.doneTurnButton];
    
      // ...these are the criteria by which swap button is enabled
      // swap button cannot have any rack dyadminoes on board
      // FIXME: swap button also is disabled when any dyadmino has been played
//    if ([_touchedDyadmino isOnBoard] || _recentRackDyadmino) {
//      [_topBar disableButton:_topBar.swapButton];
//    } else if (!_touchedDyadmino || [_touchedDyadmino isInRack]) {
//      [_topBar enableButton:_topBar.swapButton];
//    }
    
    if (self.myMatch.holdingContainer.count > 0) {
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
  if (_canDoubleTapForDyadminoFlip || _canDoubleTapForBoardZoom) {
    if (_doubleTapTime == 0.f) {
      _doubleTapTime = currentTime;
    }
  }
  
  if (_doubleTapTime != 0.f && currentTime > _doubleTapTime + kDoubleTapTime) {
    _canDoubleTapForBoardZoom = NO;
    _canDoubleTapForDyadminoFlip = NO;
    _hoveringDyadmino.canFlip = NO;
    _doubleTapTime = 0.f;
  }
}

-(void)updateForHoveringDyadminoBeingCorrectedWithinBounds {
  if (![_hoveringDyadmino isRotating] && !_boardToBeMovedOrBeingMoved &&
      !_boardBeingCorrectedWithinBounds && !_boardJustShiftedNotCorrected &&
      _hoveringDyadmino && _hoveringDyadmino != _touchedDyadmino &&
      ![_hoveringDyadmino isInRack] && ![_hoveringDyadmino isInTopBar]) {
    
    CGFloat xLowLimit = -_boardField.position.x;
    CGFloat xHighLimit = self.view.frame.size.width - _boardField.position.x;
    
    CGFloat thisDistance;
    CGFloat distanceDivisor = 5.333f; // tweak this number if desired
    CGFloat dyadminoBuffer;
    
    switch (_hoveringDyadmino.orientation) {
      case kPC1atTwelveOClock:
      case kPC1atSixOClock:
        dyadminoBuffer = kDyadminoFaceWideRadius * 1.5;
        break;
        
      default: // all other cases
        dyadminoBuffer = kDyadminoFaceWideDiameter * 1.5;
        break;
    }
    
    if (_hoveringDyadmino.position.x - dyadminoBuffer < xLowLimit) {
      _hoveringDyadminoBeingCorrected++;
      thisDistance = 1.f + (xLowLimit - (_hoveringDyadmino.position.x - dyadminoBuffer)) / distanceDivisor;
      _hoveringDyadmino.position = CGPointMake(_hoveringDyadmino.position.x + thisDistance, _hoveringDyadmino.position.y);
      
    } else if (_hoveringDyadmino.position.x + dyadminoBuffer > xHighLimit) {
      _hoveringDyadminoBeingCorrected++;
      thisDistance = 1.f + ((_hoveringDyadmino.position.x + dyadminoBuffer) - xHighLimit) / distanceDivisor;
      _hoveringDyadmino.position = CGPointMake(_hoveringDyadmino.position.x - thisDistance, _hoveringDyadmino.position.y);
      
    } else {
      _hoveringDyadminoFinishedCorrecting++;
    }
    

      // only goes through one time
    if (_hoveringDyadminoBeingCorrected == 1) {
      [_boardField hideAllPivotGuides];
      NSLog(@"update cells for removed dyadmino called from update for hovering dyadmino being corrected");
      [self updateCellsForRemovedDyadmino:_hoveringDyadmino andColour:NO];
      _hoveringDyadminoFinishedCorrecting = 0;
      
    } else if (_hoveringDyadminoFinishedCorrecting == 1) {
      [self updateCellsForRemovedDyadmino:_hoveringDyadmino andColour:NO];
      _hoveringDyadmino.tempBoardNode = [self findSnapPointClosestToDyadmino:_hoveringDyadmino];
      NSLog(@"update cells for removed dyadmino called from update for hovering dyadmino being corrected, finished correcting");
      [self updateCellsForPlacedDyadmino:_hoveringDyadmino andColour:NO];
      NSLog(@"update for hovering");
      if (!_canDoubleTapForDyadminoFlip && ![_hoveringDyadmino isRotating]) {
        [_boardField hidePivotGuideAndShowPrePivotGuideForDyadmino:_hoveringDyadmino];
      }
      _hoveringDyadminoBeingCorrected = 0;
    }
  }
}

-(void)updateForBoardBeingCorrectedWithinBounds {
  
  if (_swapFieldActionInProgress) {
    _boardField.homePosition = _boardField.position;
    return;
  }
  
  CGFloat swapBuffer = 0.f;
  if (_swapMode) {
    swapBuffer = kRackHeight; // the height of the swap field
  }
  
    // only prevents board move from touch if it's truly out of bounds
    // it's fine if it's still within the buffer
  if (_boardField.position.x < _boardField.lowestXPos) {
    _boardBeingCorrectedWithinBounds = YES;
  }
  if (_boardField.position.y < _boardField.lowestYPos) {
    _boardBeingCorrectedWithinBounds = YES;
  }
  if (_boardField.position.x > _boardField.highestXPos) {
    _boardBeingCorrectedWithinBounds = YES;
  }
  if (_boardField.position.y > _boardField.highestYPos + swapBuffer) {
    _boardBeingCorrectedWithinBounds = YES;
  }
  
  if (!_boardToBeMovedOrBeingMoved || _boardBeingCorrectedWithinBounds) {
    
    if (_hoveringDyadmino && _boardBeingCorrectedWithinBounds) {
      [_boardField hideAllPivotGuides];
      NSLog(@"update cells for removed dyadmino called from update for board being corrected within bounds, hovering dyadmino removed");
      [self updateCellsForRemovedDyadmino:_hoveringDyadmino andColour:NO];
    }
    
    CGFloat thisDistance;
      // this number can be tweaked, but it seems fine for now
    CGFloat distanceDivisor = 8.f;
    
      // this establishes when board is no longer being corrected within bounds
    NSUInteger alreadyCorrect = 0;

    CGFloat lowestXBuffer = _boardField.lowestXPos + kDyadminoFaceWideRadius;
    CGFloat lowestYBuffer = _boardField.lowestYPos + kDyadminoFaceRadius;
    CGFloat highestXBuffer = _boardField.highestXPos - kDyadminoFaceWideRadius;
    CGFloat highestYBuffer = _boardField.highestYPos - kDyadminoFaceRadius + swapBuffer;
    
      // this way when the board is being corrected,
      // it doesn't jump afterwards
    if (_boardToBeMovedOrBeingMoved) {
      _beganTouchLocation = _currentTouchLocation;
    }
  
      // establishes the board is being shifted away from hard edge, not as a correction
    
    if (_boardField.position.x < lowestXBuffer) {
      _boardJustShiftedNotCorrected = YES;
      thisDistance = 1.f + (lowestXBuffer - _boardField.position.x) / distanceDivisor;
      _boardField.position = CGPointMake(_boardField.position.x + thisDistance, _boardField.position.y);
      _boardField.homePosition = _boardField.position;
      
      if (_hoveringDyadminoToStayFixedWhileBoardMoves) {
        _hoveringDyadmino.position = CGPointMake(_hoveringDyadmino.position.x - thisDistance, _hoveringDyadmino.position.y);
      }
      
    } else {
      alreadyCorrect++;
    }
    
    if (_boardField.position.y < lowestYBuffer) {
      _boardJustShiftedNotCorrected = YES;
      thisDistance = 1.f + (lowestYBuffer - _boardField.position.y) / distanceDivisor;
      _boardField.position = CGPointMake(_boardField.position.x, _boardField.position.y + thisDistance);
      _boardField.homePosition = _boardField.position;
      
      if (_hoveringDyadminoToStayFixedWhileBoardMoves) {
        _hoveringDyadmino.position = CGPointMake(_hoveringDyadmino.position.x, _hoveringDyadmino.position.y - thisDistance);
      }
      
    } else {
      alreadyCorrect++;
    }

    if (_boardField.position.x > highestXBuffer) {
      _boardJustShiftedNotCorrected = YES;
      thisDistance = 1.f + (_boardField.position.x - highestXBuffer) / distanceDivisor;
      _boardField.position = CGPointMake(_boardField.position.x - thisDistance, _boardField.position.y);
      _boardField.homePosition = _boardField.position;
      
      if (_hoveringDyadminoToStayFixedWhileBoardMoves) {
        _hoveringDyadmino.position = CGPointMake(_hoveringDyadmino.position.x + thisDistance, _hoveringDyadmino.position.y);
      }
      
    } else {
      alreadyCorrect++;
    }

    if (_boardField.position.y > highestYBuffer) {
      _boardJustShiftedNotCorrected = YES;
      thisDistance = 1.f + (_boardField.position.y - highestYBuffer) / distanceDivisor;
      _boardField.position = CGPointMake(_boardField.position.x, _boardField.position.y - thisDistance);
      _boardField.homePosition = _boardField.position;
      
      if (_hoveringDyadminoToStayFixedWhileBoardMoves) {
        _hoveringDyadmino.position = CGPointMake(_hoveringDyadmino.position.x, _hoveringDyadmino.position.y + thisDistance);
      }
      
    } else {
      alreadyCorrect++;
    }

      // this one is constantly being called even when board is motionless
    if (alreadyCorrect == 4) {

      if (_boardJustShiftedNotCorrected &&
          _hoveringDyadmino && _hoveringDyadmino != _touchedDyadmino) {
//        NSLog(@"hovering dyadmino is %@, touched dyadmino is %@", _hoveringDyadmino.name, _touchedDyadmino.name);
        
        _boardJustShiftedNotCorrected = NO;
        NSLog(@"update cells for removed dyadmino called from update for board being corrected within bounds, board just shifted not corrected");
        [self updateCellsForRemovedDyadmino:_hoveringDyadmino andColour:NO];
        _hoveringDyadmino.tempBoardNode = [self findSnapPointClosestToDyadmino:_hoveringDyadmino];
        [self updateCellsForPlacedDyadmino:_hoveringDyadmino andColour:NO];
        
        if (_hoveringDyadminoBeingCorrected == 0) {
//          NSLog(@"update for board");
          if (!_canDoubleTapForDyadminoFlip && ![_hoveringDyadmino isRotating]) {
            [_boardField hidePivotGuideAndShowPrePivotGuideForDyadmino:_hoveringDyadmino];
          }
        }
      }
      
      _boardBeingCorrectedWithinBounds = NO;
    }
  }
}

-(void)updatePivotForDyadminoMoveWithoutBoardCorrected {
    // if board not shifted or corrected, show prepivot guide
  if (_hoveringDyadmino && _hoveringDyadminoBeingCorrected == 0 && !_touchedDyadmino && !_currentTouch && !_boardBeingCorrectedWithinBounds && !_boardJustShiftedNotCorrected && ![_boardField.children containsObject:_boardField.prePivotGuide]) {
//    NSLog(@"update pivot for dyadmino move without board corrected");
    if (!_canDoubleTapForDyadminoFlip && ![_hoveringDyadmino isRotating]) {
      [_boardField hidePivotGuideAndShowPrePivotGuideForDyadmino:_hoveringDyadmino];
    }
  }
}

-(void)updateDyadmino:(Dyadmino *)dyadmino forHover:(CFTimeInterval)currentTime {
  if (!_swapMode) {
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
    
      // 
    if (_hoverTime != 0.f && currentTime > _hoverTime + kAnimateHoverTime) {
      _hoverTime = 0.f;
      
      _uponTouchDyadminoNode = nil;
      [dyadmino finishHovering];
    }
    
    if ([dyadmino isFinishedHovering]) {
//      NSLog(@"update dyadmino, finished hovering, check");
      [self checkWhetherToEaseOrKeepHovering:dyadmino afterTouchJustEnded:NO];
    }
  }
}

  // touch just ended doesn't really make a difference
-(void)checkWhetherToEaseOrKeepHovering:(Dyadmino *)dyadmino afterTouchJustEnded:(BOOL)touchJustEnded {
//  NSLog(@"dyadmino name is %@, %i, %i", dyadmino.name, [dyadmino belongsInRack], [dyadmino isInRack]);
//  NSLog(@"touch just ended %i", touchJustEnded);
//  NSLog(@"dyadmino home node %@, tempboard node %@, orientation %i, tempreturnorientation %i, candoubletap %i", dyadmino.homeNode.name, dyadmino.tempBoardNode.name, dyadmino.orientation, dyadmino.tempReturnOrientation, _canDoubleTapForDyadminoFlip);
  
    // if finished hovering
  if ([dyadmino isOnBoard] && _touchedDyadmino != dyadmino) {
    
      // finish hovering only if placement is legal
    if (dyadmino.tempBoardNode) { // ensures that validation takes place only if placement is uncertain
                                  // will not get called if returning to homeNode from top bar
      PhysicalPlacementResult placementResult = [_boardField validatePlacingDyadmino:dyadmino
                                                                         onBoardNode:dyadmino.tempBoardNode];
      
        // handle placement results:
//      NSLog(@"placement result is %i", placementResult);
        // ease in right away because
        // no error and
        // dyadmino was not moved from original spot
      if (placementResult == kNoError && !(dyadmino.tempBoardNode == _uponTouchDyadminoNode && dyadmino.orientation == _uponTouchDyadminoOrientation)) {
//        NSLog(@"will finish hovering");
        [dyadmino finishHovering];
        if ([dyadmino belongsOnBoard]) {
          
            // this is the only place where a board dyadmino's tempBoardNode becomes its new homeNode
          
            // this method will record a dyadmino that's already in the match's board
            // this method also gets called if a recently played dyadmino
            // has been moved, but data will not be submitted until the turn is officially done.
          [self persistDataForDyadmino:dyadmino];
          dyadmino.homeNode = dyadmino.tempBoardNode;
        }
        
          // this is one of two places where board bounds are updated
          // the other is when rack dyadmino is sent home
        
        NSLog(@"updateBoardBounds called from check whether to ease");
        [self updateBoardBoundsWithLayoutCells:YES];
        
        [_boardField hideAllPivotGuides];
        [dyadmino animateEaseIntoNodeAfterHover];
        _hoveringDyadmino = nil;
//        NSLog(@"hovering dyadmino is %@", _hoveringDyadmino.name);
      } else {
//        NSLog(@"will keep hovering");
        [dyadmino keepHovering];
        
            // lone dyadmino
        if (placementResult == kErrorLoneDyadmino) {
          [_topBar flashLabelNamed:@"message" withText:@"no lone dyadminoes!"];
          
            // stacked dyadminoes
        } else if (placementResult == kErrorStackedDyadminoes) {
          [_topBar flashLabelNamed:@"message" withText:@"can't stack dyadminoes!"];
        }
      }
    }
  }
}

#pragma mark - update label and button methods

-(void)updateLabels {
  
    // pile count
  [_topBar updateLabelNamed:@"pileCount"
                   withText:[NSString stringWithFormat:@"in pile: %lu",
                             (unsigned long)self.myMatch.pile.count]];
  
  for (int i = 0; i < self.myMatch.players.count; i++) {
    Player *player = self.myMatch.players[i];
    Label *nameLabel = _topBar.playerNameLabels[i];
    Label *scoreLabel = _topBar.playerScoreLabels[i];
    Label *rackLabel = _topBar.playerRackLabels[i];
  
    if (player.resigned) {
      nameLabel.fontColor = [SKColor darkGrayColor];
    } else if (player == _myPlayer) {
      nameLabel.fontColor = (player == self.myMatch.currentPlayer) ? [SKColor orangeColor] : [SKColor yellowColor];
    } else if (player == self.myMatch.currentPlayer) {
      nameLabel.fontColor = [SKColor orangeColor];
    } else if ([self.myMatch.wonPlayers containsObject:self.myMatch.currentPlayer]) {
      nameLabel.fontColor = [SKColor greenColor];
    } else {
      nameLabel.fontColor = [SKColor whiteColor];
    }

    [_topBar updateLabelNamed:nameLabel.name withText:player.playerName];
    
    NSString *scoreText = self.myMatch.tempScore > 0 && player == _myPlayer ?
    [NSString stringWithFormat:@"%lu + %lu", (unsigned long)player.playerScore, (unsigned long)self.myMatch.tempScore] :
    [NSString stringWithFormat:@"%lu", (unsigned long)player.playerScore];
    [_topBar updateLabelNamed:scoreLabel.name withText:scoreText];
    
    [_topBar updateLabelNamed:rackLabel.name withText:[[player.dataDyadminoesThisTurn valueForKey:kDyadminoIDKey] componentsJoinedByString:@", "]];
    
    NSString *pileText = [NSString stringWithFormat:@"in pile: %@", [[self.myMatch.pile valueForKey:kDyadminoIDKey] componentsJoinedByString:@", "]];
    NSMutableArray *tempBoard = [NSMutableArray arrayWithArray:[self.myMatch.board allObjects]];
    NSString *boardText = [NSString stringWithFormat:@"on board: %@", [[tempBoard valueForKey:kDyadminoIDKey] componentsJoinedByString:@", "]];
    NSString *holdingContainerText = [NSString stringWithFormat:@"in holding container: %@", [[self.myMatch.holdingContainer valueForKey:kDyadminoIDKey] componentsJoinedByString:@", "]];
    NSString *swapContainerText = [NSString stringWithFormat:@"in swap container: %@", [[self.myMatch.swapContainer valueForKey:kDyadminoIDKey] componentsJoinedByString:@", "]];
    
    [_topBar updateLabelNamed:_topBar.pileDyadminoesLabel.name withText:pileText];
    [_topBar updateLabelNamed:_topBar.boardDyadminoesLabel.name withText:boardText];
    [_topBar updateLabelNamed:_topBar.holdingContainerLabel.name withText:holdingContainerText];
    [_topBar updateLabelNamed:_topBar.swapContainerLabel.name withText:swapContainerText];
  }
}

-(void)updateButtonsForStaticState {
  
  if (_myPlayer.resigned || self.myMatch.gameHasEnded) { // only games, replay, and toggle (and debug)
    [_topBar disableButton:_topBar.undoButton];
    [_topBar disableButton:_topBar.redoButton];
    [_topBar disableButton:_topBar.resignButton];
    [_topBar disableButton:_topBar.swapButton];
    [_topBar disableButton:_topBar.playDyadminoButton];
    [_topBar disableButton:_topBar.doneTurnButton];
  } else { // game still active for player
    if (_swapMode) { // only games, toggle, cancel, and done (and debug)
      [_topBar disableButton:_topBar.undoButton];
      [_topBar disableButton:_topBar.redoButton];
      [_topBar disableButton:_topBar.replayButton];
      [_topBar disableButton:_topBar.resignButton];
      [_topBar disableButton:_topBar.swapButton];
      [_topBar disableButton:_topBar.playDyadminoButton];
    } else {
      [_topBar enableButton:_topBar.undoButton];
      [_topBar enableButton:_topBar.redoButton];
      [_topBar enableButton:_topBar.replayButton];
      [_topBar enableButton:_topBar.resignButton];
      if (self.myMatch.holdingContainer.count == 0) {
        [_topBar enableButton:_topBar.swapButton];
      }
      [_topBar enableButton:_topBar.playDyadminoButton];
    }
  }
  
  if (_myPlayer != self.myMatch.currentPlayer) {
      // TODO: obviously, do this
  }
  
//  if (self.myMatch.holdingContainer > 0) {
//    [_topBar disableButton:_topBar.swapButton];
//  } else {
//    [_topBar enableButton:_topBar.swapButton];
//  }
  
    // undo and redo buttons
  [self.myMatch.undoManager canUndo] ? [_topBar enableButton:_topBar.undoButton] : [_topBar disableButton:_topBar.undoButton];
  [self.myMatch.undoManager canRedo] ? [_topBar enableButton:_topBar.redoButton] : [_topBar disableButton:_topBar.redoButton];

}

#pragma mark - field animation methods

-(void)toggleSwapField {
    // TODO: move animations at some point
    // FIXME: make better animation
    // otherwise toggle
  if (_swapMode) { // swap mode on, so turn off
    [self.mySoundEngine soundSwapFieldSwoosh];
    _swapFieldActionInProgress = YES;
    
    SKAction *moveAction = [SKAction moveToY:0.f duration:kConstantTime];
    SKAction *completionAction = [SKAction runBlock:^{
      _swapFieldActionInProgress = NO;
      _swapField.hidden = YES;
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
    [self.mySoundEngine soundSwapFieldSwoosh];
    _swapFieldActionInProgress = YES;
    
    _swapField.hidden = NO;
    SKAction *moveAction = [SKAction moveToY:kRackHeight duration:kConstantTime];
    SKAction *completionAction = [SKAction runBlock:^{
      _swapFieldActionInProgress = NO;
      [self revealBoardCover];
    }];
    SKAction *sequenceAction = [SKAction sequence:@[moveAction, completionAction]];
    [_swapField runAction:sequenceAction];
    SKAction *moveBoardAction = [SKAction moveToY:_boardField.position.y + kRackHeight duration:kConstantTime];
    [_boardField runAction:moveBoardAction];
  }
}

-(void)revealBoardCover {
    // TODO: make this animated
  _boardCover.hidden = NO;
  _boardCover.zPosition = kZPositionBoardCover;
}

-(void)hideBoardCover {
  _boardCover.hidden = YES;
  _boardCover.zPosition = kZPositionBoardCoverHidden;
}

#pragma mark - match helper methods

-(void)addDataDyadminoToSwapContainerForDyadmino:(Dyadmino *)dyadmino {
  DataDyadmino *dataDyad = [self getDataDyadminoFromDyadmino:dyadmino];
  if (![self.myMatch.swapContainer containsObject:dataDyad]) {
    [self.myMatch.swapContainer addObject:dataDyad];
  }
}

-(void)removeDataDyadminoFromSwapContainerForDyadmino:(Dyadmino *)dyadmino {
  DataDyadmino *dataDyad = [self getDataDyadminoFromDyadmino:dyadmino];
  if ([self.myMatch.swapContainer containsObject:dataDyad]) {
    [self.myMatch.swapContainer removeObject:dataDyad];
  }
}

#pragma mark - board helper methods

-(void)updateCellsForPlacedDyadmino:(Dyadmino *)dyadmino andColour:(BOOL)colour {
  NSLog(@"update cells for placed dyadmino");
  if (![dyadmino isRotating]) {
    dyadmino.tempBoardNode ?
      [_boardField updateCellsForDyadmino:dyadmino placedOnBoardNode:dyadmino.tempBoardNode andColour:colour] :
      [_boardField updateCellsForDyadmino:dyadmino placedOnBoardNode:dyadmino.homeNode andColour:colour];
  }
}

-(void)updateCellsForRemovedDyadmino:(Dyadmino *)dyadmino andColour:(BOOL)colour {
  NSLog(@"update cells for removed dyadmino");
  if (![dyadmino isRotating]) {
    dyadmino.tempBoardNode ?
      [_boardField updateCellsForDyadmino:dyadmino removedFromBoardNode:dyadmino.tempBoardNode andColour:colour] :
      [_boardField updateCellsForDyadmino:dyadmino removedFromBoardNode:dyadmino.homeNode andColour:colour];
  }
}

-(void)updateBoardBoundsWithLayoutCells:(BOOL)layoutCells {
  
  NSLog(@"updateBoardBounds called");
  NSMutableSet *dyadminoesOnBoard = [NSMutableSet setWithSet:self.boardDyadminoes];

    // add dyadmino to set if dyadmino is a recent rack dyadmino
  if ([_recentRackDyadmino isOnBoard]) {
    if (![dyadminoesOnBoard containsObject:_recentRackDyadmino]) {
      [dyadminoesOnBoard addObject:_recentRackDyadmino];
    }
  }
  
  if (layoutCells) {
    NSLog(@"layoutboardcells called from updateboardbounds");
    [_boardField layoutBoardCellsAndSnapPointsOfDyadminoes:dyadminoesOnBoard];
  }
  
  [_topBar updateLabelNamed:@"log" withText:[NSString stringWithFormat:@"cells: top %i, right %i, bottom %i, left %i",
                                             _boardField.cellsTop - 0, _boardField.cellsRight - 0, _boardField.cellsBottom + 0, _boardField.cellsLeft + 0]];
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

-(DataDyadmino *)getDataDyadminoFromDyadmino:(Dyadmino *)dyadmino {
  
  NSMutableSet *tempDataDyadSet = [NSMutableSet setWithSet:self.myMatch.board];
  [tempDataDyadSet addObjectsFromArray:_myPlayer.dataDyadminoesThisTurn];

  for (DataDyadmino *dataDyad in tempDataDyadSet) {
    if (dataDyad.myID == dyadmino.myID) {
      return dataDyad;
    }
  }
  
  return nil;
}

-(void)determineCurrentSectionOfDyadmino:(Dyadmino *)dyadmino {
    // this the ONLY place that determines current section of dyadmino
    // this is the ONLY place that sets dyadmino's belongsInSwap to YES
  
    // if it's pivoting, it's on the board, period
    // it's also on board, if not in swap and above rack and below top bar
  if (_pivotInProgress || (!_swapMode && _currentTouchLocation.y - _touchOffsetVector.y >= kRackHeight &&
      _currentTouchLocation.y - _touchOffsetVector.y < self.frame.size.height - kTopBarHeight)) {
//    NSLog(@"it's on the board");
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_boardField];
    dyadmino.isInTopBar = NO;
    
      // it's in swap
  } else if (_swapMode && _currentTouchLocation.y - _touchOffsetVector.y > kRackHeight) {
//    NSLog(@"it's in swap");
    dyadmino.belongsInSwap = YES;
    [self addDataDyadminoToSwapContainerForDyadmino:dyadmino];
    
    dyadmino.isInTopBar = NO;

    // if in rack field, doesn't matter if it's in swap
  } else if (_currentTouchLocation.y - _touchOffsetVector.y <= kRackHeight) {
//    NSLog(@"it's in the rack field");
    [self removeDyadmino:dyadmino fromParentAndAddToNewParent:_rackField];
    dyadmino.belongsInSwap = NO;
    [self removeDataDyadminoFromSwapContainerForDyadmino:dyadmino];
    dyadmino.isInTopBar = NO;

      // else it's in the top bar, but this is a clumsy workaround, so be careful!
  } else if (!_swapMode && _currentTouchLocation.y - _touchOffsetVector.y >=
             self.frame.size.height - kTopBarHeight) {
//    NSLog(@"it's in the top bar");
    dyadmino.isInTopBar = YES;
  } else {
//    NSLog(@"it's nowhere!");
  }
}

-(CGPoint)getOffsetForTouchPoint:(CGPoint)touchPoint forDyadmino:(Dyadmino *)dyadmino {
  return dyadmino.parent == _boardField ?
    [_boardField getOffsetForPoint:touchPoint withTouchOffset:_touchOffsetVector] :
    [self subtractFromThisPoint:touchPoint thisPoint:_touchOffsetVector];
}

-(SKSpriteNode *)selectFaceFromTouchPoint:(CGPoint)touchPoint {
  NSArray *touchNodes = [self nodesAtPoint:touchPoint];
  for (SKSpriteNode *touchNode in touchNodes) {
    if ([touchNode.parent isKindOfClass:[Dyadmino class]]) {
//      NSLog(@"yes, it's a dyadmino");
      Dyadmino *dyadmino = (Dyadmino *)touchNode.parent;
      CGPoint relativeToDyadmino = [self addToThisPoint:touchNode.position thisPoint:dyadmino.position];
      
      
      if (dyadmino && [dyadmino isOnBoard] && !_swapMode) {
        
          // accommodate the fact that dyadmino's position is now relative to board
        CGPoint relativeToBoardPoint = [_boardField getOffsetFromPoint:touchPoint];
        if ([self getDistanceFromThisPoint:relativeToBoardPoint toThisPoint:relativeToDyadmino] < kDistanceForTouchingFace) {
//          NSLog(@"yes, we got the distance");
          return touchNode;
        }
          // if dyadmino is in rack...
      } else if (dyadmino && ([dyadmino isInRack] || [dyadmino isOrBelongsInSwap])) {
        if ([self getDistanceFromThisPoint:touchPoint toThisPoint:relativeToDyadmino] <
            kDistanceForTouchingFace) {
          return touchNode;
        }
      }
    }
  }
  return nil;
}

-(Dyadmino *)selectDyadminoFromTouchPoint:(CGPoint)touchPoint {
    // also establishes if pivot is in progress; touchOffset isn't relevant for this method

    // if we're in hovering mode...
  if ([_hoveringDyadmino isHovering]) {
    
      // accommodate if it's on board
    CGPoint touchBoardOffset = [_boardField getOffsetFromPoint:touchPoint];

      // if touch point is close enough, just rotate
    if ([self getDistanceFromThisPoint:touchBoardOffset toThisPoint:_hoveringDyadmino.position] <
        kDistanceForTouchingHoveringDyadmino) {
      return _hoveringDyadmino;
 
        // otherwise, we're pivoting, so establish that
    } else if ([self getDistanceFromThisPoint:touchBoardOffset toThisPoint:_hoveringDyadmino.position] <
            kMaxDistanceForPivot) {
      _pivotInProgress = YES;
      _hoveringDyadmino.canFlip = NO;
      return _hoveringDyadmino;
    }
  }

    //--------------------------------------------------------------------------
  
    // otherwise, first restriction is that the node being touched is the dyadmino
  
  NSArray *touchNodes = [self nodesAtPoint:touchPoint];
  for (SKNode *touchNode in touchNodes) {
    Dyadmino *dyadmino;
    if ([touchNode isKindOfClass:[Dyadmino class]]) {
      dyadmino = (Dyadmino *)touchNode;
    } else if ([touchNode.parent isKindOfClass:[Dyadmino class]]) {
      dyadmino = (Dyadmino *)touchNode.parent;
    } else if ([touchNode.parent.parent isKindOfClass:[Dyadmino class]]) {
      dyadmino = (Dyadmino *)touchNode.parent.parent;
    }
  //  else {
  //    return nil;
  //  }

    if (dyadmino) {
      
        // second restriction is that touch point is close enough based on following criteria:
        // if dyadmino is on board, not hovering and thus locked in a node, and we're not in swap mode...
//      NSLog(@"determine current section of dyadmino from selectDyadminoFromTouchPoint");
      
      [self determineCurrentSectionOfDyadmino:dyadmino];
      
      if ([dyadmino isOnBoard] && !_swapMode) {
        
          // accommodate the fact that dyadmino's position is now relative to board
        CGPoint relativeToBoardPoint = [_boardField getOffsetFromPoint:touchPoint];
        if ([self getDistanceFromThisPoint:relativeToBoardPoint toThisPoint:dyadmino.position] <
            kDistanceForTouchingRestingDyadmino) {
          return dyadmino;
        }
          // if dyadmino is in rack...
      } else if (dyadmino && ([dyadmino isInRack] || [dyadmino isOrBelongsInSwap])) {
        if ([self getDistanceFromThisPoint:touchPoint toThisPoint:dyadmino.position] <
            kDistanceForTouchingRestingDyadmino) { // was _rackField.xIncrementInRack
          return dyadmino;
        }
      }
    }
  }
    // otherwise, dyadmino is not close enough
  return nil;
}

-(SnapPoint *)findSnapPointClosestToDyadmino:(Dyadmino *)dyadmino {
  id arrayOrSetToSearch;
  
  if ([self isFirstDyadmino:dyadmino]) {
    Cell *homeCell = dyadmino.tempBoardNode.myCell;
    switch (dyadmino.orientation) {
      case kPC1atTwelveOClock:
      case kPC1atSixOClock:
        return homeCell.boardSnapPointTwelveOClock;
        break;
      case kPC1atTwoOClock:
      case kPC1atEightOClock:
        return homeCell.boardSnapPointTwoOClock;
        break;
      case kPC1atFourOClock:
      case kPC1atTenOClock:
        return homeCell.boardSnapPointTenOClock;
        break;
    }
  }
  
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

#pragma mark - undo manager

-(void)addToPlayerRackDyadminoes:(Dyadmino *)dyadmino {
  if (![self.playerRackDyadminoes containsObject:dyadmino]) {
    NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.playerRackDyadminoes];
    [tempArray addObject:dyadmino];
    self.playerRackDyadminoes = [NSArray arrayWithArray:tempArray];
  }
}

-(void)removeFromPlayerRackDyadminoes:(Dyadmino *)dyadmino {
  if ([self.playerRackDyadminoes containsObject:dyadmino]) {
    NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.playerRackDyadminoes];
    [tempArray removeObject:dyadmino];
    self.playerRackDyadminoes = [NSArray arrayWithArray:tempArray];
  }
}

-(void)setPlayerRackDyadminoes:(NSArray *)playerRackDyadminoes {
  if (!_playerRackDyadminoes || !playerRackDyadminoes) {
    _playerRackDyadminoes = playerRackDyadminoes;
  } else if (_playerRackDyadminoes != playerRackDyadminoes) {
    [self.myMatch.undoManager registerUndoWithTarget:self selector:@selector(setPlayerRackDyadminoes:) object:_playerRackDyadminoes];
    _playerRackDyadminoes = playerRackDyadminoes;
  }
}

-(void)addToSceneBoardDyadminoes:(Dyadmino *)dyadmino {
  if (![self.boardDyadminoes containsObject:dyadmino]) {
    NSMutableSet *tempSet = [NSMutableSet setWithSet:self.boardDyadminoes];
    [tempSet addObject:dyadmino];
    self.boardDyadminoes = [NSSet setWithSet:tempSet];
  }
}

-(void)removeFromSceneBoardDyadminoes:(Dyadmino *)dyadmino {
  if ([self.boardDyadminoes containsObject:dyadmino]) {
    NSMutableSet *tempSet = [NSMutableSet setWithSet:self.boardDyadminoes];
    [tempSet removeObject:dyadmino];
    self.boardDyadminoes = [NSSet setWithSet:tempSet];
  }
}

#pragma mark - delegate methods

-(BOOL)isFirstDyadmino:(Dyadmino *)dyadmino {
  return (self.boardDyadminoes.count == 1 && dyadmino == [self.boardDyadminoes anyObject] && !_recentRackDyadmino) ? YES : NO;
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    // for resign alert view
  NSString *buttonText = [actionSheet buttonTitleAtIndex:buttonIndex];
  if ([buttonText isEqualToString:@"Resign"]) {
    [self.myMatch resignPlayer:_myPlayer];
    [self updateLabels];
    [self updateButtonsForStaticState];
  }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // for resign alert view
  NSString *buttonText = [alertView buttonTitleAtIndex:buttonIndex];
  if ([buttonText isEqualToString:@"OK"]) {
    [self.myMatch resignPlayer:_myPlayer];
    [self updateLabels];
    [self updateButtonsForStaticState];
  }
}

-(void)soundRackExchangedDyadmino:(Dyadmino *)dyadmino {
    // this will be a click clack sound
  [self.mySoundEngine soundRackExchangedDyadmino];
}

  // these methods might be different later, so keep them separate
-(void)soundDyadminoPivotClick {
//  NSLog(@"sound dyadmino pivot click");
  [self.mySoundEngine soundPivotClickedDyadmino];
}

-(void)soundDyadminoSettleClick {
  [self.mySoundEngine soundSettledDyadmino];
}

-(void)soundDyadminoSuck {
  [self.mySoundEngine soundSuckedDyadmino];
}

-(void)changeColoursAroundDyadmino:(Dyadmino *)dyadmino withSign:(NSInteger)sign {
  [_boardField changeColoursAroundDyadmino:dyadmino withSign:sign];
}

#pragma mark - debugging methods

-(void)debugButtonPressed {
  [self updateLabels];

  if (_topBar.pileDyadminoesLabel.hidden) {
    _topBar.pileDyadminoesLabel.hidden = NO;
    _topBar.pileDyadminoesLabel.zPosition = kZPositionTopBarLabel;
    _topBar.boardDyadminoesLabel.hidden = NO;
    _topBar.boardDyadminoesLabel.zPosition = kZPositionTopBarLabel;
    _topBar.holdingContainerLabel.hidden = NO;
    _topBar.holdingContainerLabel.zPosition = kZPositionTopBarLabel;
    _topBar.swapContainerLabel.hidden = NO;
    _topBar.swapContainerLabel.zPosition = kZPositionTopBarLabel;
  } else {
    _topBar.pileDyadminoesLabel.hidden = YES;
    _topBar.pileDyadminoesLabel.zPosition = -1000;
    _topBar.boardDyadminoesLabel.hidden = YES;
    _topBar.pileDyadminoesLabel.zPosition = -1000;
    _topBar.holdingContainerLabel.hidden = YES;
    _topBar.holdingContainerLabel.zPosition = -1000;
    _topBar.swapContainerLabel.hidden = YES;
    _topBar.swapContainerLabel.zPosition = -1000;
  }
  
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


  for (Cell *cell in _boardField.allCells) {
    if ([cell isKindOfClass:[Cell class]]) {
      cell.hexCoordLabel.hidden = (!_dyadminoesHidden) ? YES : NO;
    }
  }

  [self updateLabels];
  [self updateButtonsForStaticState];
}

@end
