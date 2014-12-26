//
//  Match.m
//  Dyadminoes
//
//  Created by Bennett Lin on 5/19/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "Match.h"
#import "Player.h"
#import "DataDyadmino.h"

@interface Match ()

@property (strong, nonatomic) NSMutableArray *pile; // was mutable array
@property (strong, nonatomic) NSMutableSet *board; // was mutable set

@end

@implementation Match

  // persisted
@dynamic rules;
@dynamic skill;
@dynamic type;
@dynamic lastPlayed;
@dynamic players;
@dynamic currentPlayerIndex;
@dynamic gameHasEnded;
@dynamic dataDyadminoes;
@dynamic holdingIndexContainer;
@dynamic swapIndexContainer;
@dynamic replayTurn;
@dynamic turns;
@dynamic firstDataDyadIndex;
@dynamic randomNumber1To24;
@dynamic arrayOfChordsAndPoints;
@dynamic pointsThisTurn;

  // not persisted
@synthesize replayBoard = _replayBoard;
@synthesize delegate = _delegate;
@synthesize pile = _pile;
@synthesize board = _board;

#pragma mark - init methods

-(void)initialPlayers:(NSSet *)players andRules:(GameRules)rules andSkill:(GameSkill)skill withContext:(NSManagedObjectContext *)managedObjectContext {

  [self setPlayers:players];

  if (self.players.count != players.count) {
    NSLog(@"Players not set properly.");
    abort();
    
  } else {
    self.rules = [NSNumber numberWithUnsignedInteger:rules];
    self.skill = [NSNumber numberWithUnsignedInteger:skill];
    self.type = (players.count == 1) ? [NSNumber numberWithUnsignedInteger:kSelfGame] : [NSNumber numberWithUnsignedInteger:kPnPGame];
    
    self.lastPlayed = [NSDate date];
    self.gameHasEnded = [NSNumber numberWithBool:NO];
    self.currentPlayerIndex = [NSNumber numberWithUnsignedInteger:0];
    self.randomNumber1To24 = [NSNumber numberWithUnsignedInteger:[self randomIntegerUpTo:24] + 1];
    
    self.holdingIndexContainer = [NSMutableArray new];
    self.swapIndexContainer = [NSMutableSet new];

    self.turns = [NSMutableArray new];
    self.replayTurn = [NSNumber numberWithUnsignedInteger:0];
    
    if (![self generateDataDyadminoesWithContext:managedObjectContext]) {
      NSLog(@"Data dyadminoes not generated properly.");
      abort();

    } else {
      [self placeFirstDyadminoOnBoard];
      if (![self distributePileAmongstPlayers]) {
        NSLog(@"Pile not distributed amongst players properly.");
        abort();
      }
    }
  }
}

-(BOOL)generateDataDyadminoesWithContext:(NSManagedObjectContext *)context {
  NSMutableSet *tempSet = [NSMutableSet new];
  
    // start index at 0 (previously started at 1)
  for (NSUInteger i = 0; i < kPileCount; i++) {
    
    DataDyadmino *dataDyad = [NSEntityDescription insertNewObjectForEntityForName:@"DataDyadmino" inManagedObjectContext:context];

    [dataDyad initialID:i];
    [tempSet addObject:dataDyad];
  }
  
  [self setDataDyadminoes:[NSSet setWithSet:tempSet]];
  return (self.dataDyadminoes.count == kPileCount);
}

-(BOOL)distributePileAmongstPlayers {
  for (Player *player in self.players) {
    [self fillRackFromPileForPlayer:player];
    if ([(NSArray *)player.dataDyadminoIndexesThisTurn count] != kNumDyadminoesInRack) {
      return NO;
    }
  }
  return YES;
}

-(void)placeFirstDyadminoOnBoard {
  
  while (self.board.count == 0 && self.pile.count > 0) {
    
    NSUInteger randIndex = [self randomIntegerUpTo:self.pile.count];
    self.firstDataDyadIndex = [NSNumber numberWithUnsignedInteger:randIndex];
    DataDyadmino *firstDyadmino = [self dataDyadminoForIndex:randIndex];
    
    if ([self.pile containsObject:firstDyadmino]) {
      struct HexCoord myHex = {0, 0};
      firstDyadmino.myHexCoord = myHex;
      
        // establish first dyadmino is out of pile and now on board
      firstDyadmino.placeStatus = [NSNumber numberWithUnsignedInteger:kOnBoard];
      [self.pile removeObject:firstDyadmino];
      [self.board addObject:firstDyadmino];

      [self persistChangedPositionForBoardDataDyadmino:firstDyadmino];
    }
  }
}

#pragma mark - game play methods

