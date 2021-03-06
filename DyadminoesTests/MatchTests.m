//
//  MatchTests.m
//  Dyadminoes
//
//  Created by Bennett Lin on 12/2/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "TestHelper.h"
#import "Match+Helper.h"
#import "Player.h"
#import "DataDyadmino.h"
#import "DataCell.h"

@interface MatchTests : XCTestCase

@property (strong, nonatomic) NSManagedObjectContext *myContext;
@property (strong, nonatomic) Match *myMatch;
@property (strong, nonatomic) NSArray *playerNames;
@property (strong, nonatomic) NSMutableSet *swapContainer;

@end

@implementation MatchTests

-(void)setUp {
  [super setUp];
  self.myContext = [TestHelper managedObjectContextForTests];
  self.playerNames = @[@"Bennett", @"Lauren", @"Julia", @"Pamela"];
}

-(void)tearDown {
  self.myContext = nil;
  [super tearDown];
}

#pragma mark - initial setup tests

-(void)testMatchIsProperTypeForNumberOfPlayers {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
    GameType expectedType = (i == 1) ? kSelfGame : kPnPGame;
    GameType returnedType = (GameType)[self.myMatch.type unsignedIntegerValue];
    
    XCTAssertTrue(returnedType == expectedType, @"Game type is incorrect for %i players", i);
  }
}

-(void)testMatchReturnsProperNumberOfPlayers {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
    XCTAssertTrue(self.myMatch.players.count == i, @"Game type has incorrect number of players for %i players", i);
  }
}

-(void)testMatchReturnsProperNamesAndOrdersOfPlayers {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
    for (int j = 1; j <= i; j++) {
      Player *player = [self.myMatch playerForIndex:j - 1];
      XCTAssertEqualObjects(player.name, self.playerNames[j - 1], @"Player name is wrong.");
      XCTAssertEqual([player.order unsignedIntegerValue], j - 1, @"Player order number is wrong.");
    }
  }
}

-(void)testCorrectCountOfPileDistribution {
  
    // test 1 to 4 players
  for (int i = 0; i < kMaxNumPlayers; i++) {
    NSUInteger numberOfPlayers = i + 1;
    [self setupGameForNumberOfPlayers:numberOfPlayers];

      // pile count is 66, minus 1 on board, and 6 in each player's rack
    NSUInteger expectedPileCount = kPileCount - (numberOfPlayers * kNumDyadminoesInRack) - 1;
    XCTAssertTrue(self.myMatch.pile.count == expectedPileCount, @"Pile count is not as expected for %lu players", (unsigned long)numberOfPlayers);
    XCTAssertTrue(self.myMatch.board.count == 1, @"There isn't one dyadmino on board for %lu players", (unsigned long)numberOfPlayers);
    
    for (int j = 0; j <= i; j++) {
      Player *player = [self.myMatch playerForIndex:j];
      NSArray *dataDyadminoIndexesThisTurn = (NSArray *)player.rackIndexes;
      NSUInteger numberOfDataDyadminoesThisTurn = dataDyadminoIndexesThisTurn.count;
      XCTAssertTrue(numberOfDataDyadminoesThisTurn == kNumDyadminoesInRack, @"There isn't six dyadminoes in player %i's hand for %lu players", j, (unsigned long)numberOfPlayers);
    }
  }
}

-(void)testAllDyadminoesArePresent {
  
    // test 1 to 4 players
  for (int i = 0; i < kMaxNumPlayers; i++) {
    
    NSMutableArray *allDyadminoes = [NSMutableArray new];
    
    NSUInteger numberOfPlayers = i + 1;
    [self setupGameForNumberOfPlayers:numberOfPlayers];
    
    BOOL allNumbersAreInPile = YES;
    
      // add dyadminoes from pile, board, and player racks to array
    for (DataDyadmino *dataDyad in self.myMatch.pile) {
      NSNumber *dataDyadNumber = dataDyad.myID;
      [allDyadminoes addObject:dataDyadNumber];
    }

    for (DataDyadmino *dataDyad in self.myMatch.board) {
      NSNumber *dataDyadNumber = dataDyad.myID;
      NSLog(@"board dyadmino is %@", dataDyadNumber);
      [allDyadminoes addObject:dataDyadNumber];
    }
    
    for (int j = 0; j <= i; j++) {
      Player *player = [self.myMatch playerForIndex:j];
      NSArray *dataDyadminoIndexesThisTurn = (NSArray *)player.rackIndexes;
      [allDyadminoes addObjectsFromArray:dataDyadminoIndexesThisTurn];
    }

    for (NSUInteger k = 0; k < allDyadminoes.count; k++) {
      NSNumber *dataDyadNumber = [NSNumber numberWithUnsignedInteger:k];
      if (![allDyadminoes containsObject:dataDyadNumber]) {
        allNumbersAreInPile = NO;
        NSLog(@"doesn't contain %@", dataDyadNumber);
      }
    }

    XCTAssertTrue(allNumbersAreInPile, @"Some numbers are missing in pile for %lu players", (unsigned long)numberOfPlayers);
  }
}

#pragma mark - pass tests

-(void)testPassesToNextPlayer {
  
    // test 2 to 4 players
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    NSInteger numberOfPlayers = self.myMatch.players.count;
    
      // test that passes to next player for each player
    for (int j = 1; j <= numberOfPlayers; j++) {
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnOrder];
      NSUInteger currentTurnCount = [(NSArray *)self.myMatch.turns count];
      
      [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      
      Player *nextPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger nextPlayerIndex = [nextPlayer returnOrder];
      NSUInteger nextTurnCount = [(NSArray *)self.myMatch.turns count];
      
        // next player will be current player for solo game
      BOOL switchesCorrectlyToNextPlayer = ((nextPlayerIndex - currentPlayerIndex + numberOfPlayers) % numberOfPlayers) == 1;
      
      XCTAssertTrue(switchesCorrectlyToNextPlayer, @"Does not switch to next player correctly after pass.");
      XCTAssertTrue(nextTurnCount == currentTurnCount + 1, @"Pass did not add turn.");
    }
  }
}

#pragma mark - swap tests

-(void)testSwapPassesToNextPlayer {
  
    // duplicates testPassesToNextPlayer, except with swap
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    NSInteger numberOfPlayers = self.myMatch.players.count;
    
      // test that passes to next player for any number of players
    for (int j = 1; j <= numberOfPlayers; j++) {
      self.swapContainer = [NSMutableSet new];
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnOrder];
      NSUInteger currentTurnCount = [(NSArray *)self.myMatch.turns count];
      
        // random data dyadmino
      NSUInteger randomDataDyadminoRackIndex = arc4random() % [(NSArray *)currentPlayer.rackIndexes count];
      NSNumber *randomDataDyadminoIndex = [(NSArray *)currentPlayer.rackIndexes objectAtIndex:randomDataDyadminoRackIndex];
      DataDyadmino *dataDyadmino = [self.myMatch dataDyadminoForIndex:[randomDataDyadminoIndex unsignedIntegerValue]];
      
      [self.swapContainer addObject:dataDyadmino];
      [self.myMatch passTurnBySwappingDyadminoes:self.swapContainer];
      
      Player *nextPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger nextPlayerIndex = [nextPlayer returnOrder];
      NSUInteger nextTurnCount = [(NSArray *)self.myMatch.turns count];
      
        // next player will be current player for solo game
      BOOL switchesCorrectlyToNextPlayer = ([self.myMatch returnType] == kSelfGame) ?
      (nextPlayerIndex == currentPlayerIndex) :
      ((nextPlayerIndex - currentPlayerIndex + numberOfPlayers) % numberOfPlayers) == 1;
      
      XCTAssertTrue(switchesCorrectlyToNextPlayer, @"Does not switch to next player after swap correctly.");
      XCTAssertTrue(nextTurnCount == currentTurnCount + 1, @"Swap did not add pass turn.");
    }
  }
}

