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
@dynamic tempScore;
@dynamic holdingIndexContainer;
@dynamic swapIndexContainer;
@dynamic replayTurn;
@dynamic turns;
@dynamic numberOfConsecutivePasses;
@dynamic firstDataDyadIndex;
@dynamic randomNumber1To24;

  // not persisted
@synthesize replayBoard = _replayBoard;
@synthesize delegate = _delegate;
@synthesize pile = _pile;
@synthesize board = _board;

#pragma mark - archiver methods

//-(id)initWithCoder:(NSCoder *)aDecoder {
//  self = [super init];
//  if (self) {
//    self.rules = [[aDecoder decodeObjectForKey:@"rules"] unsignedIntValue];
//    self.skill = [[aDecoder decodeObjectForKey:@"skill"] unsignedIntValue];
//    self.type = [[aDecoder decodeObjectForKey:@"type"] unsignedIntValue];
//
//    self.lastPlayed = [aDecoder decodeObjectForKey:@"lastPlayed"];
//    
//    self.players = [aDecoder decodeObjectForKey:@"players"];
//    
//    for (Player *player in self.players) {
//      player.delegate = self;
//    }
//    
//    self.currentPlayer = [aDecoder decodeObjectForKey:@"currentPlayer"];
//    self.wonPlayers = [aDecoder decodeObjectForKey:@"wonPlayers"];
//    self.gameHasEnded = [aDecoder decodeBoolForKey:@"gameHasEnded"];
//    
//    self.pile = [aDecoder decodeObjectForKey:@"pile"];
//    self.board = [aDecoder decodeObjectForKey:@"board"];
//    
//    self.tempScore = [[aDecoder decodeObjectForKey:@"tempScore"] unsignedIntegerValue];
//    self.holdingContainer = [aDecoder decodeObjectForKey:@"holdingContainer"];
//    self.swapContainer = [aDecoder decodeObjectForKey:@"swapContainer"];
//    self.replayTurn = [[aDecoder decodeObjectForKey:@"replayCounter"] unsignedIntegerValue];
//    self.turns = [aDecoder decodeObjectForKey:@"turns"];
//    
//    self.numberOfConsecutivePasses = [[aDecoder decodeObjectForKey:@"consecutivePasses"] unsignedIntegerValue];
//    self.firstDyadmino = [aDecoder decodeObjectForKey:@"firstDyadmino"];
//    
//    self.randomNumber1To24 = [aDecoder decodeIntegerForKey:@"randomNumber1To24"];
//  }
//  return self;
//}

//-(void)encodeWithCoder:(NSCoder *)aCoder {
//  [aCoder encodeObject:[NSNumber numberWithUnsignedInt:self.rules] forKey:@"rules"];
//  [aCoder encodeObject:[NSNumber numberWithUnsignedInt:self.skill] forKey:@"skill"];
//  [aCoder encodeObject:[NSNumber numberWithUnsignedInt:self.type] forKey:@"type"];
//
//  [aCoder encodeObject:self.lastPlayed forKey:@"lastPlayed"];
//  
//  [aCoder encodeObject:self.players forKey:@"players"];
//  [aCoder encodeObject:self.currentPlayer forKey:@"currentPlayer"];
//  [aCoder encodeObject:self.wonPlayers forKey:@"wonPlayers"];
//  [aCoder encodeBool:self.gameHasEnded forKey:@"gameHasEnded"];
//  
//  [aCoder encodeObject:self.pile forKey:@"pile"];
//  [aCoder encodeObject:self.board forKey:@"board"];
//  
//  [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.tempScore] forKey:@"tempScore"];
//  [aCoder encodeObject:self.holdingContainer forKey:@"holdingContainer"];
//  [aCoder encodeObject:self.swapContainer forKey:@"swapContainer"];
//  [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.replayTurn] forKey:@"replayCounter"];
//  [aCoder encodeObject:self.turns forKey:@"turns"];
//  
//  [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.numberOfConsecutivePasses] forKey:@"consecutivePasses"];
//  [aCoder encodeObject:self.firstDyadmino forKey:@"firstDyadmino"];
//  
//  [aCoder encodeInteger:self.randomNumber1To24 forKey:@"randomNumber1To24"];
//}

#pragma mark - init methods

