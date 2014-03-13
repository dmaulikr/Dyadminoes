//
//  Dyadmino.m
//  Dyadminoes
//
//  Created by Bennett Lin on 1/25/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "Dyadmino.h"

@implementation Dyadmino {
  BOOL _alreadyAddedChildren;
  CGSize _touchSize;
}

-(id)initWithPC1:(NSUInteger)pc1 andPC2:(NSUInteger)pc2 andPCMode:(PCMode)pcMode andRotationFrameArray:(NSArray *)rotationFrameArray andPC1LetterSprite:(SKSpriteNode *)pc1LetterSprite andPC2LetterSprite:(SKSpriteNode *)pc2LetterSprite andPC1NumberSprite:(SKSpriteNode *)pc1NumberSprite andPC2NumberSprite:(SKSpriteNode *)pc2NumberSprite {
  self = [super init];
  if (self) {
      // constants
    self.color = [UIColor yellowColor]; // for color blend factor
    self.zPosition = kZPositionRackRestingDyadmino;
    self.name = [NSString stringWithFormat:@"dyadmino %i-%i", pc1, pc2];
    self.pc1 = pc1;
    self.pc2 = pc2;
    self.pcMode = pcMode;
    self.rotationFrameArray = rotationFrameArray;
    self.pc1LetterSprite = pc1LetterSprite;
    self.pc2LetterSprite = pc2LetterSprite;
    self.pc1NumberSprite = pc1NumberSprite;
    self.pc2NumberSprite = pc2NumberSprite;
    self.withinSection = kDyadminoWithinRack;
    self.hoveringStatus = kDyadminoNoHoverStatus;
    [self randomiseRackOrientation];
    [self selectAndPositionSprites];
  }
  return self;
}

-(void)selectAndPositionSprites {
  if (self.pcMode == kPCModeLetter) {
    if (!self.pc1Sprite || self.pc1Sprite == self.pc1NumberSprite) {
      _alreadyAddedChildren = YES;
      [self removeAllChildren];
      self.pc1Sprite = self.pc1LetterSprite;
      self.pc2Sprite = self.pc2LetterSprite;
      [self addChild:self.pc1Sprite];
      [self addChild:self.pc2Sprite];
    }
  } else if (self.pcMode == kPCModeNumber) {
    if (!self.pc1Sprite || self.pc1Sprite == self.pc1LetterSprite) {
      _alreadyAddedChildren = YES;
      [self removeAllChildren];
      self.pc1Sprite = self.pc1NumberSprite;
      self.pc2Sprite = self.pc2NumberSprite;
      [self addChild:self.pc1Sprite];
      [self addChild:self.pc2Sprite];
    }
  }
  
  switch (self.orientation) {
    case kPC1atTwelveOClock:
      self.texture = self.rotationFrameArray[0];
      [self resizeDyadmino];
      self.pc1Sprite.position = CGPointMake(0, self.size.height / 4);
      self.pc2Sprite.position = CGPointMake(0, -self.size.height / 4);
      break;
    case kPC1atTwoOClock:
      self.texture = self.rotationFrameArray[1];
      [self resizeDyadmino];
      self.pc1Sprite.position = CGPointMake(self.size.width * 1.5f / 7, self.size.height / 6);
      self.pc2Sprite.position = CGPointMake(-self.size.width * 1.5f / 7, -self.size.height / 6);
      break;
    case kPC1atFourOClock:
      self.texture = self.rotationFrameArray[2];
      [self resizeDyadmino];
      self.pc1Sprite.position = CGPointMake(self.size.width * 1.5f / 7, -self.size.height / 6);
      self.pc2Sprite.position = CGPointMake(-self.size.width * 1.5f / 7, self.size.height / 6);
      break;
    case kPC1atSixOClock:
      self.texture = self.rotationFrameArray[0];
      [self resizeDyadmino];
      self.pc1Sprite.position = CGPointMake(0, -self.size.height / 4);
      self.pc2Sprite.position = CGPointMake(0, self.size.height / 4);
      break;
    case kPC1atEightOClock:
      self.texture = self.rotationFrameArray[1];
      [self resizeDyadmino];
      self.pc1Sprite.position = CGPointMake(-self.size.width * 1.5f / 7, -self.size.height / 6);
      self.pc2Sprite.position = CGPointMake(self.size.width * 1.5f / 7, self.size.height / 6);
      break;
    case kPC1atTenOClock:
      self.texture = self.rotationFrameArray[2];
      [self resizeDyadmino];
      self.pc1Sprite.position = CGPointMake(-self.size.width * 1.5f / 7, self.size.height / 6);
      self.pc2Sprite.position = CGPointMake(self.size.width * 1.5f / 7, -self.size.height / 6);
      break;
  }
}