-(void)fillRackFromPileForPlayer:(Player *)player {
    // reset rack order of data dyadminoes already in rack
  NSArray *dataDyadminoIndexesThisTurn = player.dataDyadminoIndexesThisTurn;
  
  while (dataDyadminoIndexesThisTurn.count < kNumDyadminoesInRack && self.pile.count > 0) {
    NSUInteger randIndex = [self randomIntegerUpTo:self.pile.count];
    DataDyadmino *dataDyad = self.pile[randIndex];
      // rack order is total count at the time
    dataDyad.myRackOrder = [NSNumber numberWithInteger:dataDyadminoIndexesThisTurn.count];
    
      // establish dyadmino is out of pile and in rack
    dataDyad.placeStatus = [NSNumber numberWithUnsignedInteger:kInRack];
    [self.pile removeObjectAtIndex:randIndex];
    [player addToThisTurnsDataDyadmino:dataDyad];
    dataDyadminoIndexesThisTurn = player.dataDyadminoIndexesThisTurn;
  }
}

-(Player *)switchToNextPlayer {
  
  Player *currentPlayer = [self returnCurrentPlayer];
  NSUInteger index = [currentPlayer returnPlayerOrder];
  if ([self checkNumberOfPlayersStillInGame] > 1) {

    while (index < self.players.count * 2) {
      Player *nextPlayer = [self playerForIndex:(index + 1) % self.players.count];
      if ([nextPlayer returnResigned]) {
        index++;
      } else {
        self.currentPlayerIndex = [NSNumber numberWithUnsignedInteger:[nextPlayer returnPlayerOrder]];
        
        [self.delegate handleSwitchToNextPlayer];
        
        return nextPlayer;
      }
    }
  }
  return nil;
}

#pragma mark - game state change methods

-(BOOL)swapDyadminoesFromCurrentPlayer {

  NSUInteger swapContainerCount = [(NSArray *)self.swapIndexContainer count];
  if (swapContainerCount <= self.pile.count && swapContainerCount > 0) {
    
    Player *player = [self returnCurrentPlayer];
    
      // temporarily store swapped data dyadminoes so that player doesn't get same ones back
    NSMutableArray *tempDataDyadminoes = [NSMutableArray new];
    
      // remove data dyadminoes from player rack, store in temp array
    for (NSNumber *number in self.swapIndexContainer) {
      DataDyadmino *dataDyad = [self dataDyadminoForIndex:[number unsignedIntegerValue]];
      dataDyad.placeStatus = [NSNumber numberWithUnsignedInteger:kInPile];
      [player removeFromThisTurnsDataDyadmino:dataDyad];
      [tempDataDyadminoes addObject:dataDyad];
    }
    
      // fill player rack from pile
    [self fillRackFromPileForPlayer:player];
    
      // add data dyadminoes in temp array back to pile
    for (DataDyadmino *dataDyad in tempDataDyadminoes) {
      [self.pile addObject:dataDyad];
    }
    
    [self removeAllSwaps];
    
    [self resetHoldingContainer];
    [self resetArrayOfChordsAndPoints];
    [self recordDyadminoesFromCurrentPlayerWithSwap:YES]; // this records turn as a pass
      // sort the board and pile
    [self sortPileArray];
    return YES;
  }
  return NO;
}

-(void)recordDyadminoesFromCurrentPlayerWithSwap:(BOOL)swap {
  
  NSSet *chordSonorities = [self totalChordSonoritiesThisTurn];
  NSNumber *points = @([self sumOfPointsThisTurn]);
  
    // a pass has an empty holding container, while a resign has *no* holding container
  NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInteger:[self returnCurrentPlayerIndex]], kTurnPlayer,
                              self.holdingIndexContainer, kTurnDyadminoes,
                              chordSonorities, kTurnChords,
                              points, kTurnPoints,
                              nil];
  
  [self addTurn:dictionary];
  NSLog(@"turn dictionary is %@", dictionary);
  
  NSArray *turns = self.turns;
  self.replayTurn = [NSNumber numberWithUnsignedInteger:turns.count];
  
      // player passes
  if ([(NSArray *)self.holdingIndexContainer count] == 0) {
    
      // if solo game, ends right away
      // FIXME: this will need to be changed to accommodate when board dyadmino
      // is moved to create a chord and nothing else, which counts as a turn and
      // not a pass
    if ([self returnType] == kSelfGame && !swap) {
      [self endGame];
      return;
    }
    
      // enough players passed to end game
      // 1. two rotations if there are dyadminoes left in pile
      // 2. one rotation if no dyadminoes are left in pile
    if ([self returnType] != kSelfGame && [self allPlayersBeforePassedOrResignedToEndGame]) {
      [self endGame];
      return;
    }
    
      // player submitted dyadminoes
  } else {
    
      /// obviously scorekeeping will be more sophisticated
      /// and will consider chords formed
    Player *player = [self returnCurrentPlayer];
    NSUInteger newScore = [player returnPlayerScore] + [self sumOfPointsThisTurn];
    player.playerScore = [NSNumber numberWithUnsignedInteger:newScore];
    
    for (DataDyadmino *dataDyad in [self dataDyadsInIndexContainer:self.holdingIndexContainer]) {
      if ([player.dataDyadminoIndexesThisTurn containsObject:dataDyad.myID]) {
        dataDyad.placeStatus = [NSNumber numberWithUnsignedInteger:kOnBoard];
        [player removeFromThisTurnsDataDyadmino:dataDyad];
        [self.board addObject:dataDyad];
      }
    }
    
      // reset rack order
    NSArray *dataDyadminoIndexesThisTurn = player.dataDyadminoIndexesThisTurn;
    for (NSInteger i = 0; i < dataDyadminoIndexesThisTurn.count; i++) {
      NSNumber *number = dataDyadminoIndexesThisTurn[i];
      DataDyadmino *dataDyad = [self dataDyadminoForIndex:[number unsignedIntegerValue]];
      dataDyad.myRackOrder = [NSNumber numberWithInteger:i];
    }
    
      // if player ran out and pile is empty, then end game
    if ([self checkPlayerFirstToRunOut]) {
      [self endGame];
      return;
        // else just refill the rack
    } else {
      [self fillRackFromPileForPlayer:player];
    }
      // sort the board and pile
    [self sortPileArray];
  }
  
      // whether pass or not, game continues
  [self resetHoldingContainer];
  [self resetArrayOfChordsAndPoints];
  self.lastPlayed = [NSDate date];
  [self switchToNextPlayer];
}

