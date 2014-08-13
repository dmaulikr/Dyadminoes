//
//  MatchTableViewCell.m
//  Dyadminoes
//
//  Created by Bennett Lin on 5/19/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "MatchTableViewCell.h"
#import "NSObject+Helper.h"
#import "Match.h"
#import "Player.h"
#import "CellBackgroundView.h"
#import "StavesView.h"
#import "UIImage+colouredImage.h"

@interface MatchTableViewCell ()

@property (strong, nonatomic) UILabel *lastPlayedLabel;
@property (strong, nonatomic) StavesView *stavesView;
@property (strong, nonatomic) UIImageView *clefImage;

@end

@implementation MatchTableViewCell

-(void)awakeFromNib {
  
    // colour when cell is selected
  UIView *customColorView = [[UIView alloc] init];
  self.selectedBackgroundView = customColorView;
  self.accessoryType = UITableViewCellAccessoryNone;
  
    // labels for each player
  NSMutableArray *tempPlayerLabelsArray = [NSMutableArray new];
  NSMutableArray *tempPlayerLabelViewsArray = [NSMutableArray new];
  NSMutableArray *tempScoreLabelsArray = [NSMutableArray new];
  NSMutableArray *tempFermataImageViewArray = [NSMutableArray new];
  
  for (int i = 0; i < kMaxNumPlayers; i++) {
    
    CellBackgroundView *labelView = [[CellBackgroundView alloc] init];
    [tempPlayerLabelViewsArray addObject:labelView];
    [self addSubview:labelView];
    
    UILabel *playerLabel = [[UILabel alloc] init];
    playerLabel.font = [UIFont fontWithName:kFontModern size:(kIsIPhone ? (kCellRowHeight / 3.4) : (kCellRowHeight / 2.8125))];
    playerLabel.adjustsFontSizeToFitWidth = YES;
    playerLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    [tempPlayerLabelsArray addObject:playerLabel];
    [self addSubview:playerLabel];
    
    UILabel *scoreLabel = [[UILabel alloc] init];
    scoreLabel.font = [UIFont fontWithName:kFontModern size:(kCellRowHeight / 4.5)];
    scoreLabel.textColor = [UIColor brownColor];
    scoreLabel.textAlignment = NSTextAlignmentCenter;
    scoreLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    scoreLabel.frame = CGRectMake(scoreLabel.frame.origin.x, scoreLabel.frame.origin.y, kScoreLabelWidth, kScoreLabelHeight);
    scoreLabel.adjustsFontSizeToFitWidth = YES;
    [self addSubview:scoreLabel];
    [tempScoreLabelsArray addObject:scoreLabel];
    
    UIImageView *fermataImageView = [[UIImageView alloc] initWithImage:[UIImage colourImage:[UIImage imageNamed:@"fermata-med"] withColor:kStaveEndedGameColour]];
    fermataImageView.frame = CGRectMake(0, kStaveYHeight, kStaveYHeight * 2, kStaveYHeight * 2);
    fermataImageView.contentMode = UIViewContentModeScaleAspectFit;
    [tempFermataImageViewArray addObject:fermataImageView];
  }
  
  self.playerLabelsArray = [NSArray arrayWithArray:tempPlayerLabelsArray];
  self.playerLabelViewsArray = [NSArray arrayWithArray:tempPlayerLabelViewsArray];
  self.scoreLabelsArray = [NSArray arrayWithArray:tempScoreLabelsArray];
  self.fermataImageViewArray = [NSArray arrayWithArray:tempFermataImageViewArray];

    // staves and clef
  self.stavesView = [[StavesView alloc] initWithFrame:CGRectMake(self.frame.origin.x, self.frame.origin.y, kCellWidth, kCellRowHeight + kCellSeparatorBuffer)];
  [self insertSubview:self.stavesView belowSubview:self.selectedBackgroundView];
  
  self.clefImage = [UIImageView new];
  self.clefImage.contentMode = UIViewContentModeScaleAspectFit;
  [self addSubview:self.clefImage];
  
  self.lastPlayedLabel = [[UILabel alloc] initWithFrame:CGRectMake(kStaveXBuffer, (kCellRowHeight / 10) * 11.5, kCellWidth - kStaveXBuffer * 2, kStaveYHeight * 2)];
  self.lastPlayedLabel.textAlignment = NSTextAlignmentRight;
  self.lastPlayedLabel.adjustsFontSizeToFitWidth = YES;
  self.lastPlayedLabel.font = [UIFont fontWithName:kFontHarmony size:(kIsIPhone ? 20.f : 22.f)];
  [self insertSubview:self.lastPlayedLabel aboveSubview:self.stavesView];
}

