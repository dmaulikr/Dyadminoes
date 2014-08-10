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

  // TODO: verify this
#define kPlayerLabelWidth (kIsIPhone ? kCellWidth / 6.f : kCellWidth / 5.8f)
#define kPlayerLabelHeightPadding (kCellRowHeight / 12)
#define kPlayerLabelWidthPadding (kPlayerLabelWidth / 4.84444444)
#define kScoreLabelWidth kPlayerLabelWidth
#define kScoreLabelHeight (kCellRowHeight / 2.66666667)
#define kMaxNumPlayers 4

@interface MatchTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *player1Label;
@property (weak, nonatomic) IBOutlet UILabel *player2Label;
@property (weak, nonatomic) IBOutlet UILabel *player3Label;
@property (weak, nonatomic) IBOutlet UILabel *player4Label;

@property (strong, nonatomic) CellBackgroundView *player1LabelView;
@property (strong, nonatomic) CellBackgroundView *player2LabelView;
@property (strong, nonatomic) CellBackgroundView *player3LabelView;
@property (strong, nonatomic) CellBackgroundView *player4LabelView;

@property (weak, nonatomic) IBOutlet UILabel *score1Label;
@property (weak, nonatomic) IBOutlet UILabel *score2Label;
@property (weak, nonatomic) IBOutlet UILabel *score3Label;
@property (weak, nonatomic) IBOutlet UILabel *score4Label;

@property (weak, nonatomic) IBOutlet UILabel *lastPlayedLabel;

@property (strong, nonatomic) UIImageView *clefImage;
@property (strong, nonatomic) NSArray *fermataImageViewArray;

@property (strong, nonatomic) NSArray *playerLabelsArray;
@property (strong, nonatomic) NSArray *playerLabelViewsArray;
@property (strong, nonatomic) NSArray *scoreLabelsArray;

@property (strong, nonatomic) StavesView *stavesView;

@end

@implementation MatchTableViewCell

-(void)awakeFromNib {
  
    // colour when cell is selected
  UIView *customColorView = [[UIView alloc] init];
  self.selectedBackgroundView = customColorView;
  
  self.playerLabelsArray = @[self.player1Label, self.player2Label, self.player3Label, self.player4Label];
  
  self.player1LabelView = [[CellBackgroundView alloc] init];
  self.player2LabelView = [[CellBackgroundView alloc] init];
  self.player3LabelView = [[CellBackgroundView alloc] init];
  self.player4LabelView = [[CellBackgroundView alloc] init];
  self.playerLabelViewsArray = @[self.player1LabelView, self.player2LabelView, self.player3LabelView, self.player4LabelView];
  
  self.scoreLabelsArray = @[self.score1Label, self.score2Label, self.score3Label, self.score4Label];
  
  for (int i = 0; i < 4; i++) {
    UILabel *playerLabel = self.playerLabelsArray[i];
    playerLabel.font = [UIFont fontWithName:kPlayerNameFont size:(kIsIPhone ? (kCellRowHeight / 3.4) : (kCellRowHeight / 2.8125))];
    CellBackgroundView *labelView = self.playerLabelViewsArray[i];
    [self insertSubview:labelView belowSubview:playerLabel];
    
    UILabel *scoreLabel = self.scoreLabelsArray[i];
    scoreLabel.font = [UIFont fontWithName:kPlayerNameFont size:(kCellRowHeight / 4.5)];
    scoreLabel.textColor = [UIColor brownColor];
    scoreLabel.textAlignment = NSTextAlignmentCenter;
    scoreLabel.frame = CGRectMake(scoreLabel.frame.origin.x, scoreLabel.frame.origin.y, kScoreLabelWidth, kScoreLabelHeight);
  }
  
  self.lastPlayedLabel.adjustsFontSizeToFitWidth = YES;
  self.lastPlayedLabel.frame = CGRectMake(kStaveXBuffer, (kCellRowHeight / 10) * 11,
                                          kCellWidth - kStaveXBuffer * 2, kStaveYHeight * 2);

  self.stavesView = [[StavesView alloc] initWithFrame:CGRectMake(self.frame.origin.x, self.frame.origin.y, kCellWidth, kCellRowHeight + kCellSeparatorBuffer)];
  [self insertSubview:self.stavesView belowSubview:self.selectedBackgroundView];
  
  self.clefImage = [UIImageView new];
  self.clefImage.frame = CGRectMake(kStaveXBuffer, kStaveYHeight * 3, kStaveYHeight * 3.25, kStaveYHeight * 3.25);
  [self addSubview:self.clefImage];
  
  UIImage *fermataImage = [UIImage imageNamed:@"fermata-med"];
  fermataImage = [UIImage colourImage:fermataImage withColor:kStaveEndedGameColour];
  NSMutableArray *tempFermataImageViewArray = [NSMutableArray new];
  for (int i = 0; i < 4; i++) {
    UIImageView *fermataImageView = [[UIImageView alloc] initWithImage:fermataImage];
    fermataImageView.frame = CGRectMake(0, kStaveYHeight, kStaveYHeight * 2, kStaveYHeight * 2);
    fermataImageView.contentMode = UIViewContentModeScaleAspectFit;
    [tempFermataImageViewArray addObject:fermataImageView];
  }
  self.fermataImageViewArray = [NSArray arrayWithArray:tempFermataImageViewArray];
}