-(BOOL)allPlayersBeforePassedOrResignedToEndGame {

  NSUInteger indexOfNextPlayer = ([self returnCurrentPlayerIndex] + 1) % self.players.count;
    // find player other than current player who is still in game
  Player *activeOtherPlayer;
  while (!activeOtherPlayer && indexOfNextPlayer != [self returnCurrentPlayerIndex]) {
    Player *nextPlayer = [self playerForIndex:indexOfNextPlayer];
    if (![nextPlayer returnResigned]) {
      activeOtherPlayer = nextPlayer;
    }
    indexOfNextPlayer = (indexOfNextPlayer + 1) % self.players.count;
  }
  
  if (!activeOtherPlayer) {
    return YES;
  }
  
  NSInteger turnIndex = [(NSArray *)self.turns count] - 1;
  NSUInteger numberOfSightingsOfActiveOtherPlayer = 0;
  NSUInteger numberOfSightingsOfActiveOtherPlayerNeededToEndMatch = (self.pile.count > 0) ? 2 : 1;
  BOOL everyonePassedOrResignedSoFar = YES;
  
  while (turnIndex >= 0 && everyonePassedOrResignedSoFar &&
         numberOfSightingsOfActiveOtherPlayer < numberOfSightingsOfActiveOtherPlayerNeededToEndMatch) {
    NSDictionary *turn = [self.turns objectAtIndex:turnIndex];
    NSArray *indexContainer = [turn objectForKey:kTurnDyadminoes];

      // return no if this player scored
    if (indexContainer && indexContainer.count > 0) {
      everyonePassedOrResignedSoFar = NO;
    }
    
    Player *playerInRotation = [self playerForIndex:[[turn objectForKey:kTurnPlayer] unsignedIntegerValue]];
    if (playerInRotation == activeOtherPlayer) {
      numberOfSightingsOfActiveOtherPlayer++;
    }
    
    turnIndex--;
  }
  
    // did not run out of turns, and everyone passed or resigned
    // in every turn after the active other player was first sighted
    // the required number of times
  return ((numberOfSightingsOfActiveOtherPlayer == numberOfSightingsOfActiveOtherPlayerNeededToEndMatch) && everyonePassedOrResignedSoFar);
}