-(void)setProperties {
  
  NSUInteger turn = self.myMatch.turns.count;
  
    // backgroundColour and lastPlayedLabel are not async
  if (self.myMatch.gameHasEnded) {
    self.selectedBackgroundView.backgroundColor = kEndedMatchCellSelectedColour;
    self.backgroundColor = kEndedMatchCellLightColour;
    
      // game ended, so lastPlayed label shows date
    self.lastPlayedLabel.textColor = kStaveEndedGameColour;
    self.lastPlayedLabel.text = [self returnGameEndedDateStringFromDate:self.myMatch.lastPlayed andTurn:turn];
    
  } else {
    self.selectedBackgroundView.backgroundColor = kMainSelectedYellow;
    self.backgroundColor = kMainLighterYellow;
    
      // game still in play, so lastPlayed label shows time since last played
    self.lastPlayedLabel.textColor = kStaveColour;
    self.lastPlayedLabel.text = [self returnLastPlayedStringFromDate:self.myMatch.lastPlayed andTurn:turn];
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self updateStaves];
    [self updateClef];
    
      // remove fermatas, they will be decided later
    for (UIImageView *fermataImageView in self.fermataImageViewArray) {
      [fermataImageView removeFromSuperview];
    }
    
    Player *player;
    for (int i = 0; i < kMaxNumPlayers; i++) {
      
      player = (i < self.myMatch.players.count) ? self.myMatch.players[i] : nil;
      
      UILabel *playerLabel = self.playerLabelsArray[i];
      CellBackgroundView *labelView = self.playerLabelViewsArray[i];
      UILabel *scoreLabel = self.scoreLabelsArray[i];
      
        // score label
      scoreLabel.text = (player && !(player.resigned && self.myMatch.type != kSelfGame)) ?
      [NSString stringWithFormat:@"%lu", (unsigned long)player.playerScore] : @"";
      
        // player label
      playerLabel.text = player ? player.playerName : @"";
      [playerLabel sizeToFit];
      
        // frame width can never be greater than maximum label width
      CGFloat playerLabelFrameWidth = (playerLabel.frame.size.width > kPlayerLabelWidth) ?
      kPlayerLabelWidth : playerLabel.frame.size.width;
      playerLabel.frame = CGRectMake(kStaveXBuffer + kStaveWidthDivision + (i * kStaveWidthDivision * 2), playerLabel.frame.origin.y, playerLabelFrameWidth, playerLabel.frame.size.height);
      playerLabel.center = CGPointMake(kStaveXBuffer + (kIsIPhone ? kStaveWidthDivision * 1.6f : kStaveWidthDivision * 1.3f) + (i * kStaveWidthDivision * 2) + kStaveWidthDivision / 2, playerLabel.center.y);
      
      labelView.frame = CGRectMake(labelView.frame.origin.x, labelView.frame.origin.y, playerLabel.frame.size.width + kPlayerLabelWidthPadding, playerLabel.frame.size.height + kPlayerLabelHeightPadding);
      labelView.center = CGPointMake(playerLabel.center.x,
                                     playerLabel.center.y - (kCellRowHeight / 40.f));
      labelView.layer.cornerRadius = labelView.frame.size.height / 2.f;
      labelView.clipsToBounds = YES;
      
        // static player colours, check if player resigned
      playerLabel.textColor = (player.resigned && self.myMatch.type != kSelfGame) ?
      kResignedGray : [self.myMatch colourForPlayer:player];
      
        // background colours depending on match results
      labelView.backgroundColourCanBeChanged = YES;
      if (!self.myMatch.gameHasEnded && player == self.myMatch.currentPlayer) {
        labelView.backgroundColor = [kMainDarkerYellow colorWithAlphaComponent:0.8f];
      } else if (self.myMatch.gameHasEnded && [self.myMatch.wonPlayers containsObject:player]) {
        labelView.backgroundColor = [UIColor clearColor]; // I've decided just fermata, no background for won player
        UIImageView *fermataImageView = self.fermataImageViewArray[i];
        [self addSubview:fermataImageView];
        
      } else {
        labelView.backgroundColor = [UIColor clearColor];
      }
      labelView.backgroundColourCanBeChanged = NO;
    }
    
    [self determinePlayerLabelPositionsBasedOnScores];
  });
}