-(void)randomiseRackOrientation { // only gets called before sprite is reloaded
  NSUInteger zeroOrOne = [self randomValueUpTo:2]; // randomise rackOrientation
  if (zeroOrOne == 0) {
    self.orientation = kPC1atTwelveOClock;
  } else if (zeroOrOne == 1) {
    self.orientation = kPC1atSixOClock;
  }
  self.tempReturnOrientation = self.orientation;
}

-(void)resizeDyadmino {
  if (self.isTouchThenHoverResized) {
    self.size = CGSizeMake(self.texture.size.width * kTouchedDyadminoSize, self.texture.size.height * kTouchedDyadminoSize);
    self.pc1Sprite.size = CGSizeMake(self.pc1Sprite.texture.size.width * kTouchedDyadminoSize, self.pc1Sprite.texture.size.height * kTouchedDyadminoSize);
    self.pc2Sprite.size = CGSizeMake(self.pc2Sprite.texture.size.width * kTouchedDyadminoSize, self.pc2Sprite.texture.size.height * kTouchedDyadminoSize);
  } else {
    self.size = self.texture.size;
    self.pc1Sprite.size = self.pc1Sprite.texture.size;
    self.pc2Sprite.size = self.pc2Sprite.texture.size;
  }
}

-(void)orientBySnapNode:(SnapNode *)snapNode {
  switch (snapNode.snapNodeType) {
    case kSnapNodeRack:
      if (self.orientation <= 1 || self.orientation >= 5) {
        self.orientation = 0;
      } else {
        self.orientation = 3;
      }
      break;
    default: // snapNode is on board
      self.orientation = self.tempReturnOrientation;
      break;
  }
  [self selectAndPositionSprites];
}

-(void)orientBasedOnSextantChange:(CGFloat)sextantChange {
  for (NSUInteger i = 0; i < 12; i++) {
    if (sextantChange >= 0.f + i && sextantChange < 1.f + i) {
      NSUInteger dyadminoOrientationShouldBe = (self.prePivotDyadminoOrientation + i) % 6;
      if (self.orientation == dyadminoOrientationShouldBe) {
        return;
      } else {
        self.orientation = dyadminoOrientationShouldBe;
        
          // or else put this in an animation
        [self selectAndPositionSprites];
        return;
      }
    }
  }
}

#pragma mark - change status methods

-(void)startTouchThenHoverResize {
  self.isTouchThenHoverResized = YES;
  [self resizeDyadmino];
  [self selectAndPositionSprites];
}

-(void)endTouchThenHoverResize {
  self.isTouchThenHoverResized = NO;
  [self resizeDyadmino];
  [self selectAndPositionSprites];
}

-(void)startHovering {
  self.hoveringStatus = kDyadminoHovering;
}

-(void)keepHovering {
  self.hoveringStatus = kDyadminoContinuesHovering;
}

-(void)finishHovering {
  self.hoveringStatus = kDyadminoFinishedHovering;
}

-(void)adjustHighlightIntoPlay {
  if (self.position.y < kRackHeight + (kHeightGapToHighlightIntoPlay / 2) &&
      self.position.y >= kRackHeight - (kHeightGapToHighlightIntoPlay / 2)) {
    self.colorBlendFactor = (self.position.y + (kHeightGapToHighlightIntoPlay / 2) - kRackHeight) *
    kDyadminoColorBlendFactor / kHeightGapToHighlightIntoPlay;
  }
  if (self.position.y > kRackHeight + (kHeightGapToHighlightIntoPlay / 2)) {
    self.colorBlendFactor = kDyadminoColorBlendFactor;
  }
}

-(void)unhighlightOutOfPlay {
// TODO: possibly some animation here
  self.colorBlendFactor = 0.f;
}

#pragma mark - change state methods

-(void)setToHomeZPosition {
  if (self.homeNode.snapNodeType == kSnapNodeRack) {
    self.zPosition = kZPositionRackRestingDyadmino;
  } else {
    self.zPosition = kZPositionBoardRestingDyadmino;
  }
}

-(void)setToTempZPosition {
    self.zPosition = kZPositionBoardRestingDyadmino;
}

-(void)goHome {
  [self unhighlightOutOfPlay];
  [self orientBySnapNode:self.homeNode];
  self.zPosition = kZPositionRackMovedDyadmino;
  [self animateConstantSpeedMoveDyadminoToPoint:self.homeNode.position];
  self.tempBoardNode = nil;
  [self setToHomeZPosition];
  [self finishHovering];
}