-(void)persistChangedPositionForBoardDataDyadmino:(DataDyadmino *)dataDyad {
  if ([self.board containsObject:dataDyad]) {
    
    NSNumber *lastHexX;
    NSNumber *lastHexY;
    NSNumber *lastOrientation;
    NSArray *turnChanges = dataDyad.turnChanges;
    
      // get last hexCoord and orientation
      // (must be iterated separately, because they might be in different dictionaries)
    NSInteger hexCoordCounter = turnChanges.count - 1;
    while (!(lastHexX || lastHexY) && hexCoordCounter >= 0) {
      NSDictionary *lastDictionary = (NSDictionary *)dataDyad.turnChanges[hexCoordCounter];
      lastHexX = (NSNumber *)[lastDictionary objectForKey:@"hexX"];
      lastHexY = (NSNumber *)[lastDictionary objectForKey:@"hexY"];
      hexCoordCounter--;
    }
    NSInteger orientationCounter = turnChanges.count - 1;
    while (!lastOrientation && orientationCounter >= 0) {
      NSDictionary *lastDictionary = (NSDictionary *)dataDyad.turnChanges[orientationCounter];
      lastOrientation = (NSNumber *)[lastDictionary objectForKey:@"orientation"];
      orientationCounter--;
    }
    
      // if either hexCoord position or orientation has changed, or was never established
    if ((!lastHexX || dataDyad.myHexCoord.x != [lastHexX integerValue]) ||
        (!lastHexY || dataDyad.myHexCoord.y != [lastHexY integerValue]) ||
        (!lastOrientation || [dataDyad returnMyOrientation] != [lastOrientation unsignedIntegerValue])) {
      
        // create new dictionary
      NSMutableDictionary *newDictionary = [NSMutableDictionary new];
      NSArray *turns = self.turns;
      NSNumber *thisTurn = [NSNumber numberWithUnsignedInteger:turns.count]; // first dyadmino turn count will be 0
      [newDictionary setObject:thisTurn forKey:@"turn"];
      
        // set object for changed hexCoord position
      if (!(lastHexX || lastHexY) || !(dataDyad.myHexCoord.x == [lastHexX integerValue] && dataDyad.myHexCoord.y == [lastHexY integerValue])) {
        NSNumber *newHexX = [NSNumber numberWithInteger:dataDyad.myHexCoord.x];
        NSNumber *newHexY = [NSNumber numberWithInteger:dataDyad.myHexCoord.y];
        [newDictionary setObject:newHexX forKey:@"hexX"];
        [newDictionary setObject:newHexY forKey:@"hexY"];
      }
      
        // set object for changed orientation
      if (!lastOrientation || [dataDyad returnMyOrientation] != [lastOrientation unsignedIntegerValue]) {
        NSNumber *newOrientation = [NSNumber numberWithUnsignedInteger:[dataDyad returnMyOrientation]];
        [newDictionary setObject:newOrientation forKey:@"orientation"];
      }
      
      NSMutableArray *mutableTurnChanges = [NSMutableArray arrayWithArray:dataDyad.turnChanges];
      [mutableTurnChanges addObject:[NSDictionary dictionaryWithDictionary:newDictionary]];
      dataDyad.turnChanges = [NSArray arrayWithArray:mutableTurnChanges];
    }
  }
}

-(void)resignPlayer:(Player *)player {
  
    // a resign has *no* holding container
  if (self.type != kSelfGame) {
    
    NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:[self returnCurrentPlayerIndex]], kTurnPlayer, nil];
    
    [self addTurn:dictionary];
    NSArray *turns = self.turns;
    self.replayTurn = [NSNumber numberWithUnsignedInteger:turns.count];
  }

  player.resigned = [NSNumber numberWithBool:YES];
  NSArray *dataDyads = [self dataDyadsInIndexContainer:player.dataDyadminoIndexesThisTurn];
  for (DataDyadmino *dataDyad in dataDyads) {
    dataDyad.placeStatus = [NSNumber numberWithUnsignedInteger:kInPile];
  }
  
  [self.pile addObjectsFromArray:dataDyads];
  [self sortPileArray];
  
  [self resetHoldingContainer];
  [self resetArrayOfChordsAndPoints];
  [player removeAllDataDyadminoesThisTurn];
  if (![self switchToNextPlayer]) {
    [self endGame];
  }
  
  self.lastPlayed = [NSDate date];
}

-(void)endGame {
  self.currentPlayerIndex = [NSNumber numberWithUnsignedInteger:0];
  [self resetHoldingContainer];
  [self resetArrayOfChordsAndPoints];
  
    // if solo game, sole player is winner if any score at all
  if ([self returnType] == kSelfGame) {
    Player *soloPlayer = [self playerForIndex:0];
      // player only won if score greater than 0
    soloPlayer.won = ([soloPlayer returnPlayerScore] > 0) ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];
    
  } else {
      // rules out that players with no points can win
    NSUInteger maxScore = 1;
    
    for (Player *player in self.players) {
      if (![player returnResigned]) {
        
        NSUInteger playerScore = [player returnPlayerScore];
        if (playerScore > maxScore) {
          maxScore = playerScore;
        }
      }
    }
    
    for (Player *player in self.players) {
      if ([player returnPlayerScore] == maxScore) {
        player.won = [NSNumber numberWithBool:YES];
      }
    }
  }

  self.gameHasEnded = [NSNumber numberWithBool:YES];
  [self.delegate handleEndGame];
}

#pragma mark - helper methods

-(BOOL)checkPlayerFirstToRunOut {
  Player *currentPlayer = [self returnCurrentPlayer];
  NSArray *dataDyadminoIndexesThisTurn = currentPlayer.dataDyadminoIndexesThisTurn;
  return (dataDyadminoIndexesThisTurn.count == 0 && self.pile.count == 0);
}

-(NSUInteger)checkNumberOfPlayersStillInGame {
  NSUInteger numberOfPlayersInGame = 0;
  for (Player *player in self.players) {
    if (![player returnResigned]) {
      numberOfPlayersInGame++;
    }
  }
  return numberOfPlayersInGame;
}

-(void)sortPileArray {
  [self sortDyadminoes:self.pile];
}

-(void)sortDyadminoes:(NSMutableArray *)array {
  NSSortDescriptor *sortByID = [[NSSortDescriptor alloc] initWithKey:@"myID" ascending:YES];
  [array sortedArrayUsingDescriptors:@[sortByID]];
}