-(void)testSwapCorrectlyExchangesBetweenPileAndRack {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    
      // returns all subsets of dyadminoes
    NSArray *numberArray = [self arrayOfNumbersWithCount:kNumDyadminoesInRack];
    NSArray *powerSetArray = [self powerSet:numberArray];

      // for this particular combination of data dyadminoes to be swapped
    for (NSArray *rackOrderArray in powerSetArray) {
      
      self.swapContainer = [NSMutableSet new];
      [self setupGameForNumberOfPlayers:i];
      
      Player *player = [self.myMatch returnCurrentPlayer];
      NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
      
      NSUInteger beforePileCount = self.myMatch.pile.count;
      NSUInteger beforeDataDyadminoIndexesCount = dataDyadminoIndexes.count;
      
      NSMutableArray *tempSwappedDataDyads = [NSMutableArray new];
      
      for (NSNumber *index in rackOrderArray) {
        NSUInteger rackOrderIndex = [index unsignedIntegerValue];
        NSUInteger dataDyadminoIndex = [dataDyadminoIndexes[rackOrderIndex] unsignedIntegerValue];
        DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:dataDyadminoIndex];
        [self.swapContainer addObject:dataDyad];
        [tempSwappedDataDyads addObject:dataDyad];
      }
      
      NSArray *swappedDataDyads = [NSArray arrayWithArray:tempSwappedDataDyads];
      
        // swapped!
      [self.myMatch passTurnBySwappingDyadminoes:self.swapContainer];
      
      NSUInteger afterPileCount = self.myMatch.pile.count;
      NSUInteger afterDataDyadminoIndexesCount = [(NSArray *)player.rackIndexes count];
      
        // check pile count is same
      XCTAssertEqual(beforePileCount, afterPileCount, @"Pile count is different after swap.");
      
        // check player rack count is same
      XCTAssertEqual(beforeDataDyadminoIndexesCount, afterDataDyadminoIndexesCount, @"Player rack count is different after swap.");
      
        // check swapped dyadminoes are now in pile
      for (DataDyadmino *dataDyad in swappedDataDyads) {
        PlaceStatus placeStatus = (PlaceStatus)[dataDyad.placeStatus unsignedIntegerValue];
        XCTAssertTrue(placeStatus == kInPile, @"Data dyadmino is not back in pile after swap.");
      }
    }
  }
}

-(void)testPlayerNeverGetsSameDyadminoesBackAfterSwap {
  
    // repeat 100 times to be sure
  for (int i = 0; i < 100; i++) {

    [self setupGameForNumberOfPlayers:1];
    self.swapContainer = [NSMutableSet new];
    
    NSMutableArray *tempSwappedDataDyadminoIndexes = [NSMutableArray new];
    Player *player = [self.myMatch returnCurrentPlayer];
    NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
    
      // exchange all data dyadminoes in rack
    for (NSNumber *index in dataDyadminoIndexes) {
      DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[index unsignedIntegerValue]];
      [tempSwappedDataDyadminoIndexes addObject:index];
      [self.swapContainer addObject:dataDyad];
    }
    
    [self.myMatch passTurnBySwappingDyadminoes:self.swapContainer];
    NSArray *postSwapDataDyadminoIndexes = (NSArray *)player.rackIndexes;

    BOOL noDataDyadminoesReturnedToRack = YES;
    for (NSNumber *index in tempSwappedDataDyadminoIndexes) {
      if ([postSwapDataDyadminoIndexes containsObject:index]) {
        noDataDyadminoesReturnedToRack = NO;
      }
    }
    
    XCTAssertTrue(noDataDyadminoesReturnedToRack, @"Some data dyadminoes returned to rack after swap.");
  }
}

-(void)testSwapNotPossibleIfSwapContainerExceedsPileCount {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    
      // test all possible number of dyadminoes to swap
    for (int j = 0; j <= kNumDyadminoesInRack; j++) {
      
        // test all possible number of dyadminoes left in pile
      for (int k = 0; k <= kNumDyadminoesInRack; k++) {
        [self setupGameForNumberOfPlayers:i];
        self.swapContainer = [NSMutableSet new];
        
        NSUInteger numberToRemove = kPileCount - (i * kNumDyadminoesInRack) - 1 - k;
        [self.myMatch removeFromPileNumberOfDataDyadminoes:numberToRemove];
        
        Player *player = [self.myMatch returnCurrentPlayer];
        NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
        
          // exchange data dyadminoes
        for (int l = 0; l < j; l++) {
          NSNumber *numberIndex = dataDyadminoIndexes[l];
          DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[numberIndex unsignedIntegerValue]];
          [self.swapContainer addObject:dataDyad];
        }
        
        BOOL dyadminoesShouldBeSwapped = (j > 0 && j <= k);
        BOOL dyadminoesWereSwapped = [self.myMatch passTurnBySwappingDyadminoes:self.swapContainer];
        
        XCTAssertTrue(dyadminoesShouldBeSwapped == dyadminoesWereSwapped, @"Dyadminoes should have been swapped but weren't, or vice versa.");
      }
    }
  }
}

-(void)testThatSwapFailsIfSwapContainerContainsDyadminoNotInCurrentPlayerRack {
  
  [self setupGameForNumberOfPlayers:1];
  self.swapContainer = [NSMutableSet new];
  Player *currentPlayer = [self.myMatch returnCurrentPlayer];
  
    // random dyadmino in pile
  NSNumber *swappedIndex;
  while (!swappedIndex) {
    NSNumber *randomIndex = @(arc4random() % kPileCount);
    if (![currentPlayer.rackIndexes containsObject:swappedIndex]) {
      swappedIndex = randomIndex;
    }
  }
  
  [self.swapContainer addObject:[self.myMatch dataDyadminoForIndex:[swappedIndex unsignedIntegerValue]]];
  BOOL successfullySwapped = [self.myMatch passTurnBySwappingDyadminoes:self.swapContainer];
  
  XCTAssertFalse(successfullySwapped, @"Swap of dyadmino that was not in rack should not have succeeded.");
}

#pragma mark - resign tests

-(void)testResignSwitchesToNextPlayer {
    // duplicates testPassesToNextPlayer, except with resign
  
    // test 3 to 4 players
  for (int i = 3; i <= kMaxNumPlayers; i++) {

      // test that passes to next player for each player
    for (int j = 1; j <= i; j++) {
      
      [self setupGameForNumberOfPlayers:i];
      NSInteger numberOfPlayers = self.myMatch.players.count;
      
        // pass this many times, depending on order of player
      for (int k = 1; k < j; k++) {
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
      
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnOrder];
      NSUInteger currentTurnCount = [(NSArray *)self.myMatch.turns count];
      
      [self.myMatch resignPlayer:currentPlayer];
      
      Player *nextPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger nextPlayerIndex = [nextPlayer returnOrder];
      NSUInteger nextTurnCount = [(NSArray *)self.myMatch.turns count];
      
        // next player will be current player for solo game
      BOOL switchesCorrectlyToNextPlayer = ((nextPlayerIndex - currentPlayerIndex + numberOfPlayers) % numberOfPlayers) == 1;
      
      XCTAssertTrue(switchesCorrectlyToNextPlayer, @"Does not switch to next player correctly after resign.");
      XCTAssertTrue(nextTurnCount == currentTurnCount + 1, @"Resign did not add turn.");
    }
  }
}

-(void)testResignCorrectlyReturnsRackDyadminoesToPile {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
      
    [self setupGameForNumberOfPlayers:i];
    
    Player *player = [self.myMatch returnCurrentPlayer];
    NSArray *dataDyadminoIndexes = [NSArray arrayWithArray:(NSArray *)player.rackIndexes];
    
    [self.myMatch resignPlayer:player];
    
    BOOL allRackDyadminoesAreBackInPile = YES;
    for (NSNumber *number in dataDyadminoIndexes) {
      DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[number unsignedIntegerValue]];
      
      if (![self.myMatch.pile containsObject:dataDyad]) {
        allRackDyadminoesAreBackInPile = NO;
      }
    }
    
    XCTAssert(allRackDyadminoesAreBackInPile, @"Not all resigned player's dyadminoes are back in pile.");
  }
}