#pragma mark - animation methods

-(void)animateConstantTimeMoveToPoint:(CGPoint)point {
  [self removeActionsAndEstablishNotRotating];
  SKAction *moveAction = [SKAction moveTo:point duration:kConstantTime];
  [self runAction:moveAction];
}

-(void)animateSlowerConstantTimeMoveToPoint:(CGPoint)point {
  [self removeActionsAndEstablishNotRotating];
  SKAction *snapAction = [SKAction moveTo:point duration:kSlowerConstantTime];
  [self runAction:snapAction];
}

-(void)animateConstantSpeedMoveDyadminoToPoint:(CGPoint)point{
  [self removeActionsAndEstablishNotRotating];
  CGFloat distance = [self getDistanceFromThisPoint:self.position toThisPoint:point];
  SKAction *snapAction = [SKAction moveTo:point duration:kConstantSpeed * distance];
  [self runAction:snapAction];
}

-(void)removeActionsAndEstablishNotRotating {
  [self removeAllActions];
  self.isRotating = NO;
}

-(void)animateFlip {
  [self removeActionsAndEstablishNotRotating];
  self.isRotating = YES;
  
  SKAction *nextFrame = [SKAction runBlock:^{
    self.orientation = (self.orientation + 1) % 6;
    [self selectAndPositionSprites];
  }];
  SKAction *waitTime = [SKAction waitForDuration:kRotateWait];
  SKAction *finishAction;
  
    // rotation
  if ([self isInRack]) {
    finishAction = [SKAction runBlock:^{
      [self finishHovering];
      [self setToHomeZPosition];
      [self endTouchThenHoverResize];
      self.isRotating = NO;
    }];
      // just to ensure that dyadmino is back in its node position
    self.position = self.homeNode.position;
    
  } else if ([self isOnBoard]) {
    finishAction = [SKAction runBlock:^{
      self.isRotating = NO;
      self.tempReturnOrientation = self.orientation;
      self.hoveringStatus = kDyadminoHovering;
    }];
  }
  
  SKAction *completeAction = [SKAction sequence:@[nextFrame, waitTime, nextFrame, waitTime, nextFrame, finishAction]];
  [self runAction:completeAction];
}

-(void)animateEaseIntoNodeAfterHover {
    // animate to homeNode as default, to tempBoardNode if it's a rack dyadmino
  CGPoint settledPosition = self.homeNode.position;
  if ([self belongsInRack] && [self isOnBoard]) {
    settledPosition = self.tempBoardNode.position;
  }
  
  SKAction *moveAction = [SKAction moveTo:settledPosition duration:kConstantTime];
  SKAction *finishAction = [SKAction runBlock:^{
    [self endTouchThenHoverResize];
    [self setToHomeZPosition];
    self.canFlip = NO;
    self.hoveringStatus = kDyadminoNoHoverStatus;
    self.prePivotPosition = CGPointZero;
  }];
  SKAction *sequence = [SKAction sequence:@[moveAction, finishAction]];
  [self runAction:sequence];
}

#pragma mark - bool methods

-(BOOL)belongsInRack {
  return (self.homeNode.snapNodeType == kSnapNodeRack);
}

-(BOOL)belongsOnBoard {
  return (self.homeNode.snapNodeType == kSnapNodeBoardTwelveAndSix ||
          self.homeNode.snapNodeType == kSnapNodeBoardTwoAndEight ||
          self.homeNode.snapNodeType == kSnapNodeBoardFourAndTen);
}

-(BOOL)isInRack {
  return (self.withinSection == kDyadminoWithinRack);
}

-(BOOL)isOnBoard {
  return (self.withinSection == kDyadminoWithinBoard);
}

-(BOOL)isHovering {
  if (self.hoveringStatus == kDyadminoHovering) {
    return YES;
  } else {
    return NO;
  }
}

-(BOOL)continuesToHover {
  if (self.hoveringStatus == kDyadminoContinuesHovering) {
    return YES;
  } else {
    return NO;
  }
}

-(BOOL)isFinishedHovering {
  if (self.hoveringStatus == kDyadminoFinishedHovering) {
    return YES;
  } else {
    return NO;
  }
}

#pragma mark - debugging methods

-(NSString *)logThisDyadmino {
  if (self) {
    NSString *tempString = [NSString stringWithFormat:@"%@", self.name];
    return tempString;
  } else {
    return @"dyadmino doesn't exist";
  }
}

@end