-(NSString *)endGameResultsText {
  
  NSString *resultsText;
    // there are winners if there is any score at all
  
  if ([self wonPlayersCount] > 0) {
    
    NSMutableArray *wonPlayerNames = [[NSMutableArray alloc] initWithCapacity:[self wonPlayersCount]];
    for (Player *player in self.players) {
      [player returnWon] ? [wonPlayerNames addObject:player.playerName] : nil;
    }
    
    NSString *wonPlayers = [wonPlayerNames componentsJoinedByString:@" and "];
    resultsText = [NSString stringWithFormat:@"%@ won!", wonPlayers];
    
      // solo game with no score
  } else if ([self returnType] == kSelfGame) {
    resultsText = @"Scoreless game.";
    
  } else {
    resultsText = @"Draw game.";
  }
  
  return resultsText;
}

-(NSString *)turnTextLastPlayed:(BOOL)lastPlayed {
  Player *turnPlayer = [self playerForIndex:[[self.turns[[self returnReplayTurn] - 1] objectForKey:kTurnPlayer] unsignedIntegerValue]];
  NSArray *dyadminoesPlayed;
  
  NSUInteger points;
  if ([self.turns[[self returnReplayTurn] - 1] objectForKey:kTurnDyadminoes]) {
    dyadminoesPlayed = [self.turns[[self returnReplayTurn] - 1] objectForKey:kTurnDyadminoes];
    points = [[self.turns[[self returnReplayTurn] - 1] objectForKey:kTurnPoints] unsignedIntegerValue];
  }
  
  NSString *dyadminoesPlayedString;
  if (dyadminoesPlayed.count > 0) {
//    NSAttributedString *chordsText = [self.delegate stringForSonorities:chordSonoritiesPlayed withInitialString:@"" andEndingString:@""];
//    NSLog(@"chordsText is %@", chordsText);
    
    dyadminoesPlayedString = [NSString stringWithFormat:@"scored %i points", points];
  } else if (!dyadminoesPlayed) {
    dyadminoesPlayedString = @"resigned";
  } else if (dyadminoesPlayed.count == 0) {
    dyadminoesPlayedString = @"passed";
  }
  
  if (lastPlayed) {
    if (dyadminoesPlayed.count > 0) {
      return [NSString stringWithFormat:@"%@ last %@.", turnPlayer.playerName, dyadminoesPlayedString];
    } else {
      return [NSString stringWithFormat:@"%@ %@ last turn.", turnPlayer.playerName, dyadminoesPlayedString];
    }

  } else {
    NSArray *turns = self.turns;
    return [NSString stringWithFormat:@"%@ %@ for turn %lu of %lu.", turnPlayer.playerName, dyadminoesPlayedString, (unsigned long)[self returnReplayTurn], (unsigned long)turns.count];
  }
}

-(UIColor *)colourForPlayer:(Player *)player {
  if ([self.players containsObject:player]) {
    
    NSUInteger playerIndex = [player returnPlayerOrder];
    NSUInteger randomIndex = (playerIndex + [self returnRandomNumber1To24]) % 4;
    return [self colourForIndex:randomIndex];
  }
  return nil;
}

-(UIColor *)colourForIndex:(NSUInteger)index {
  switch (index) {
    case 0:
      return kPlayerBlue;
      break;
    case 1:
      return kPlayerRed;
      break;
    case 2:
      return kPlayerGreen;
      break;
    case 3:
      return kPlayerOrange;
      break;
    default:
      return nil;
      break;
  }
}

#pragma mark - undo manager

-(BOOL)addToHoldingContainer:(DataDyadmino *)dataDyad {
  
  NSUInteger originalCount = [(NSArray *)self.holdingIndexContainer count];
  
  NSNumber *number = [NSNumber numberWithUnsignedInteger:[dataDyad returnMyID]];
  if (![self holdingsContainsDataDyadmino:dataDyad]) {
    NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.holdingIndexContainer];
    [tempArray addObject:number];
    self.holdingIndexContainer = [NSArray arrayWithArray:tempArray];
  }
  
  return ([(NSArray *)self.holdingIndexContainer count] == originalCount + 1);
}

-(DataDyadmino *)undoDyadminoToHoldingContainer {
  NSArray *holdingIndexContainer = self.holdingIndexContainer;
  if (holdingIndexContainer.count > 0) {
    
    NSNumber *number = [self.holdingIndexContainer lastObject];
    NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.holdingIndexContainer];
    [tempArray removeObject:number];
    self.holdingIndexContainer = [NSArray arrayWithArray:tempArray];
    DataDyadmino *lastDataDyadmino = [self dataDyadminoForIndex:[number unsignedIntegerValue]];
    return lastDataDyadmino;
  }
  return nil;
}

-(void)resetHoldingContainer {
  self.holdingIndexContainer = nil;
}