-(void)testResignedPlayerIsSkipped {
  
    // test 3 to 4 players
  for (int i = 3; i <= kMaxNumPlayers; i++) {
    
    for (int j = 1; j <= i; j++) {
      
      [self setupGameForNumberOfPlayers:i];
      
        // pass this many times, depending on order of player
      for (int k = 1; k < j; k++) {
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
      
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnOrder];
      
      [self.myMatch resignPlayer:currentPlayer];
      
        // pass to player before in next round
      for (int k = 0; k < i - 1; k++) {
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
      
      Player *afterPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger afterPlayerIndex = [afterPlayer returnOrder];

      BOOL afterPlayerComesAfter = ((afterPlayerIndex - currentPlayerIndex + i) % i) == 1;
      XCTAssertTrue(afterPlayerComesAfter, @"Resigned player is not skipped over in next round.");
    }
  }
}

#pragma mark - undo tests

-(void)testAddAndUndoDyadminoesToHoldingContainer {
  
  [self setupGameForNumberOfPlayers:1];
  
  Player *player = [self.myMatch returnCurrentPlayer];
  NSArray *dataDyadminoIndexes = [NSArray arrayWithArray:(NSArray *)player.rackIndexes];
  
    // add dyadminoes to holding container one by one, in sequential order
  for (int i = 0; i < kNumDyadminoesInRack; i++) {
    NSNumber *dataDyadIndex = dataDyadminoIndexes[i];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[dataDyadIndex unsignedIntegerValue]];
    [self.myMatch testAddToHoldingContainer:dataDyad];

    XCTAssertEqualObjects([self.myMatch.holdingIndexContainer lastObject], dataDyadIndex, @"Data dyadmino index was not added to holding container.");
    XCTAssertTrue([self.myMatch.holdingIndexContainer count] == i + 1, @"Holding container count is incorrect for added dyadmino.");
  }
  
    // undo dyadminoes in holding container one by one, in reverse order
  for (int i = kNumDyadminoesInRack - 1; i >= 0; i--) {
    
    NSNumber *dataDyadIndex = dataDyadminoIndexes[i];
    XCTAssertEqualObjects([self.myMatch.holdingIndexContainer lastObject], dataDyadIndex, @"Data dyadmino index was not removed from holding container after last undo.");
    
    [self.myMatch testUndoLastPlayedDyadmino];
    
    XCTAssertEqual([self.myMatch.holdingIndexContainer count], i, @"Holding container count is incorrect after undo.");
  }
}

-(void)testUndoNotPossibleWithStrandedDyadminoes {
  XCTFail(@"");

//    // test 100 times
//  for (int i = 0; i < 100; i++) {
//    
//    [self setupGameForNumberOfPlayers:1];
//    Player *currentPlayer = [self.myMatch returnCurrentPlayer];
//    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[[currentPlayer.rackIndexes lastObject] unsignedIntegerValue]];
//    
//    NSUInteger randomX = (3 + (arc4random() % 10)) * ((arc4random() % 2) ? 1 : -1);
//    NSUInteger randomY = (3 + (arc4random() % 10)) * ((arc4random() % 2) ? 1 : -1);
//    DyadminoOrientation randomOrientation = arc4random() % 6;
//    
//    HexCoord bottomHexCoord = [self hexCoordFromX:randomX andY:randomY];
//    dataDyad.myHexCoord = bottomHexCoord;
//    dataDyad.myOrientation = @(randomOrientation);
//    
//    [self.myMatch playDataDyadmino:dataDyad onBottomHexCoord:bottomHexCoord withOrientation:randomOrientation];
//    BOOL strandedDyadminoes = [self.myMatch testStrandedDyadminoesAfterRemovingDataDyadmino:dataDyad];
//    BOOL undoSuccessful = [self.myMatch undoLastPlayedDyadmino];
//    
//    if (strandedDyadminoes) {
//      XCTAssertFalse(undoSuccessful, @"Undo should not be possible if it leaves dyadminoes stranded.");
//    } else {
//      XCTAssertTrue(undoSuccessful, @"Undo should be possible if it leaves dyadminoes stranded.");
//    }
//  }
}

#pragma mark - turn tests

-(void)testRackIsProperlyRefilledAfterPlayedTurn {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    
      // returns all subsets of dyadminoes
    NSArray *numberArray = [self arrayOfNumbersWithCount:kNumDyadminoesInRack];
    NSArray *powerSetArray = [self powerSet:numberArray];
    
      // for this particular combination of data dyadminoes to be played
    for (NSArray *rackOrderArray in powerSetArray) {
      if (rackOrderArray.count > 0) {
        
        [self setupGameForNumberOfPlayers:i];
        
        Player *player = [self.myMatch returnCurrentPlayer];
        NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
        
        NSUInteger beforePileCount = self.myMatch.pile.count;
        NSUInteger beforeDataDyadminoIndexesCount = dataDyadminoIndexes.count;
        
        NSMutableArray *tempPlayedDataDyads = [NSMutableArray new];
        
        for (NSNumber *index in rackOrderArray) {
          NSUInteger rackOrderIndex = [index unsignedIntegerValue];
          NSUInteger dataDyadminoIndex = [dataDyadminoIndexes[rackOrderIndex] unsignedIntegerValue];
          DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:dataDyadminoIndex];
          [self.myMatch testAddToHoldingContainer:dataDyad];
          [tempPlayedDataDyads addObject:dataDyad];
        }
        
        NSArray *playedDataDyads = [NSArray arrayWithArray:tempPlayedDataDyads];
        
          // played!
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
        
        NSUInteger afterPileCount = self.myMatch.pile.count;
        NSUInteger afterDataDyadminoIndexesCount = [(NSArray *)player.rackIndexes count];
        
          // check after pile count is before pile count minus data dyadminoes played
        XCTAssertTrue(beforePileCount == afterPileCount + rackOrderArray.count, @"Pile count did not subtract dyadmino count properly after play.");
        
          // check player rack count is same
        XCTAssertEqual(beforeDataDyadminoIndexesCount, afterDataDyadminoIndexesCount, @"Player rack count is different after play.");
        
          // check played dyadminoes are now on board
        for (DataDyadmino *dataDyad in playedDataDyads) {
          PlaceStatus placeStatus = (PlaceStatus)[dataDyad.placeStatus unsignedIntegerValue];
          XCTAssertTrue(placeStatus == kOnBoard, @"Data dyadmino is not on board after play.");
        }
      }
    }
  }
}

-(void)testRackRefillsOnlyUntilPileIsEmptyAndGameEndsWhenPileAndRackAreBothEmpty {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    
      // test all possible number of dyadminoes to play
    for (int j = 0; j <= kNumDyadminoesInRack; j++) {
      
        // test all possible number of dyadminoes left in pile from 0 to 6
      for (int k = 0; k <= kNumDyadminoesInRack; k++) {
        [self setupGameForNumberOfPlayers:i];
        
        Player *player = [self.myMatch returnCurrentPlayer];
        NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
        
        NSUInteger numberToRemove = kPileCount - (i * kNumDyadminoesInRack) - 1 - k;
        [self.myMatch removeFromPileNumberOfDataDyadminoes:numberToRemove];
        
          // play data dyadminoes
        for (int l = 0; l < j; l++) {
          NSNumber *numberIndex = dataDyadminoIndexes[l];
          DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[numberIndex unsignedIntegerValue]];
          [self.myMatch testAddToHoldingContainer:dataDyad];
        }
        
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
        
        NSUInteger rackCount = [(NSArray *)player.rackIndexes count];
        
        BOOL pileIsEmptyAndPlayerRackLessThanFullIfMoreDyadminoesPlayedThanLeftInPile = YES;
        
          // number left in pile is less than number played
        if (k < j) {
          if (rackCount == kNumDyadminoesInRack || self.myMatch.pile.count > 0) {
            pileIsEmptyAndPlayerRackLessThanFullIfMoreDyadminoesPlayedThanLeftInPile = NO;
          }
        }
        
        XCTAssertTrue(pileIsEmptyAndPlayerRackLessThanFullIfMoreDyadminoesPlayedThanLeftInPile, @"Pile should be empty and player rack less than full if more dyadminoes were played than there were dyadminoes left in pile.");
        
          // none left in pile or rack, game should end
          // this is also a separate test by itself, but it never hurts to test again
        BOOL gameEndsIfPileAndRackAreEmpty = YES;
        if (self.myMatch.pile.count == 0 && rackCount == 0 && ![self.myMatch returnGameHasEnded]) {
          gameEndsIfPileAndRackAreEmpty = NO;
        }
        
        XCTAssertTrue(gameEndsIfPileAndRackAreEmpty, @"Game did not end after play leaves empty pile and empty rack.");
      }
    }
  }
}

#pragma mark - recording of turn tests

