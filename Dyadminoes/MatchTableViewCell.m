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

@interface MatchTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *player1Label;
@property (weak, nonatomic) IBOutlet UILabel *player2Label;
@property (weak, nonatomic) IBOutlet UILabel *player3Label;
@property (weak, nonatomic) IBOutlet UILabel *player4Label;

@property (weak, nonatomic) IBOutlet UILabel *score1Label;
@property (weak, nonatomic) IBOutlet UILabel *score2Label;
@property (weak, nonatomic) IBOutlet UILabel *score3Label;
@property (weak, nonatomic) IBOutlet UILabel *score4Label;

@property (weak, nonatomic) IBOutlet UILabel *lastPlayedLabel;
@property (weak, nonatomic) IBOutlet UILabel *winnerLabel;

@property (strong, nonatomic) NSArray *playerLabelsArray;
@property (strong, nonatomic) NSArray *scoreLabelsArray;

@end

@implementation MatchTableViewCell

-(void)awakeFromNib {
  self.playerLabelsArray = @[self.player1Label, self.player2Label, self.player3Label, self.player4Label];
  self.scoreLabelsArray = @[self.score1Label, self.score2Label, self.score3Label, self.score4Label];
  self.winnerLabel.text = @"";
  [self setProperties];
}

-(void)setProperties {
  
  for (UILabel *label in self.playerLabelsArray) {
    label.text = @"";
  }
  
  for (UILabel *label in self.scoreLabelsArray) {
    label.text = @"";
  }
  
  if (self.myMatch) {
    
    self.lastPlayedLabel.text = [self returnStringFromDate:self.myMatch.lastPlayed];
    
    for (Player *player in self.myMatch.players) {
      UILabel *playerLabel = self.playerLabelsArray[[self.myMatch.players indexOfObject:player]];
      UILabel *scoreLabel = self.scoreLabelsArray[[self.myMatch.players indexOfObject:player]];

      playerLabel.text = player.playerName;

      if (player.resigned) {
        playerLabel.textColor = [UIColor lightGrayColor];
      } else if (player == self.myMatch.currentPlayer) {
        playerLabel.textColor = [UIColor orangeColor];
      } else if ([self.myMatch.wonPlayers containsObject:player]) {
        playerLabel.textColor = [UIColor greenColor];
      } else {
        playerLabel.textColor = [UIColor blackColor];
      }
      
      scoreLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)player.playerScore];
    }
    
    if (self.myMatch.wonPlayers.count > 0) {
      NSMutableArray *wonPlayerNames = [[NSMutableArray alloc] initWithCapacity:self.myMatch.wonPlayers.count];
      for (Player *player in self.myMatch.wonPlayers) {
        [wonPlayerNames addObject:player.playerName];
      }
      
      NSString *wonPlayers = [wonPlayerNames componentsJoinedByString:@" and "];
      self.winnerLabel.text = [NSString stringWithFormat:@"%@ won!", wonPlayers];
    } else {
      self.winnerLabel.text = @"";
    }
    
  }
}

@end