-(BOOL)addToArrayOfChordsAndPointsTheseChordSonorities:(NSSet *)chordSonorities
                               extendedChordSonorities:(NSSet *)extendedChordSonorities
                                        fromDyadminoID:(NSInteger)dyadminoID { // -1 if from board dyadmino

  BOOL extendingDyadmino = NO;
  
  NSUInteger originalCount = [(NSArray *)self.arrayOfChordsAndPoints count];
  
  NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.arrayOfChordsAndPoints];
  
  NSSet *previousChordSonorities;
    // this checks if we now have an extending seventh replacing a previously played triad
  for (NSDictionary *previousDictionary in self.arrayOfChordsAndPoints) {
    if (dyadminoID != -1 && [previousDictionary[@"dyadmino"] isEqualToNumber:@(dyadminoID)]) {
      previousChordSonorities = previousDictionary[@"chordSonorities"];
      [tempArray removeObject:previousDictionary];
      extendingDyadmino = YES;
    }
  }
  
    // this ensures that extending seventh counts as a new chord, now that original triad has been removed
  if (previousChordSonorities) {
    NSMutableSet *tempNewExtendedChordSonorities = [NSMutableSet setWithSet:extendedChordSonorities];
    for (NSSet *previousSonority in previousChordSonorities) {
      for (NSSet *extendedSonority in extendedChordSonorities) {
        if ([self.delegate sonority:previousSonority IsSubsetOfSonority:extendedSonority]) {
          [tempNewExtendedChordSonorities removeObject:extendedSonority];
        }
      }
    }
    extendedChordSonorities = [NSSet setWithSet:tempNewExtendedChordSonorities];
  }

  
  NSUInteger points = [self pointsForChordSonorities:chordSonorities extendedChordSonorities:extendedChordSonorities];
  
  NSDictionary *thisDictionary = @{@"chordSonorities":chordSonorities, @"points":@(points), @"dyadmino":@(dyadminoID)};
  [tempArray addObject:thisDictionary];
  self.arrayOfChordsAndPoints = [NSArray arrayWithArray:tempArray];
  
    // count should not change if extending dyadmino, otherwise it should add one
  NSUInteger addedComparisonValue = extendingDyadmino ? 0 : 1;
  return ([(NSArray *)self.arrayOfChordsAndPoints count] == originalCount + addedComparisonValue);
}

-(BOOL)undoFromArrayOfChordsAndPointsThisDyadminoID:(NSInteger)dyadminoID {
  
  NSUInteger originalCount = [(NSArray *)self.arrayOfChordsAndPoints count];
  
  NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.arrayOfChordsAndPoints];

  for (NSDictionary *chordDictionary in self.arrayOfChordsAndPoints) {
    if ([chordDictionary[@"dyadmino"] isEqualToNumber:@(dyadminoID)]) {
      [tempArray removeObject:chordDictionary];
    }
  }

  self.arrayOfChordsAndPoints = [NSArray arrayWithArray:tempArray];

  return ([(NSArray *)self.arrayOfChordsAndPoints count] == originalCount - 1);
}

-(void)resetArrayOfChordsAndPoints {
  self.arrayOfChordsAndPoints = nil;
}

#pragma mark - replay methods

-(void)startReplay {
  NSArray *turns = self.turns;
  self.replayTurn = [NSNumber numberWithUnsignedInteger:turns.count];
  self.replayBoard = [NSMutableSet setWithSet:self.board];
}

-(void)leaveReplay {
  NSArray *turns = self.turns;
  self.replayTurn = [NSNumber numberWithUnsignedInteger:turns.count];
  self.replayBoard = nil;
}

-(void)first {
  if ([self returnReplayTurn] == 0) { // in case the replay is before any turn made
    return;
  }
  
  self.replayTurn = [NSNumber numberWithUnsignedInteger:1];
  [self.replayBoard removeAllObjects];
  [self.replayBoard addObject:[self dataDyadminoForIndex:[self returnFirstDataDyadIndex]]];
  NSArray *holdingContainer = [self.turns[[self returnReplayTurn] - 1] objectForKey:kTurnDyadminoes];
  for (DataDyadmino *dataDyad in [self dataDyadsInIndexContainer:holdingContainer]) {
    if (![self.replayBoard containsObject:dataDyad]) {
      [self.replayBoard addObject:dataDyad];
    }
  }
}

-(BOOL)previous {

  if ([self returnReplayTurn] <= 1) {
    return NO;
    
  } else {
      NSArray *holdingContainer = [self.turns[[self returnReplayTurn] - 1] objectForKey:kTurnDyadminoes];
      for (DataDyadmino *dataDyad in [self dataDyadsInIndexContainer:holdingContainer]) {
        if ([self.replayBoard containsObject:dataDyad]) {
          [self.replayBoard removeObject:dataDyad];
        }
      }
    self.replayTurn = [NSNumber numberWithUnsignedInteger:[self returnReplayTurn] - 1];
    return YES;
  }
}