-(void)testTurnsAreRecordedSequentially {
  
    // test 2 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
    NSUInteger preTurnCount, postTurnCount;
    
      // pass this many times
    for (int j = 0; j < 2 * i; j++) {
      
      preTurnCount = [(NSArray *)self.myMatch.turns count];
      [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      postTurnCount = [(NSArray *)self.myMatch.turns count];
      
      XCTAssertTrue(preTurnCount == j, @"Turns start at 0.");
      XCTAssertTrue(postTurnCount == preTurnCount + 1, @"Turn was not recorded sequentially.");
    }
  }
}

-(void)testTurnRecordsProperPlayer {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];

      // pass this many times
    for (int j = 0; j < 2 * i; j++) {
      
      NSUInteger expectedPlayerOrder = [[self.myMatch currentPlayerOrder] unsignedIntegerValue];
      [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      
      NSDictionary *turn = [(NSArray *)self.myMatch.turns lastObject];
      NSUInteger returnedPlayerOrder = [(NSNumber *)[turn objectForKey:@"player"] unsignedIntegerValue];
      XCTAssertEqual(expectedPlayerOrder, returnedPlayerOrder, @"Proper player not recorded for turn.");
    }
  }
}

-(void)testTurnForPassIsRecordedWithEmptyContainer {
  
    // test 2 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    
    NSDictionary *turn = [(NSArray *)self.myMatch.turns lastObject];
    id indexContainer = [turn objectForKey:@"indexContainer"];
    XCTAssertTrue([indexContainer isKindOfClass:[NSArray class]], @"Index container is not an array.");
    
    NSArray *indexContainerArray = (NSArray *)indexContainer;
    XCTAssertTrue(indexContainerArray.count == 0, @"Index container is not empty for pass.");
  }
}

-(void)testTurnForSwapIsRecordedLikePass {
  self.swapContainer = [NSMutableSet new];

    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    NSInteger numberOfPlayers = self.myMatch.players.count;
    
      // swap needs to have a data dyadmino in
    for (int j = 1; j <= numberOfPlayers; j++) {
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      
        // random data dyadmino
      NSUInteger randomDataDyadminoRackIndex = arc4random() % [(NSArray *)currentPlayer.rackIndexes count];
      NSNumber *randomDataDyadminoIndex = [(NSArray *)currentPlayer.rackIndexes objectAtIndex:randomDataDyadminoRackIndex];
      DataDyadmino *dataDyadmino = [self.myMatch dataDyadminoForIndex:[randomDataDyadminoIndex unsignedIntegerValue]];
      
      [self.swapContainer addObject:dataDyadmino];
      [self.myMatch passTurnBySwappingDyadminoes:self.swapContainer];
      
      NSDictionary *turn = [(NSArray *)self.myMatch.turns lastObject];
      NSArray *indexContainer = (NSArray *)[turn objectForKey:@"indexContainer"];
      
      XCTAssertTrue(indexContainer.count == 0, @"Index container is not empty for swap.");
    }
  }
}

