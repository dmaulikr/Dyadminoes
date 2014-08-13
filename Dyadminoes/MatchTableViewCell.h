//
//  MatchTableViewCell.h
//  Dyadminoes
//
//  Created by Bennett Lin on 5/19/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSObject+Helper.h"
@class Match;

@protocol MatchCellDelegate;

@interface MatchTableViewCell : UITableViewCell

@property (strong, nonatomic) Match *myMatch;
@property (weak, nonatomic) id<MatchCellDelegate> delegate;

@property (strong, nonatomic) NSArray *playerLabelsArray;
@property (strong, nonatomic) NSArray *playerLabelViewsArray;
@property (strong, nonatomic) NSArray *scoreLabelsArray;
@property (strong, nonatomic) NSArray *fermataImageViewArray;

-(void)setProperties;

@end

@protocol MatchCellDelegate <NSObject>

-(UIImage *)returnClefImageForMatchType:(GameType)type andGameEnded:(BOOL)gameEnded;

@end