-(BOOL)next {
  NSArray *turns = self.turns;
  if ([self returnReplayTurn] >= turns.count) {
    return NO;
    
  } else {
      self.replayTurn = [NSNumber numberWithUnsignedInteger:[self returnReplayTurn] + 1];
      NSArray *holdingContainer = [self.turns[[self returnReplayTurn] - 1] objectForKey:kTurnDyadminoes];
      for (DataDyadmino *dataDyad in [self dataDyadsInIndexContainer:holdingContainer]) {
        if (![self.replayBoard containsObject:dataDyad]) {
          [self.replayBoard addObject:dataDyad];
        }
      }
    return YES;
  }
}

-(void)last {
  NSArray *turns = self.turns;
  self.replayTurn = [NSNumber numberWithUnsignedInteger:turns.count];
  for (int i = 0; i < turns.count; i++) {
    NSArray *holdingContainer = [self.turns[i] objectForKey:kTurnDyadminoes];
    for (DataDyadmino *dataDyad in [self dataDyadsInIndexContainer:holdingContainer]) {
      if (![self.replayBoard containsObject:dataDyad]) {
        [self.replayBoard addObject:dataDyad];
      }
    }
  }
}

#pragma mark - custom accessor methods

-(NSMutableSet *)replayBoard {
  if (!_replayBoard) {
    _replayBoard = [NSMutableSet new];
  }
  return _replayBoard;
}

-(void)setReplayBoard:(NSMutableSet *)replayBoard {
  _replayBoard = replayBoard;
}

-(id<MatchDelegate>)delegate {
  return _delegate;
}

-(void)setDelegate:(id<MatchDelegate>)delegate {
  _delegate = delegate;
}

-(NSArray *)pile {
  if (!_pile) {
    _pile = [NSMutableArray new];
    for (DataDyadmino *dataDyad in self.dataDyadminoes) {
      if ([dataDyad returnPlaceStatus] == kInPile) {
        [_pile addObject:dataDyad];
      }
    }
  }
  return _pile;
}

-(void)setPile:(NSMutableArray *)pile {
  _pile = pile;
}

-(NSSet *)board {
  if (!_board) {
    _board = [NSMutableSet new];
    for (DataDyadmino *dataDyad in self.dataDyadminoes) {
      if ([dataDyad returnPlaceStatus] == kOnBoard) {
        [_board addObject:dataDyad];
      }
    }
  }
  return _board;
}

-(void)setBoard:(NSMutableSet *)board {
  _board = board;
}

#pragma mark - helper methods

-(NSUInteger)wonPlayersCount {
  NSUInteger counter = 0;
  for (Player *player in self.players) {
    if ([player returnWon]) {
      counter++;
    }
  }
  return counter;
}

-(Player *)playerForIndex:(NSUInteger)index {
  for (Player *player in self.players) {
    if ([player returnPlayerOrder] == index) {
      return player;
    }
  }
  return nil;
}

-(Player *)returnCurrentPlayer {
  return [self playerForIndex:[self returnCurrentPlayerIndex]];
}

-(DataDyadmino *)dataDyadminoForIndex:(NSUInteger)index {
  for (DataDyadmino *dataDyadmino in self.dataDyadminoes) {
    if ([dataDyadmino returnMyID] == index) {
      return dataDyadmino;
    }
  }
  return nil;
}

#pragma mark - array of chords and points helper methods

-(NSSet *)totalChordSonoritiesThisTurn {

  NSMutableSet *tempTotalChordSonorities = [NSMutableSet new];
  
  for (int i = 0; i < [(NSArray *)self.arrayOfChordsAndPoints count]; i++) {
    NSDictionary *chordDictionary = self.arrayOfChordsAndPoints[i];
    NSSet *chordSonorities = chordDictionary[@"chordSonorities"];
    for (NSSet *chordSonority in chordSonorities) {
      [tempTotalChordSonorities addObject:chordSonority];
    }
  }
  
  NSLog(@"total chord sonorities this turn is %@", tempTotalChordSonorities);
  return [NSSet setWithSet:tempTotalChordSonorities];
}

-(NSUInteger)sumOfPointsThisTurn {
  
  NSUInteger sumPoints = 0;
  
  for (int i = 0; i < [(NSArray *)self.arrayOfChordsAndPoints count]; i++) {
    NSDictionary *chordDictionary = self.arrayOfChordsAndPoints[i];
    NSNumber *chordPointsNumber = chordDictionary[@"points"];
    sumPoints += [chordPointsNumber unsignedIntegerValue];
  }
  
  return sumPoints;
}

-(NSUInteger)pointsForChordSonorities:(NSSet *)chordSonorities extendedChordSonorities:(NSSet *)extendedChordSonorities {
  
  NSUInteger points = 0;
  for (NSSet *chordSonority in chordSonorities) {
    
    BOOL extended = [extendedChordSonorities containsObject:chordSonority];
    
    NSLog(@"chord sonority %@, extendedchordSonorities %@, extended %i", chordSonority, extendedChordSonorities, extended);

    points += [self pointsForChordSonority:chordSonority extended:extended];
  }
  
  return points;
}