-(void)testTurnForResignIsRecordedWithNoContainer {
  
    // test 3 to 4 players
  for (int i = 3; i <= kMaxNumPlayers; i++) {
    
      // test for each player
    for (int j = 1; j <= i; j++) {
      
      [self setupGameForNumberOfPlayers:i];

        // pass this many times, depending on order of player
      for (int k = 1; k < j; k++) {
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
      
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      
      [self.myMatch resignPlayer:currentPlayer];
      
      NSDictionary *turn = [(NSArray *)self.myMatch.turns lastObject];
      NSArray *indexContainer = (NSArray *)[turn objectForKey:@"indexContainer"];
      
      XCTAssertNil(indexContainer, @"Index container should be nil for resign.");
    }
  }
}

#pragma mark - recorded data dyadmino tests

-(void)testDataDyadDoesNotAddTurnChangeIfNotMoved {
  
  [self setupGameForNumberOfPlayers:2];
  DataDyadmino *firstDataDyad = [self.myMatch dataDyadminoForIndex:[self.myMatch returnFirstDataDyadIndex]];

    // three passes in a row
  [self.myMatch testPersistChangedPositionForBoardDataDyadmino:firstDataDyad];
  [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
  
  [self.myMatch testPersistChangedPositionForBoardDataDyadmino:firstDataDyad];
  [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];

  [self.myMatch testPersistChangedPositionForBoardDataDyadmino:firstDataDyad];
  [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
  
    // should only have one turn change, which records its initial placement
  XCTAssertTrue([(NSArray *)firstDataDyad.turnChanges count] == 1, @"Extra turn change should not have been added.");
}

  // this test fails occasionally, not sure why
-(void)testDataDyadRecordsBoardDyadminoChange {
  
    // test 100 times
  for (int i = 0; i < 100; i++) {
    
      // test for just 2 players
    [self setupGameForNumberOfPlayers:2];
    DataDyadmino *firstDataDyad = [self.myMatch dataDyadminoForIndex:[self.myMatch returnFirstDataDyadIndex]];
    
    HexCoord originalCoord = firstDataDyad.myHexCoord;
    DyadminoOrientation originalOrientation = (DyadminoOrientation)[firstDataDyad.myOrientation unsignedIntegerValue];
 
    NSInteger randX = [self randomIntegerUpTo:20] - 10;
    NSInteger randY = [self randomIntegerUpTo:20] - 10;
    HexCoord movedCoord = [self hexCoordFromX:randX andY:randY];
    DyadminoOrientation movedOrientation = (DyadminoOrientation)[self randomIntegerUpTo:5];
    
    firstDataDyad.myHexCoord = movedCoord;
    firstDataDyad.myOrientation = [NSNumber numberWithUnsignedInteger:movedOrientation];
    [self.myMatch testPersistChangedPositionForBoardDataDyadmino:firstDataDyad];
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    
    NSDictionary *turnChange = (NSDictionary *)[(NSArray *)firstDataDyad.turnChanges lastObject];

      // if coordinate changed
    if (originalCoord.x != movedCoord.x || originalCoord.y != movedCoord.y) {
      NSInteger returnedX = [[turnChange valueForKey:@"hexX"] integerValue];
      NSInteger returnedY = [[turnChange valueForKey:@"hexY"] integerValue];

      XCTAssertEqual(movedCoord.x, returnedX, @"X value not as expected.");
      XCTAssertEqual(movedCoord.y, returnedY, @"Y value not as expected.");
    } else {
      XCTAssertNil([turnChange valueForKey:@"hexX"], @"Should not have object for hexX key.");
      XCTAssertNil([turnChange valueForKey:@"hexY"], @"Should not have object for hexY key.");
    }
    
      // if orientation changed
    if (originalOrientation != movedOrientation) {
      DyadminoOrientation returnedOrientation = (DyadminoOrientation)[[turnChange valueForKey:@"orientation"] unsignedIntegerValue];
      XCTAssertEqual(movedOrientation, returnedOrientation, @"Orientation value not as expected.");
    } else {
      XCTAssertNil([turnChange valueForKey:@"orientation"], @"Should not have object for orientation key.");
    }
  }
}

-(void)testDataDyadRecordsCorrectTurn {
  
    // test 100 times
  for (int i = 0; i < 100; i++) {
    
      // test for 4 players (to maximise passes)
    [self setupGameForNumberOfPlayers:4];
    DataDyadmino *firstDataDyad = [self.myMatch dataDyadminoForIndex:[self.myMatch returnFirstDataDyadIndex]];
    
    for (int j = 0; j < 4 * 2; j++) {
    
      HexCoord originalCoord = firstDataDyad.myHexCoord;
      DyadminoOrientation originalOrientation = (DyadminoOrientation)[firstDataDyad.myOrientation unsignedIntegerValue];
      
        // change coordinate and orientation (there's a chance it's the same as original)
      NSInteger randX = [self randomIntegerUpTo:20] - 10;
      NSInteger randY = [self randomIntegerUpTo:20] - 10;
      HexCoord movedCoord = [self hexCoordFromX:randX andY:randY];
      DyadminoOrientation movedOrientation = (DyadminoOrientation)[self randomIntegerUpTo:5];
      
      firstDataDyad.myHexCoord = movedCoord;
      firstDataDyad.myOrientation = [NSNumber numberWithUnsignedInteger:movedOrientation];
    
      [self.myMatch testPersistChangedPositionForBoardDataDyadmino:firstDataDyad];
      [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    
        // if moved
      if (originalCoord.x != movedCoord.x || originalCoord.y != movedCoord.y || originalOrientation != movedOrientation) {
        NSDictionary *turnChange = (NSDictionary *)[(NSArray *)firstDataDyad.turnChanges lastObject];

        NSUInteger turnNumber = [[turnChange valueForKey:@"turn"] unsignedIntegerValue];
        
          // first data dyadmino turn count begins at 0
        XCTAssertEqual(turnNumber, [(NSArray *)self.myMatch.turns count] - 1, @"Turn value not as expected.");
      }
    }
  }
}

-(void)testDataDyadRecordsRackDyadminoPlacement {

    // test 100 times
  for (int i = 0; i <= 100; i++) {
    
      // test for 2 players (number of players not important)
    [self setupGameForNumberOfPlayers:2];
    
    Player *player = [self.myMatch returnCurrentPlayer];
    NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
    
      // play first dyadmino
    NSUInteger dataDyadminoIndex = [dataDyadminoIndexes[0] unsignedIntegerValue];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:dataDyadminoIndex];
    HexCoord originalCoord = dataDyad.myHexCoord;
    
      // change coordinate and orientation (there's a chance it's the same as original)
    NSInteger randX = [self randomIntegerUpTo:20] - 10;
    NSInteger randY = [self randomIntegerUpTo:20] - 10;
    HexCoord movedCoord = [self hexCoordFromX:randX andY:randY];
    DyadminoOrientation movedOrientation = (DyadminoOrientation)[self randomIntegerUpTo:5];
    
    dataDyad.myHexCoord = movedCoord;
    dataDyad.myOrientation = [NSNumber numberWithUnsignedInteger:movedOrientation];
    
    [self.myMatch testAddToHoldingContainer:dataDyad];
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    [self.myMatch testPersistChangedPositionForBoardDataDyadmino:dataDyad];

    NSDictionary *turnChange = (NSDictionary *)[(NSArray *)dataDyad.turnChanges lastObject];
    
      // if coordinate is different
    if (originalCoord.x != movedCoord.x || originalCoord.y != movedCoord.y) {
      NSInteger returnedX = [[turnChange valueForKey:@"hexX"] integerValue];
      NSInteger returnedY = [[turnChange valueForKey:@"hexY"] integerValue];
      
      XCTAssertEqual(movedCoord.x, returnedX, @"X value not as expected.");
      XCTAssertEqual(movedCoord.y, returnedY, @"Y value not as expected.");
    }
    
      // orientation in rack will be different, so object for key will always exist
    DyadminoOrientation returnedOrientation = (DyadminoOrientation)[[turnChange valueForKey:@"orientation"] unsignedIntegerValue];
    XCTAssertEqual(movedOrientation, returnedOrientation, @"Orientation value not as expected.");
    XCTAssertNotNil([turnChange valueForKey:@"orientation"], @"Object for orientation key should not be nil.");
  }
}

#pragma mark - replay tests

-(void)testReplayStartsAndEndsOnLastTurn {
  
  [self playFullGameForNumberOfPlayers:4];
  [self.myMatch startReplay];
  
  NSUInteger replayTurn = self.myMatch.replayTurn;
  XCTAssertEqual(replayTurn, [(NSArray *)self.myMatch.turns count], @"Replay does not start on last turn.");
  
  [self.myMatch leaveReplay];
  replayTurn = self.myMatch.replayTurn;
  XCTAssertEqual(replayTurn, [(NSArray *)self.myMatch.turns count], @"Replay does not leave on last turn.");
}

-(void)testReplayFirstAndLast {
  [self playFullGameForNumberOfPlayers:4];
  [self.myMatch startReplay];
  [self.myMatch first];
  
  NSUInteger replayTurn = self.myMatch.replayTurn;
  XCTAssertEqual(replayTurn, 1, @"Replay first does not go to turn 1.");
  
  [self.myMatch last];
  replayTurn = self.myMatch.replayTurn;
  XCTAssertEqual(replayTurn, [(NSArray *)self.myMatch.turns count], @"Replay last does not go to last turn.");
}

-(void)testReplayPreviousAndNext {
  [self playFullGameForNumberOfPlayers:4];
  [self.myMatch startReplay];
  
  NSUInteger expectedReplayTurn = self.myMatch.replayTurn;
    // press previous one by one
  do {
    [self.myMatch previous];
    expectedReplayTurn--;
    XCTAssertEqual(self.myMatch.replayTurn, expectedReplayTurn, @"Replay previous does not go to previous turn.");
  } while (self.myMatch.replayTurn > 1);
  
    // now it's at turn 1
    // press next one by one
  expectedReplayTurn = 1;
  do {
    [self.myMatch next];
    expectedReplayTurn++;
    XCTAssertEqual(self.myMatch.replayTurn, expectedReplayTurn, @"Replay next does not go to next turnturn.");
  } while (self.myMatch.replayTurn < [(NSArray *)self.myMatch.turns count]);
  
  [self.myMatch leaveReplay];
}

#pragma mark - match game end tests

-(void)testPassEndsSelfGame {
  [self setupGameForNumberOfPlayers:1];
  [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
  XCTAssertTrue(self.myMatch.gameHasEnded, @"Game does not end after pass in self game.");
}

-(void)testCorrectNumberOfPassesEndMatchForAllNumbersOfPlayersWithoutResigns {
  
    // test 2 to 4 players, two rotations for dyadminoes left in pile
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
      // pass this many times, up until the last turn before game ends
    for (int j = 0; j < 2 * i - 1; j++) {
      [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    }
    XCTAssertFalse([self.myMatch returnGameHasEnded], @"Game ended prematurely with dyadminoes left in pile.");
    
      // now pass once, and game should end
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game should have ended with dyadminoes left in pile.");
  }
  
    // test 2 to 4 players, one rotation for no dyadminoes left in pile
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    [self.myMatch removeFromPileNumberOfDataDyadminoes:self.myMatch.pile.count];
    
      // pass this many times, up until the last turn before game ends
    for (int j = 0; j < i - 1; j++) {
      [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    }
    XCTAssertFalse([self.myMatch returnGameHasEnded], @"Game ended prematurely with no dyadminoes left in pile.");
    
      // now pass once, and game should end
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game should have ended with no dyadminoes left in pile.");
  }
}

-(void)testCorrectNumberOfPassesEndMatchForAllNumbersOfPlayersWithResigns {
  
    // test 2 to 4 players, two rotations for dyadminoes left in pile
  for (int i = 3; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
      // pass this many times, up until the last turn before game ends
      // in four player game, player 2 resigns first cycle, player 3 resigns second cycle
      // in three player game, player 2 resigns first cycle
    for (int j = 0; j < 2 * i - 1 - 1; j++) {
      if ((i == 3 && j == 1) || (i == 4 && (j == 1 || j == 5))) {
        [self.myMatch resignPlayer:[self.myMatch returnCurrentPlayer]];
      } else {
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
    }
    XCTAssertFalse([self.myMatch returnGameHasEnded], @"Game ended prematurely with dyadminoes left in pile.");
    
      // now pass once, and game should end
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game should have ended with dyadminoes left in pile.");
  }
  
    // test 2 to 4 players, one rotation for no dyadminoes left in pile
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    [self.myMatch removeFromPileNumberOfDataDyadminoes:self.myMatch.pile.count];
    
      // pass this many times, up until the last turn before game ends
      // in either three or four player game, player 2 resigns
    for (int j = 0; j < i - 1; j++) {
      if (j == 1) {
        [self.myMatch resignPlayer:[self.myMatch returnCurrentPlayer]];
        [self.myMatch removeFromPileNumberOfDataDyadminoes:kNumDyadminoesInRack]; // ensures that pile remains empty upon resign
      } else {
        [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
    }
    XCTAssertFalse([self.myMatch returnGameHasEnded], @"Game ended prematurely with no dyadminoes left in pile.");
    
      // now pass once, and game should end
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game should have ended with no dyadminoes left in pile.");
  }
}

-(void)testResignEndsSelfGame {
  [self setupGameForNumberOfPlayers:1];
  [self.myMatch resignPlayer:[self.myMatch returnCurrentPlayer]];
  XCTAssertTrue(self.myMatch.gameHasEnded, @"Game does not end after resign in self game.");
}

-(void)testResignEndsPnPGame {
  
    // test 2 to 4 players
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    
    XCTAssertFalse([self.myMatch returnGameHasEnded], @"Game ended before enough players resigned.");
    
    for (int j = 0; j < i - 1; j++) {
      [self.myMatch resignPlayer:[self.myMatch returnCurrentPlayer]];
    }
    
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game did not end after enough players resigned.");
  }
}

-(void)testGameEndsIfPileIsEmptyAndPlayerPlaysLastDyadmino {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    
    [self setupGameForNumberOfPlayers:i];
    
    Player *player = [self.myMatch returnCurrentPlayer];
    NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
    
      // remove all dyadminoes in pile
    NSUInteger numberToRemove = kPileCount - (i * kNumDyadminoesInRack) - 1;
    [self.myMatch removeFromPileNumberOfDataDyadminoes:numberToRemove];
    
      // play all data dyadminoes
    for (int k = 0; k < kNumDyadminoesInRack; k++) {
      NSNumber *numberIndex = dataDyadminoIndexes[k];
      DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[numberIndex unsignedIntegerValue]];
      [self.myMatch testAddToHoldingContainer:dataDyad];
    }
    
    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
    NSUInteger rackCount = [(NSArray *)player.rackIndexes count];
    XCTAssertTrue(rackCount == 0, @"Rack should be empty because player played all dyadminoes.");
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game did not end after play leaves empty pile and empty rack.");
  }
}

#pragma mark - cell tests

-(void)testUpdateCellsForPlacedAndRemovedDyadminoes {
  
    // test 100 times
  for (int i = 0; i < 100; i++) {
    
    [self setupGameForNumberOfPlayers:1];
    Player *currentPlayer = [self.myMatch returnCurrentPlayer];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[[currentPlayer.rackIndexes lastObject] unsignedIntegerValue]];
    
      // returns random number above 3 or below -3, so as not to conflict with board dyadmino
    NSUInteger randomX = (3 + (arc4random() % 10)) * ((arc4random() % 2) ? 1 : -1);
    NSUInteger randomY = (3 + (arc4random() % 10)) * ((arc4random() % 2) ? 1 : -1);
    DyadminoOrientation randomOrientation = arc4random() % 6;
    
    HexCoord bottomHexCoord = [self hexCoordFromX:randomX andY:randomY];
    HexCoord topHexCoord = [self retrieveTopHexCoordForBottomHexCoord:bottomHexCoord andOrientation:randomOrientation];
    
    [self.myMatch testUpdateDataCellsForPlacedDyadminoID:[dataDyad returnMyID]
                                             orientation:randomOrientation
                                    onBottomCellHexCoord:bottomHexCoord];
    
    HexCoord hexCoords[2] = {topHexCoord, bottomHexCoord};
    for (int j = 0; j < 2; j++) {
      HexCoord hexCoord = hexCoords[j];
      BOOL cellUpdatedForPlacedHexCoord = NO;
      BOOL isPC1 = (randomOrientation <= kPC1atTwoOClock || randomOrientation >= kPC1atTenOClock);
      NSUInteger pc = [self pcForDyadminoIndex:[dataDyad returnMyID] isPC1:(j == 0 ? isPC1 : !isPC1)];
      for (DataCell *occupiedCell in self.myMatch.occupiedCells) {
        if (occupiedCell.myPC == pc &&
            occupiedCell.myDyadminoID == [dataDyad returnMyID] &&
            occupiedCell.hexX == hexCoord.x &&
            occupiedCell.hexY == hexCoord.y) {
          cellUpdatedForPlacedHexCoord = YES;
        }
      }
      
      XCTAssertTrue(cellUpdatedForPlacedHexCoord, @"Occupied cell was not updated for dyadmino placed on hex coord %li, %li.", (long)hexCoord.x, (long)hexCoord.y);
    }
    
    [self.myMatch testUpdateDataCellsForRemovedDyadminoID:[dataDyad returnMyID]
                                              orientation:randomOrientation
                                   fromBottomCellHexCoord:bottomHexCoord];
    
    for (int j = 0; j < 2; j++) {
      HexCoord hexCoord = hexCoords[j];
      BOOL cellUpdatedForRemovedHexCoord = YES;
      for (DataCell *occupiedCell in self.myMatch.occupiedCells) {
        if (occupiedCell.hexX == hexCoord.x &&
            occupiedCell.hexY == hexCoord.y) {
          cellUpdatedForRemovedHexCoord = NO;
        }
      }
      
      XCTAssertTrue(cellUpdatedForRemovedHexCoord, @"Occupied cell was not updated for dyadmino removed from hex coord %li, %li.", (long)hexCoord.x, (long)hexCoord.y);
    }
    
  }
}

#pragma mark - physical cell tests

-(void)testSurroundingCellsMethodOnFirstDyadmino {
  
  [self setupGameForNumberOfPlayers:1];

  HexCoord bottomHexCoord = [self hexCoordFromX:0 andY:0];
  for (DyadminoOrientation orientation = kPC1atTwelveOClock; orientation <= kPC1atTenOClock; orientation++) {
    
    HexCoord topHexCoord = [self retrieveTopHexCoordForBottomHexCoord:bottomHexCoord andOrientation:orientation];
    
    NSSet *surroundingCells = [self.myMatch testSurroundingCellsOfDyadminoBottomHexCoord:bottomHexCoord
                                                                          andOrientation:orientation];
    
    for (DataCell *cell in surroundingCells) {
      
        // for at least one cell, difference in x plus difference in y is 1 or less
      BOOL neighbourOfTop = (abs((int)(cell.hexCoord.x - topHexCoord.x) + (int)(cell.hexCoord.y - topHexCoord.y)) <= 1);
      BOOL neighbourOfBottom = (abs((int)(cell.hexCoord.x - bottomHexCoord.x) + (int)(cell.hexCoord.y - bottomHexCoord.y)) <= 1);
      
      XCTAssertTrue(neighbourOfTop || neighbourOfBottom, @"cell is not close neighbour of at least one dyadmino cell.");
    }
    
    XCTAssertTrue(surroundingCells.count == 8, @"Number of surrounding cells returned was %lu, should be eight for single dyadmino.", (unsigned long)surroundingCells.count);
  }
}

-(void)testSurroundingCellsOfSurroundingCellsMethodOnFirstDyadmino {
  
  [self setupGameForNumberOfPlayers:1];
  
  HexCoord bottomHexCoord = [self hexCoordFromX:0 andY:0];
  for (DyadminoOrientation orientation = kPC1atTwelveOClock; orientation <= kPC1atTenOClock; orientation++) {
    
    HexCoord topHexCoord = [self retrieveTopHexCoordForBottomHexCoord:bottomHexCoord andOrientation:orientation];
    
    NSSet *surroundingCellsOfSurroundingCells = [self.myMatch testSurroundingCellsOfSurroundingCellsOfDyadminoBottomHexCoord:bottomHexCoord
                                                                                            andOrientation:orientation];
    
    for (DataCell *cell in surroundingCellsOfSurroundingCells) {
      
        // for at least one cell, difference in x plus difference in y is 2 or less
      BOOL neighbourOfTop = (abs((int)(cell.hexCoord.x - topHexCoord.x) + (int)(cell.hexCoord.y - topHexCoord.y)) <= 2);
      BOOL neighbourOfBottom = (abs((int)(cell.hexCoord.x - bottomHexCoord.x) + (int)(cell.hexCoord.y - bottomHexCoord.y)) <= 2);
      
      XCTAssertTrue(neighbourOfTop || neighbourOfBottom, @"cell is not close neighbour of at least one dyadmino cell.");
    }
    
    XCTAssertTrue(surroundingCellsOfSurroundingCells.count == 14, @"Number of surrounding cells of surrounding cells returned for single dyadmino should be fourteen.");
  }
}

-(void)testValidateStackingOrNotOnFirstDyadmino {
  
  [self setupGameForNumberOfPlayers:1];
  DataDyadmino *firstDataDyad = [self.myMatch dataDyadminoForIndex:[self.myMatch returnFirstDataDyadIndex]];
  
    // test with all possible orientations of first board dyadmino
  for (DyadminoOrientation firstOrient = kPC1atTwelveOClock; firstOrient <= kPC1atTenOClock; firstOrient++) {
    [self.myMatch moveBoardDataDyadmino:firstDataDyad toBottomHexCoord:firstDataDyad.myHexCoord withOrientation:firstOrient];
    
    HexCoord firstBottomHexCoord = firstDataDyad.myHexCoord;
    HexCoord firstTopHexCoord = [self retrieveTopHexCoordForBottomHexCoord:firstDataDyad.myHexCoord andOrientation:[firstDataDyad returnMyOrientation]];
    HexCoord firstHexCoords[2] = {firstTopHexCoord, firstBottomHexCoord};
    
    NSSet *surroundingCellsOfBoardDyadmino = [self.myMatch testSurroundingCellsOfDyadminoBottomHexCoord:firstDataDyad.myHexCoord andOrientation:[firstDataDyad returnMyOrientation]];
    
    Player *currentPlayer = [self.myMatch returnCurrentPlayer];
    NSNumber *index = [currentPlayer.rackIndexes lastObject];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[index unsignedIntegerValue]];
    
    for (DataCell *surroundingCell in surroundingCellsOfBoardDyadmino) {
      for (DyadminoOrientation orientation = kPC1atTwelveOClock; orientation <= kPC1atTenOClock; orientation++) {
        BOOL returnedValidPhysicalPlacement = ([self.myMatch testValidatePhysicallyPlacingDyadminoID:[dataDyad returnMyID]
                                                                                    withOrientation:orientation
                                                                                   onBottomHexCoord:surroundingCell.hexCoord] == kNoError);
        
        BOOL expectedValidPhysicalPlacement = YES;
        HexCoord bottomHexCoord = surroundingCell.hexCoord;
        HexCoord topHexCoord = [self retrieveTopHexCoordForBottomHexCoord:bottomHexCoord andOrientation:orientation];
        HexCoord hexCoords[2] = {topHexCoord, bottomHexCoord};
        
          // test both cells of played dyadmino
        for (int i = 0; i < 2; i++) {
          HexCoord hexCoord = hexCoords[i];
          
            // compare against both cells of first dyadmino
          for (int j = 0; j < 2; j++) {
            HexCoord firstHexCoord = firstHexCoords[j];
            
            if (hexCoord.x == firstHexCoord.x && hexCoord.y == firstHexCoord.y) {
              expectedValidPhysicalPlacement = NO;
            }
          }
        }
        
        XCTAssertEqual(returnedValidPhysicalPlacement, expectedValidPhysicalPlacement, @"Match failed to recognize whether played dyadmino was stacked on first dyadmino.");
      }
    }
  }
}

-(void)testValidateLoneDyadminoWithFirstDyadmino {
  
    // same as stacked test, except compare against surrounding cells of surrounding cells
  
  [self setupGameForNumberOfPlayers:1];
  DataDyadmino *firstDataDyad = [self.myMatch dataDyadminoForIndex:[self.myMatch returnFirstDataDyadIndex]];
  
    // test with all possible orientations of first board dyadmino
  for (DyadminoOrientation firstOrient = kPC1atTwelveOClock; firstOrient <= kPC1atTenOClock; firstOrient++) {
    [self.myMatch moveBoardDataDyadmino:firstDataDyad toBottomHexCoord:firstDataDyad.myHexCoord withOrientation:firstOrient];
    
    NSSet *surroundingCellsOfBoardDyadmino = [self.myMatch testSurroundingCellsOfDyadminoBottomHexCoord:firstDataDyad.myHexCoord andOrientation:[firstDataDyad returnMyOrientation]];
    
    NSSet *surroundingCellsOfSurroundingCells = [self.myMatch testSurroundingCellsOfSurroundingCellsOfDyadminoBottomHexCoord:firstDataDyad.myHexCoord andOrientation:[firstDataDyad returnMyOrientation]];
    
    Player *currentPlayer = [self.myMatch returnCurrentPlayer];
    NSNumber *index = [currentPlayer.rackIndexes lastObject];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[index unsignedIntegerValue]];
    
    for (DataCell *surroundingCellOfSurroundingCell in surroundingCellsOfSurroundingCells) {
      for (DyadminoOrientation orientation = kPC1atTwelveOClock; orientation <= kPC1atTenOClock; orientation++) {
        BOOL returnedValidPhysicalPlacement = ([self.myMatch testValidatePhysicallyPlacingDyadminoID:[dataDyad returnMyID]
                                                                                     withOrientation:orientation
                                                                                    onBottomHexCoord:surroundingCellOfSurroundingCell.hexCoord] == kNoError);
        
        BOOL expectedValidPhysicalPlacement = NO;
        HexCoord bottomHexCoord = surroundingCellOfSurroundingCell.hexCoord;
        HexCoord topHexCoord = [self retrieveTopHexCoordForBottomHexCoord:bottomHexCoord andOrientation:orientation];
        HexCoord hexCoords[2] = {topHexCoord, bottomHexCoord};
        
          // test both cells of played dyadmino
        for (int i = 0; i < 2; i++) {
          HexCoord hexCoord = hexCoords[i];
          
            // compare against all cells of surrounding cells
          for (DataCell *dataCell in surroundingCellsOfBoardDyadmino) {
            if (dataCell.hexX == hexCoord.x && dataCell.hexY == hexCoord.y) {
              expectedValidPhysicalPlacement = YES;
            }
          }
        }
        
        XCTAssertEqual(returnedValidPhysicalPlacement, expectedValidPhysicalPlacement, @"Match failed to recognize whether played dyadmino was a lone dyadmino.");
      }
    }
  }
}