-(void)initialPlayers:(NSSet *)players andRules:(GameRules)rules andSkill:(GameSkill)skill withContext:(NSManagedObjectContext *)managedObjectContext {
//  self = [super init];
//  if (self) {
  [self setPlayers:players];
  self.rules = [NSNumber numberWithUnsignedInteger:rules];
  self.skill = [NSNumber numberWithUnsignedInteger:skill];
  self.type = (players.count == 1) ? [NSNumber numberWithUnsignedInteger:kSelfGame] : [NSNumber numberWithUnsignedInteger:kPnPGame];
  
  self.lastPlayed = [NSDate date];
  self.gameHasEnded = [NSNumber numberWithBool:NO];
  self.numberOfConsecutivePasses = [NSNumber numberWithUnsignedInteger:0];
  
  self.currentPlayerIndex = [NSNumber numberWithUnsignedInteger:0];
  
  self.randomNumber1To24 = [NSNumber numberWithUnsignedInteger:[self randomIntegerUpTo:24] + 1];
  
//  for (NSUInteger i = 0; i < players.count; i++) {
//    Player *player = players[i];
//    player.playerOrder = [NSNumber numberWithUnsignedInteger:i];
//    player.delegate = self;
//  }
  
  self.holdingIndexContainer = [NSMutableArray new];
  self.swapIndexContainer = [NSMutableSet new];
  
//  self.pile = [[NSMutableArray alloc] initWithCapacity:kPileCount];
//  self.board = [[NSMutableSet alloc] initWithCapacity:kPileCount];
  self.turns = [NSMutableArray new];
  self.replayTurn = [NSNumber numberWithUnsignedInteger:0];
  
  [self generateDataDyadminoesWithContext:managedObjectContext];
  [self placeFirstDyadminoOnBoard];
  [self distributePileAmongstPlayers];
//  }
//  return self;
}

-(void)generateDataDyadminoesWithContext:(NSManagedObjectContext *)context {
  NSMutableSet *tempSet = [NSMutableSet new];
  
    // start index at 0 (previously started at 1)
  for (NSUInteger i = 0; i < kPileCount; i++) {
    
//    DataDyadmino *dataDyad = [DataDyadmino new];
    DataDyadmino *dataDyad = [NSEntityDescription insertNewObjectForEntityForName:@"DataDyadmino" inManagedObjectContext:context];

    [dataDyad initialID:i];
//    DataDyadmino *dataDyad = [[DataDyadmino alloc] initialID:i];
//    [self.pile addObject:dataDyad];
    [tempSet addObject:dataDyad];
  }
  [self setDataDyadminoes:[NSSet setWithSet:tempSet]];
}

-(void)distributePileAmongstPlayers {
  for (Player *player in self.players) {
    [self fillRackFromPileForPlayer:player];
    
      // this won't be here in real game, should keep player's desired order
//    [self sortDyadminoes:player.dataDyadminoesThisTurn];
  }
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
      [self.pile removeObjectAtIndex:randIndex];
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
  }
}