-(NSUInteger)pointsForChordSonority:(NSSet *)chordSonority extended:(BOOL)extended {
  NSUInteger points;
  
    // triad
  if (chordSonority.count == 3) {
    points = kPointsTriad;
    
      // seventh chord
  } else {
    
    points = extended ? kPointsExtendedSeventh : kPointsSeventh;
  }
  return points;
}

#pragma mark = holding container helper methods

-(BOOL)holdingsContainsDataDyadmino:(DataDyadmino *)dataDyad {
  return [self.holdingIndexContainer containsObject:[NSNumber numberWithUnsignedInteger:[dataDyad returnMyID]]];
}

-(NSArray *)dataDyadsInIndexContainer:(NSArray *)holdingContainer {
  
  NSMutableArray *tempArray = [NSMutableArray new];
  for (NSNumber *number in holdingContainer) {
    DataDyadmino *dataDyad = [self dataDyadminoForIndex:[number unsignedIntegerValue]];
    [tempArray addObject:dataDyad];
  }
  return [NSArray arrayWithArray:tempArray];
}

#pragma mark - swap container helper methods

-(BOOL)swapContainerContainsDataDyadmino:(DataDyadmino *)dataDyad {
  return [self.swapIndexContainer containsObject:[NSNumber numberWithUnsignedInteger:[dataDyad returnMyID]]];
}

-(void)addToSwapDataDyadmino:(DataDyadmino *)dataDyad {
  NSMutableSet *tempSet = [NSMutableSet setWithSet:self.swapIndexContainer];
  [tempSet addObject:[NSNumber numberWithUnsignedInteger:[dataDyad returnMyID]]];
  self.swapIndexContainer = [NSSet setWithSet:tempSet];
}

-(void)removeFromSwapDataDyadmino:(DataDyadmino *)dataDyad {
  NSMutableSet *tempSet = [NSMutableSet setWithSet:self.swapIndexContainer];
  [tempSet removeObject:[NSNumber numberWithUnsignedInteger:[dataDyad returnMyID]]];
  self.swapIndexContainer = [NSSet setWithSet:tempSet];
}

-(void)removeAllSwaps {
  self.swapIndexContainer = nil;
  self.swapIndexContainer = [NSMutableSet new];
}

#pragma mark - turns methods

-(void)addTurn:(NSDictionary *)turn {
  NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.turns];
  [tempArray addObject:turn];
  self.turns = [NSArray arrayWithArray:tempArray];
}

#pragma mark - query number methods

-(GameRules)returnRules {
  return (GameRules)[self.rules unsignedIntegerValue];
}

-(GameSkill)returnSkill {
  return (GameSkill)[self.skill unsignedIntegerValue];
}

-(GameType)returnType {
  return (GameType)[self.type unsignedIntegerValue];
}

-(NSUInteger)returnCurrentPlayerIndex {
  return [self.currentPlayerIndex unsignedIntegerValue];
}

-(BOOL)returnGameHasEnded {
  return [self.gameHasEnded boolValue];
}

-(NSUInteger)returnFirstDataDyadIndex {
  return [self.firstDataDyadIndex unsignedIntegerValue];
}

-(NSUInteger)returnReplayTurn {
  return [self.replayTurn unsignedIntegerValue];
}

-(NSInteger)returnRandomNumber1To24 {
  return [self.randomNumber1To24 integerValue];
}

@end

@implementation Turns

+(Class)transformedValueClass {
  return [NSArray class];
}

+(BOOL)allowsReverseTransformation {
  return YES;
}

-(id)transformedValue:(id)value {
  return [NSKeyedArchiver archivedDataWithRootObject:value];
}

-(id)reverseTransformedValue:(id)value {
  return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}

@end

@implementation HoldingIndexContainer

+(Class)transformedValueClass {
  return [NSArray class];
}

+(BOOL)allowsReverseTransformation {
  return YES;
}

-(id)transformedValue:(id)value {
  return [NSKeyedArchiver archivedDataWithRootObject:value];
}

-(id)reverseTransformedValue:(id)value {
  return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}

@end

@implementation SwapIndexContainer

+(Class)transformedValueClass {
  return [NSSet class];
}

+(BOOL)allowsReverseTransformation {
  return YES;
}

-(id)transformedValue:(id)value {
  return [NSKeyedArchiver archivedDataWithRootObject:value];
}

-(id)reverseTransformedValue:(id)value {
  return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}

@end

@implementation ArrayOfChordsAndPoints

+(Class)transformedValueClass {
  return [NSArray class];
}

+(BOOL)allowsReverseTransformation {
  return YES;
}

-(id)transformedValue:(id)value {
  return [NSKeyedArchiver archivedDataWithRootObject:value];
}

-(id)reverseTransformedValue:(id)value {
  return [NSKeyedUnarchiver unarchiveObjectWithData:value];
}

@end