#pragma mark - sonority tests

-(void)testCollectionOfSonorities {
  
    // test 100 times
  for (int i = 0; i < 100; i++) {

    [self setupGameForNumberOfPlayers:1];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[self.myMatch returnFirstDataDyadIndex]];
    
    NSMutableSet *tempAllSet = [NSMutableSet new];
    
    NSSet *formationOfSonorities = [self.myMatch testSonoritiesFromPlacingDyadminoID:[dataDyad returnMyID]
                                                                    onBottomHexCoord:dataDyad.myHexCoord
                                                                     withOrientation:[dataDyad returnMyOrientation]];
    
    
    
    
  }
  
  
  XCTFail(@"Did not properly collect sonorities from placing dyadmino.");
}

-(void)testThatBrokenChordIsReturnedBeforeAnyOtherError {
  XCTFail();
}

-(void)testStrandedDyadminoMethod {
  
    // test 100 times
  for (int i = 0; i < 100; i++) {

    [self setupGameForNumberOfPlayers:1];
    DataDyadmino *firstDataDyad = [self.myMatch dataDyadminoForIndex:[self.myMatch returnFirstDataDyadIndex]];
    Player *currentPlayer = [self.myMatch returnCurrentPlayer];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[[currentPlayer.rackIndexes lastObject] unsignedIntegerValue]];

    NSSet *surroundingCellsOfBoardDyadmino = [self.myMatch testSurroundingCellsOfDyadminoBottomHexCoord:firstDataDyad.myHexCoord andOrientation:[firstDataDyad returnMyOrientation]];
    
//    BOOL played = NO;
//    while (!played) {
//      
//      
//      
//    }
    
    NSUInteger randomX = (3 + (arc4random() % 10)) * ((arc4random() % 2) ? 1 : -1);
    NSUInteger randomY = (3 + (arc4random() % 10)) * ((arc4random() % 2) ? 1 : -1);
    DyadminoOrientation randomOrientation = arc4random() % 6;

    HexCoord bottomHexCoord = [self hexCoordFromX:randomX andY:randomY];
    dataDyad.myHexCoord = bottomHexCoord;
    dataDyad.myOrientation = @(randomOrientation);

    [self.myMatch playDataDyadmino:dataDyad onBottomHexCoord:bottomHexCoord withOrientation:randomOrientation];
    BOOL strandedDyadminoes = [self.myMatch testStrandedDyadminoesAfterRemovingDataDyadmino:dataDyad];
    BOOL undoSuccessful = [self.myMatch undoLastPlayedDyadmino];

    if (strandedDyadminoes) {
      XCTAssertFalse(undoSuccessful, @"Undo should not be possible if it leaves dyadminoes stranded.");
    } else {
      XCTAssertTrue(undoSuccessful, @"Undo should be possible if it doesn't leave dyadminoes stranded.");
    }
  }
  
  
  XCTFail(@"Match failed to detect a stranded dyadmino.");
}