#pragma mark - background threaded methods

-(void)updateStaves {
  self.stavesView.gameHasEnded = self.myMatch.gameHasEnded;
  [self.stavesView setNeedsDisplay];
}

-(void)updateClef {
  UIImage *finalImage = [self.delegate returnClefImageForMatchType:self.myMatch.type andGameEnded:self.myMatch.gameHasEnded];

  switch (self.myMatch.type) {
        // treble
    case kSelfGame:
      self.clefImage.frame = CGRectMake(0 - (kStaveXBuffer / 8), kStaveYHeight * 2.2, kStaveYHeight * 6.3, kStaveYHeight * 6.3);
      break;
      
        // bass
    case kPnPGame:
      self.clefImage.frame = CGRectMake(kStaveXBuffer, kStaveYHeight * 3, kStaveYHeight * 3.25, kStaveYHeight * 3.25);
      break;
    case kGCFriendGame:
      break;
    case kGCRandomGame:
      break;
    default:
      break;
  }
  
  self.clefImage.image = finalImage;
}

#pragma mark - view helper methods

-(void)determinePlayerLabelPositionsBasedOnScores {
  
    // first create an array of scores
  NSMutableArray *tempScores = [NSMutableArray new];
  for (int i = 0; i < self.myMatch.players.count; i++) {
    Player *player = self.myMatch.players[i];
    
      // add score only if player is in game
    if (!player.resigned || self.myMatch.type == kSelfGame) {
      NSNumber *playerScore = [NSNumber numberWithUnsignedInteger:player.playerScore];
      
        // ensure no double numbers
      ![tempScores containsObject:playerScore] ? [tempScores addObject:playerScore] : nil;
    }
  }
  
  NSArray *sortedScores = [tempScores sortedArrayUsingSelector:@selector(compare:)];

  for (int i = 0; i < self.myMatch.players.count; i++) {
    
    Player *player = self.myMatch.players[i];
    UILabel *playerLabel = self.playerLabelsArray[i];
    CellBackgroundView *labelView = self.playerLabelViewsArray[i];
    UILabel *scoreLabel = self.scoreLabelsArray[i];
    NSInteger playerPosition = (player.resigned && self.myMatch.type != kSelfGame) ?
        -1 : [sortedScores indexOfObject:[NSNumber numberWithUnsignedInteger:player.playerScore]] + 1;

    playerLabel.center = CGPointMake(playerLabel.center.x, [self labelHeightForMaxPosition:sortedScores.count andPlayerPosition:playerPosition]);
    labelView.center = CGPointMake(playerLabel.center.x,
                                   playerLabel.center.y - (kCellRowHeight / 40.f));
    scoreLabel.center = CGPointMake(playerLabel.center.x, playerLabel.center.y + kStaveYHeight * 1.5f);
    
    UIImageView *fermataImageView = self.fermataImageViewArray[i];
    if (fermataImageView.superview) {
      fermataImageView.center = CGPointMake(playerLabel.center.x, fermataImageView.center.y);
    }
  }
}

-(CGFloat)labelHeightForMaxPosition:(NSUInteger)maxPosition andPlayerPosition:(NSInteger)playerPosition {
  
    // positions are 4, 4.5, 5, 5.5, 6 being resigned player
  CGFloat multFloat = (playerPosition == -1) ? 6 : ((maxPosition - playerPosition) / 2.f) + 4;
  return (multFloat * kStaveYHeight);
}

@end