-(void)setProperties {
  
  self.stavesView.gameHasEnded = self.myMatch.gameHasEnded;
  [self.stavesView setNeedsDisplay];
  
  UIImage *clefImage = (self.myMatch.players.count == 1) ?
      [UIImage imageNamed:@"treble-clef-med"] : [UIImage imageNamed:@"bass-clef-md"];
  UIColor *clefColour = self.myMatch.gameHasEnded ? kStaveEndedGameColour : kStaveColour;
  UIImage *colouredImage = [UIImage colourImage:clefImage withColor:clefColour];
  self.clefImage.image = colouredImage;
  self.clefImage.contentMode = UIViewContentModeScaleAspectFit;

    // remove fermatas, they will be decided later
  for (UIImageView *fermataImageView in self.fermataImageViewArray) {
    [fermataImageView removeFromSuperview];
  }
  
  if (self.myMatch) {
    
    Player *player;
    for (int i = 0; i < kMaxNumPlayers; i++) {

      player = (i < self.myMatch.players.count) ? self.myMatch.players[i] : nil;
      
      UILabel *playerLabel = self.playerLabelsArray[i];
      CellBackgroundView *labelView = self.playerLabelViewsArray[i];
      UILabel *scoreLabel = self.scoreLabelsArray[i];

        // score label
      scoreLabel.text = (player && !(player.resigned && self.myMatch.type != kSelfGame)) ?
          [NSString stringWithFormat:@"%lu", (unsigned long)player.playerScore] : @"";
      scoreLabel.adjustsFontSizeToFitWidth = YES;
      
        // player label
      playerLabel.text = player ? player.playerName : @"";
      [playerLabel sizeToFit];
      
        // frame width can never be greater than maximum label width
      CGFloat playerLabelFrameWidth = (playerLabel.frame.size.width > kPlayerLabelWidth) ?
          kPlayerLabelWidth : playerLabel.frame.size.width;
      playerLabel.frame = CGRectMake(kStaveXBuffer + kStaveWidthDivision + (i * kStaveWidthDivision * 2), playerLabel.frame.origin.y, playerLabelFrameWidth, playerLabel.frame.size.height);
        // first kStaveWidthDivision is for clef
      playerLabel.center = CGPointMake(kStaveXBuffer + (kIsIPhone ? kStaveWidthDivision * 1.6f : kStaveWidthDivision * 1.3f) + (i * kStaveWidthDivision * 2) + kStaveWidthDivision / 2, playerLabel.center.y);
      
        // make font size smaller if it can't fit
      playerLabel.adjustsFontSizeToFitWidth = YES;
      playerLabel.minimumScaleFactor = 0.5f;
      labelView.frame = CGRectMake(0, 0, playerLabel.frame.size.width + kPlayerLabelWidthPadding, playerLabel.frame.size.height + kPlayerLabelHeightPadding);

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
    
    if (self.myMatch.gameHasEnded) {
      
      self.selectedBackgroundView.backgroundColor = kEndedMatchCellSelectedColour;
      self.backgroundColor = kEndedMatchCellLightColour;
      
        // game ended, so lastPlayed label shows date
      self.lastPlayedLabel.textColor = kStaveEndedGameColour;
      self.lastPlayedLabel.text = [self returnGameEndedDateStringFromDate:self.myMatch.lastPlayed];
      
    } else {
      self.selectedBackgroundView.backgroundColor = kMainSelectedYellow;
      self.backgroundColor = kMainLighterYellow;
      
        // game still in play, so lastPlayed label shows time since last played
      self.lastPlayedLabel.textColor = kStaveColour;
      self.lastPlayedLabel.text = [self returnLastPlayedStringFromDate:self.myMatch.lastPlayed
                                                               started:(self.myMatch.turns.count == 0 ? YES : NO)];
    }
  }
  
  [self determinePlayerLabelPositionsBasedOnScores];
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

//    playerLabel.frame = CGRectMake(playerLabel.frame.origin.x,
//                                   playerLabel.frame.origin.y,
//                                   playerLabel.frame.size.width,
//                                   playerLabel.frame.size.height);
    playerLabel.center = CGPointMake(playerLabel.center.x, [self labelHeightForMaxPosition:sortedScores.count andPlayerPosition:playerPosition]);
    labelView.center = CGPointMake(playerLabel.center.x,
                                   playerLabel.center.y - (kCellRowHeight / 40.f));
    scoreLabel.center = CGPointMake(playerLabel.center.x, playerLabel.center.y + kStaveYHeight * 1.5f);
//    scoreLabel.frame = CGRectMake(playerLabel.frame.origin.x + playerLabel.frame.size.width + (kIsIPhone ? kPlayerLabelWidthPadding / 6 : kPlayerLabelWidthPadding / 4), scoreLabel.frame.origin.y, scoreLabel.frame.size.width, scoreLabel.frame.size.height);
    
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