#pragma mark - score tests

-(void)testSumOfPointsThisTurn {
  XCTFail(@"Did not properly calculate sum of points this turn.");
}

-(void)testPointsForChordSonorities {
  XCTFail(@"Did not properly calculate points for chord sonority.");
}

#pragma mark - reset tests

-(void)testResettingOfBoardDyadminoes {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];

  }
  
  XCTFail(@"Board dyadminoes were not reset to pre-turn state.");
}

-(void)testThatPointsAreBackToZeroAfterReset {
  XCTFail(@"Turn points were not reset back to zero after board reset.");
}

-(void)testThatPassedTurnResetsBoardDyadminoes {
  XCTFail(@"Passed turn did not reset board dyadminoes.");
}

-(void)testBoardDyadminoesHaveMovedSinceStartOfTurnMethod {
  XCTFail(@"Did not note that board dyadminoes have moved since start of turn.");
}

#pragma mark - win tests

-(void)testWhoWon {
  
    // test 1 to 4 players
  for (int totalPlayers = 1; totalPlayers <= kMaxNumPlayers; totalPlayers++) {

    for (int j = 0; j < 256; j++) { // all combinations of scores for four players

      [self setupGameForNumberOfPlayers:totalPlayers];
      NSUInteger maxScore = 0;
      
      for (int index = 0; index < totalPlayers; index++) {
        Player *player = [self.myMatch playerForIndex:index];

          // player scores vary from 0 to 3
        
        NSUInteger playerScore;
        
        switch (index) {
          case 0:
            playerScore = j / 64;
            break;
          case 1:
            playerScore = (j / 16) % 4;
            break;
          case 2:
            playerScore = (j / 4) % 4;
            break;
          case 3:
            playerScore = j % 4;
            break;
        }
        
        player.score = @(playerScore);
        
        if (playerScore > maxScore) {
          maxScore = playerScore;
        }
      }

      [self.myMatch testEndGame];
      
      for (Player *player in self.myMatch.players) {
        if ([player returnScore] > 0 && [player returnScore] == maxScore) {
          XCTAssertTrue([player returnWon], @"Match does not correctly state that player won.");
        } else {
          XCTAssertFalse([player returnWon], @"Match does not correctly state that player lost.");
        }
      }
    }
  }
}