-(Player *)switchToNextPlayer {
  
//  NSUInteger index = [self.players indexOfObject:self.currentPlayer];
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

-(void)swapDyadminoesFromCurrentPlayer {
  Player *player = [self playerForIndex:[self returnCurrentPlayerIndex]];
  
  for (NSNumber *number in self.swapIndexContainer) {
    DataDyadmino *dataDyad = [self dataDyadminoForIndex:[number unsignedIntegerValue]];
    dataDyad.placeStatus = [NSNumber numberWithUnsignedInteger:kInPile];
    [player removeFromThisTurnsDataDyadmino:dataDyad];
    
    [self.pile addObject:dataDyad];
  }
//  [self.pile addObjectsFromArray:self.swapContainer];
//  [self.pile addObjectsFromArray:[self.swapContainer allObjects]];
  
  [self fillRackFromPileForPlayer:player];
  
//  [self.swapContainer removeAllObjects];
  [self removeAllSwaps];
  
  [self resetHoldingContainer];
  [self recordDyadminoesFromPlayer:player withSwap:YES]; // this records turn as a pass
    // sort the board and pile
  [self sortBoardAndPileArrays];
}

-(void)recordDyadminoesFromPlayer:(Player *)player withSwap:(BOOL)swap {

    // a pass has an empty holding container, while a resign has *no* holding container
  NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInteger:[self returnCurrentPlayerIndex]], @"player",
                              self.holdingIndexContainer, @"container", nil];
  
  [self addTurn:dictionary];
  NSArray *turns = self.turns;
  self.replayTurn = [NSNumber numberWithUnsignedInteger:turns.count];
  
    // player passes
  NSArray *holdingIndexContainer = self.holdingIndexContainer;
  if (holdingIndexContainer.count == 0) {
    
      // if solo game, ends right away
      // FIXME: this will need to be changed to accommodate when board dyadmino
      // is moved to create a chord and nothing else, which counts as a turn and
      // not a pass
    if ([self returnType] == kSelfGame && !swap) {
      [self endGame];
      return;
    }
    
    self.numberOfConsecutivePasses = [NSNumber numberWithUnsignedInteger:[self returnNumberOfConsecutivePasses] + 1];
    
      // enough players passed to end game
      // 1. two rotations if there are dyadminoes left in pile
      // 2. one rotation if no dyadminoes are left in pile
    if ([self returnType] != kSelfGame && ((self.pile.count > 0 && [self returnNumberOfConsecutivePasses] >= self.players.count * 2) ||
        (self.pile.count == 0 && [self returnNumberOfConsecutivePasses] >= self.players.count))) {
      [self endGame];
      return;
    }
    
      // player submitted dyadminoes
  } else {
    
      // reset number of consecutive passes
    self.numberOfConsecutivePasses = [NSNumber numberWithUnsignedInteger:0];
      /// obviously scorekeeping will be more sophisticated
      /// and will consider chords formed
    NSUInteger newScore = [player returnPlayerScore] + [self returnTempScore];
    player.playerScore = [NSNumber numberWithUnsignedInteger:newScore];
    
    for (DataDyadmino *dataDyad in [self dataDyadsInIndexContainer:self.holdingIndexContainer]) {
      if ([player.dataDyadminoIndexesThisTurn containsObject:dataDyad]) {
        dataDyad.placeStatus = [NSNumber numberWithUnsignedInteger:kOnBoard];
        [player removeFromThisTurnsDataDyadmino:dataDyad];
        [self.board addObject:dataDyad];
      }
    }
    
//    [self.board addObjectsFromArray:dataDyadsInHoldingContainer];
    
      // reset rack order
    NSArray *dataDyadminoIndexesThisTurn = player.dataDyadminoIndexesThisTurn;
    for (NSInteger i = 0; i < dataDyadminoIndexesThisTurn.count; i++) {
      DataDyadmino *dataDyad = player.dataDyadminoIndexesThisTurn[i];
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
    [self sortBoardAndPileArrays];
  }
  
      // whether pass or not, game continues
  [self resetHoldingContainer];
  self.lastPlayed = [NSDate date];
  [self switchToNextPlayer];
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
      NSNumber *thisTurn = [NSNumber numberWithUnsignedInteger:(turns.count > 0 ? turns.count : 1)]; // for first dyadmino
      [newDictionary setObject:thisTurn forKey:@"turn"];
      NSLog(@"new dictionary created for turn %lu", (unsigned long)turns.count);
      
        // set object for changed hexCoord position
      if (!(lastHexX || lastHexY) || !(dataDyad.myHexCoord.x == [lastHexX integerValue] && dataDyad.myHexCoord.y == [lastHexY integerValue])) {
        NSLog(@"hexCoord for dataDyad %lu changed, persist!", (unsigned long)[dataDyad returnMyID]);
        NSNumber *newHexX = [NSNumber numberWithInteger:dataDyad.myHexCoord.x];
        NSNumber *newHexY = [NSNumber numberWithInteger:dataDyad.myHexCoord.y];
        [newDictionary setObject:newHexX forKey:@"hexX"];
        [newDictionary setObject:newHexY forKey:@"hexY"];
      }
      
        // set object for changed orientation
      if (!lastOrientation || [dataDyad returnMyOrientation] != [lastOrientation unsignedIntegerValue]) {
        NSLog(@"orientation for dataDyad %lu changed, persist!", (unsigned long)[dataDyad returnMyID]);
        NSNumber *newOrientation = [NSNumber numberWithUnsignedInteger:[dataDyad returnMyOrientation]];
        [newDictionary setObject:newOrientation forKey:@"orientation"];
      }
      
      NSMutableArray *mutableTurnChanges = [NSMutableArray arrayWithArray:dataDyad.turnChanges];
      [mutableTurnChanges addObject:[NSDictionary dictionaryWithDictionary:newDictionary]];
      dataDyad.turnChanges = [NSArray arrayWithArray:mutableTurnChanges];
      
        // for testing purposes
      for (NSDictionary *dictionary in dataDyad.turnChanges) {
        NSUInteger turn = [(NSNumber *)[dictionary objectForKey:@"turn"] unsignedIntegerValue];
        NSInteger hexX = [(NSNumber *)[dictionary objectForKey:@"hexX"] integerValue];
        NSInteger hexY = [(NSNumber *)[dictionary objectForKey:@"hexY"] integerValue];
        DyadminoOrientation orientation = [(NSNumber *)[dictionary objectForKey:@"orientation"] unsignedIntValue];
        NSLog(@"dataDyad %lu for turn %lu has position %li, %li and orientation %i", (unsigned long)[dataDyad returnMyID], (unsigned long)turn, (long)hexX, (long)hexY, orientation);
      }
    }
  }
}