-(void)testResignedPlayerCannotWin {
  
  [self setupGameForNumberOfPlayers:4];
  for (int i = 0; i < 4; i++) {
    Player *player = [self.myMatch playerForIndex:i];
    
      // first player has highest score
    player.score = @(4 - i);
  }
  
  Player *firstPlayer = [self.myMatch playerForIndex:0];
  [self.myMatch resignPlayer:firstPlayer];
  [self.myMatch testEndGame];
  
  XCTAssertFalse([firstPlayer returnWon], @"Despite having highest score, first player cannot win because they resigned.");
}

-(void)testEndGameResultsText {
  XCTFail();
}

#pragma mark - additional setup methods

-(void)setupGameForNumberOfPlayers:(NSUInteger)numberOfPlayers {
  self.myMatch = [NSEntityDescription insertNewObjectForEntityForName:@"Match" inManagedObjectContext:self.myContext];
  
  NSMutableSet *tempSet = [NSMutableSet new];
  for (NSUInteger i = 0; i < numberOfPlayers; i++) {
    Player *newPlayer = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:self.myContext];
    [newPlayer initialUniqueID:@"" andName:self.playerNames[i] andOrder:i];
    [tempSet addObject:newPlayer];
  }
  NSSet *players = [NSSet setWithSet:tempSet];
  
  [self.myMatch initialPlayers:players andRules:kGameRulesTonal andSkill:kBeginner withContext:self.myContext forTest:NO];
  
  NSError *error = nil;
  if (![self.myContext save:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
}

-(void)playFullGameForNumberOfPlayers:(NSUInteger)numberOfPlayers {
  
  [self setupGameForNumberOfPlayers:numberOfPlayers];
  
  while (![self.myMatch returnGameHasEnded]) {
    Player *player = [self.myMatch returnCurrentPlayer];
    NSArray *dataDyadminoIndexes = (NSArray *)player.rackIndexes;
    
      // play random number of dyadminoes
    NSUInteger randomNumberToPlay = dataDyadminoIndexes.count;
    for (int i = 0; i < randomNumberToPlay; i++) {
      
      NSUInteger dataDyadminoIndex = [dataDyadminoIndexes[i] unsignedIntegerValue];
      DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:dataDyadminoIndex];
      
        // change coordinate and orientation (there's a chance it's the same as original)
      NSInteger randX = [self randomIntegerUpTo:20] - 10;
      NSInteger randY = [self randomIntegerUpTo:20] - 10;
      HexCoord movedCoord = [self hexCoordFromX:randX andY:randY];
      DyadminoOrientation movedOrientation = (DyadminoOrientation)[self randomIntegerUpTo:5];
      
      dataDyad.myHexCoord = movedCoord;
      dataDyad.myOrientation = [NSNumber numberWithUnsignedInteger:movedOrientation];
      [self.myMatch testAddToHoldingContainer:dataDyad];
    }

    [self.myMatch testRecordDyadminoesFromCurrentPlayerWithSwap:NO];
  }
}

#pragma mark - match helper tests

-(void)testPCForDyadminoIndex {
  
  [self setupGameForNumberOfPlayers:1];
  
  NSUInteger myID = 0;
  
  for (int pc1 = 0; pc1 < 12; pc1++) {
    for (int pc2 = 0; pc2 < 12; pc2++) {
      if (pc1 != pc2 && pc1 < pc2) {
        
        NSUInteger returnPC1 = [self.myMatch pcForDyadminoIndex:myID isPC1:YES];
        NSUInteger returnPC2 = [self.myMatch pcForDyadminoIndex:myID isPC1:NO];
        
        XCTAssertEqual(pc1, returnPC1, @"for dyadmino %lu, returned pc1 is %lu, expected pc1 is %i", (unsigned long)myID, (unsigned long)returnPC1, pc1);
        XCTAssertEqual(pc2, returnPC2, @"for dyadmino %lu, returned pc2 is %lu, expected pc2 is %i", (unsigned long)myID, (unsigned long)returnPC2, pc2);
        
        myID++;
      }
    }
  }
}

#pragma mark - test helper methods

-(NSArray *)arrayOfNumbersWithCount:(NSUInteger)count {
  NSMutableArray *numberArray = [NSMutableArray new];
  NSUInteger counter = 0;
  while (counter < count) {
    [numberArray addObject:[NSNumber numberWithUnsignedInteger:counter]];
    counter++;
  }
  return [NSArray arrayWithArray:numberArray];
}

-(NSArray *)powerSet:(NSArray *)array {
    // return the powerset of an array:
    // an array of all possible subarrays of the passed array

  if (array.count == 0) {
    return [NSArray arrayWithObject:@[]];
  }
  
    // get an object from the array and the array without that object
  id lastObject = [array lastObject];
  NSArray *arrayLessOne = [array subarrayWithRange:NSMakeRange(0, array.count - 1)];
  
    // compute the powerset of the array without that object using recursion
  NSArray *powerSetLessOne = [self powerSet:arrayLessOne];
  
    // powerset is the union of the powerSetLessOne and powerSetLessOne where
    // each element is unioned with the removed element
  NSMutableArray *powerSet = [NSMutableArray arrayWithArray:powerSetLessOne];
  
    // add the removed object to every element of the recursive power set
  for (NSArray *lessOneElement in powerSetLessOne) {
    [powerSet addObject:[lessOneElement arrayByAddingObject:lastObject]];
  }
  
  return [NSArray arrayWithArray:powerSet];
}

#pragma mark - test helper test methods

-(void)testPileRemovalMethod {
  
    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    for (int j = 0; j <= kPileCount - (i * kNumDyadminoesInRack) - 1; j++) {
      
      [self setupGameForNumberOfPlayers:i];
      
      NSUInteger beforePileCount = self.myMatch.pile.count;
      [self.myMatch removeFromPileNumberOfDataDyadminoes:j];
      NSUInteger afterPileCount = self.myMatch.pile.count;
      
      XCTAssertTrue(beforePileCount - afterPileCount == j, @"Incorrect number of dyadminoes removed.");
    }
  }
}

-(void)testPowerSetMethod {
  NSArray *array = @[@1, @2, @3, @4, @5, @6];
  NSArray *powerSet = [self powerSet:array];
  NSLog(@"power set is: %@", powerSet);
}

-(void)testNumberArrayMethod {
  NSArray *numberArray = [self arrayOfNumbersWithCount:6];
  NSLog(@"number array is: %@", numberArray);
}

-(void)testPlayFullGameTest {
  [self playFullGameForNumberOfPlayers:4];
}

@end