-(void)resignPlayer:(Player *)player {
  
    // a resign has *no* holding container
  if (self.type != kSelfGame) {
    
    NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:[self returnCurrentPlayerIndex]], @"player", nil];
    
    [self addTurn:dictionary];
    NSArray *turns = self.turns;
    self.replayTurn = [NSNumber numberWithUnsignedInteger:turns.count];
  }

  player.resigned = [NSNumber numberWithBool:YES];
  for (DataDyadmino *dataDyad in player.dataDyadminoIndexesThisTurn) {
    dataDyad.placeStatus = [NSNumber numberWithUnsignedInteger:kInPile];
  }
  
  [self.pile addObjectsFromArray:player.dataDyadminoIndexesThisTurn];
  [self sortBoardAndPileArrays];
  
  [self resetHoldingContainer];
  [player removeAllDataDyadminoesThisTurn];
  if (![self switchToNextPlayer]) {
    [self endGame];
  }
  
  self.lastPlayed = [NSDate date];
}

-(void)endGame {
  self.currentPlayerIndex = [NSNumber numberWithUnsignedInteger:0];
  [self resetHoldingContainer];
  
    // if solo game, sole player is winner if any score at all
  if ([self returnType] == kSelfGame) {
    Player *soloPlayer = [self playerForIndex:0];
    soloPlayer.won = ([soloPlayer returnPlayerScore] > 0) ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO]; // player only won if score greater than 0
//    self.wonPlayers = (soloPlayer.playerScore > 0) ?
//      [NSArray arrayWithArray:self.players] :
//      @[];
    
  } else {
      // rules out that players with no points can win
    NSUInteger maxScore = 1;
//    NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:self.players.count];
    
    for (Player *player in self.players) {
      if (![player returnResigned]) {
        
        NSUInteger playerScore = [player returnPlayerScore];
        if (playerScore > maxScore) {
//          [tempArray removeAllObjects];
//          [tempArray addObject:player];
          maxScore = playerScore;
          
//        } else if (player.playerScore == maxScore) {
//          [tempArray addObject:player];
        }
      }
    }
    
    for (Player *player in self.players) {
      if ([player returnPlayerScore] == maxScore) {
        player.won = [NSNumber numberWithBool:YES];
      }
    }
//    self.wonPlayers = [NSArray arrayWithArray:tempArray];
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

-(void)sortBoardAndPileArrays {
    // this will have to change when dyadminoes
  [self sortDyadminoes:self.pile];
//  [self sortDyadminoes:self.board];
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
  Player *turnPlayer = [self playerForIndex:[[self.turns[[self returnReplayTurn] - 1] objectForKey:@"player"] unsignedIntegerValue]];
  NSArray *dyadminoesPlayed;
  if (![self.turns[[self returnReplayTurn] - 1] objectForKey:@"container"]) {
    
  } else {
    dyadminoesPlayed = [self.turns[[self returnReplayTurn] - 1] objectForKey:@"container"];
  }
  
  NSString *dyadminoesPlayedString;
  if (dyadminoesPlayed.count > 0) {
    NSString *componentsString = [[dyadminoesPlayed valueForKey:kDyadminoIDKey] componentsJoinedByString:@", "];
    dyadminoesPlayedString = [NSString stringWithFormat:@"played %@", componentsString];
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

  // FIXME: obviously
-(NSString *)keySigString {
    // yields number between 0 and 11
//  NSUInteger keySig = (self.randomNumber1To24 - 1) / 2;
  
//  NSString *majorOrMinor = (self.randomNumber1To24 % 2 == 0) ? @"Major" : @"minor";
  
    // sharps are 0-5, flats are 6-11
//  MusicSymbol symbol = (keySig < 6) ? kSymbolSharp : kSymbolFlat;
  
  return nil;
}

-(UIColor *)colourForPlayer:(Player *)player {
  if ([self.players containsObject:player]) {
    
    NSUInteger playerIndex = [player returnPlayerOrder];
    
      // originally
    NSUInteger randomIndex = (playerIndex + [self returnRandomNumber1To24]) % 4;
    return [self colourForIndex:randomIndex];
    
    /*
      // this method truly randomises the colours, but it's slower
      // and also too random to be aesthetically pleasing, I think
     
      // first pool starts out between 0 and 23
    NSUInteger firstPool = self.randomNumber1To24 - 1;
    NSUInteger firstRange = firstPool / 6; // will yield integer between 0 and 3
    
    NSUInteger secondPool = firstPool % 6; // second pool is between 0 and 5
    NSUInteger secondRange = secondPool / 2; // will yield integer between 0 and 2
    
    NSUInteger thirdPool = secondPool % 2; // third pool is between 0 and 1
    NSUInteger thirdRange = thirdPool; // will yield integer between 0 and 1, etc
    
    NSUInteger fourthRange = 0;
    
    NSUInteger ranges[4] = {firstRange, secondRange, thirdRange, fourthRange};

    UIColor *myColour;
    NSMutableArray *colours = [NSMutableArray arrayWithArray:@[kPlayerBlue, kPlayerRed, kPlayerGreen, kPlayerOrange]];
    
    for (int i = 0; i < playerIndex + 1; i++) {
      UIColor *colour = [colours objectAtIndex:ranges[i]];
      [colours removeObjectAtIndex:ranges[i]];
      if (i == playerIndex) {
        myColour = colour;
      }
    }
    return myColour;
    */
    
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

-(void)addToHoldingContainer:(DataDyadmino *)dataDyad {
  
    // modify scorekeeping methods, of course
    // especially since this will be used to call swap as well
  self.tempScore = [NSNumber numberWithUnsignedInteger:[self returnTempScore] + 1];
  
//  if (![self.holdingContainer containsObject:dataDyad]) {
//    NSMutableArray *tempContainer = [NSMutableArray arrayWithArray:self.holdingContainer];
//    [tempContainer addObject:dataDyad];
//    self.holdingContainer = [NSArray arrayWithArray:tempContainer];
//  }
  
  NSNumber *number = [NSNumber numberWithUnsignedInteger:[dataDyad returnMyID]];
  if (![self holdingsContainsDataDyadmino:dataDyad]) {
    NSMutableArray *tempArray = [NSMutableArray arrayWithArray:self.holdingIndexContainer];
    [tempArray addObject:number];
    self.holdingIndexContainer = [NSArray arrayWithArray:tempArray];
  }
}

//-(void)setHoldingContainer:(NSArray *)newHoldingContainer {
//  if (!_holdingContainer || !newHoldingContainer) {
//    _holdingContainer = newHoldingContainer;
//  } else if (_holdingContainer != newHoldingContainer) {
//    _holdingContainer = newHoldingContainer;
//  }
//}

-(DataDyadmino *)undoDyadminoToHoldingContainer {
  NSArray *holdingIndexContainer = self.holdingIndexContainer;
  if (holdingIndexContainer.count > 0) {
    
      // FIXME: this should be changed
    self.tempScore = [NSNumber numberWithUnsignedInteger:[self returnTempScore] - 1];
    
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
  self.holdingIndexContainer = [NSMutableArray new];
  self.tempScore = [NSNumber numberWithUnsignedInteger:0];
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
  NSArray *holdingContainer = [self.turns[[self returnReplayTurn] - 1] objectForKey:@"container"];
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
      NSArray *holdingContainer = [self.turns[[self returnReplayTurn] - 1] objectForKey:@"container"];
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
      NSArray *holdingContainer = [self.turns[[self returnReplayTurn] - 1] objectForKey:@"container"];
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
    NSArray *holdingContainer = [self.turns[i] objectForKey:@"container"];
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

#pragma mark = holding container helper methods

-(BOOL)holdingsContainsDataDyadmino:(DataDyadmino *)dataDyad {
  return [self.holdingIndexContainer containsObject:[NSNumber numberWithUnsignedInteger:[dataDyad returnMyID]]];
}

-(NSArray *)dataDyadsInIndexContainer:(NSArray *)holdingContainer {
  NSMutableArray *tempArray = [NSMutableArray new];
  NSLog(@"data dyads in container %@", holdingContainer);
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

-(NSUInteger)returnTempScore {
  return [self.tempScore unsignedIntegerValue];
}

-(NSUInteger)returnReplayTurn {
  return [self.replayTurn unsignedIntegerValue];
}

-(NSUInteger)returnNumberOfConsecutivePasses {
  return [self.numberOfConsecutivePasses unsignedIntegerValue];
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
