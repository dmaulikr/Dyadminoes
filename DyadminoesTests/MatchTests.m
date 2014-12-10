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

@interface MatchTests : XCTestCase

@property (strong, nonatomic) NSManagedObjectContext *myContext;
@property (strong, nonatomic) Match *myMatch;
@property (strong, nonatomic) NSArray *playerNames;

@end

@implementation MatchTests

-(void)setUp {
  [super setUp];
  self.myContext = [TestHelper managedObjectContextForTests];
  self.playerNames = @[@"Bennett", @"Lauren", @"Julia", @"Mary"];
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
      NSArray *dataDyadminoIndexesThisTurn = (NSArray *)player.dataDyadminoIndexesThisTurn;
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
      NSArray *dataDyadminoIndexesThisTurn = (NSArray *)player.dataDyadminoIndexesThisTurn;
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

-(void)testPassEndsSelfGame {
  [self setupGameForNumberOfPlayers:1];
  [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
  XCTAssertTrue(self.myMatch.gameHasEnded, @"Game does not end after pass in self game.");
}

-(void)testPassesToNextPlayer {
  
    // test 2 to 4 players
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    NSInteger numberOfPlayers = self.myMatch.players.count;
    
      // test that passes to next player for each player
    for (int j = 1; j <= numberOfPlayers; j++) {
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnPlayerOrder];
      NSUInteger currentTurnCount = [(NSArray *)self.myMatch.turns count];
      
      [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
      
      Player *nextPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger nextPlayerIndex = [nextPlayer returnPlayerOrder];
      NSUInteger nextTurnCount = [(NSArray *)self.myMatch.turns count];
      
        // next player will be current player for solo game
      BOOL switchesCorrectlyToNextPlayer = ((nextPlayerIndex - currentPlayerIndex + numberOfPlayers) % numberOfPlayers) == 1;
      
      XCTAssertTrue(switchesCorrectlyToNextPlayer, @"Does not switch to next player correctly after pass.");
      XCTAssertTrue(nextTurnCount == currentTurnCount + 1, @"Pass did not add turn.");
    }
  }
}

-(void)testCorrectNumberOfPassesEndMatchForAllNumbersOfPlayers {
  
  // test 2 to 4 players, two rotations for dyadminoes left in pile
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];

     // pass this many times, up until the last turn before game ends
    for (int j = 0; j < 2 * i - 1; j++) {
     [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    }
    XCTAssertFalse([self.myMatch returnGameHasEnded], @"Game ended prematurely with dyadminoes left in pile.");

     // now pass once, and game should end
    [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game should have ended with dyadminoes left in pile.");
  }
  
    // test 2 to 4 players, one rotation for no dyadminoes left in pile
  for (int i = 2; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    [self.myMatch removeFromPileNumberOfDataDyadminoes:self.myMatch.pile.count];
    
      // pass this many times, up until the last turn before game ends
    for (int j = 0; j < i - 1; j++) {
      [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    }
    XCTAssertFalse([self.myMatch returnGameHasEnded], @"Game ended prematurely with no dyadminoes left in pile.");
    
      // now pass once, and game should end
    [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    XCTAssertTrue([self.myMatch returnGameHasEnded], @"Game should have ended with no dyadminoes left in pile.");
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
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnPlayerOrder];
      NSUInteger currentTurnCount = [(NSArray *)self.myMatch.turns count];
      
        // random data dyadmino
      NSUInteger randomDataDyadminoRackIndex = arc4random() % [(NSArray *)currentPlayer.dataDyadminoIndexesThisTurn count];
      NSNumber *randomDataDyadminoIndex = [(NSArray *)currentPlayer.dataDyadminoIndexesThisTurn objectAtIndex:randomDataDyadminoRackIndex];
      DataDyadmino *dataDyadmino = [self.myMatch dataDyadminoForIndex:[randomDataDyadminoIndex unsignedIntegerValue]];
      
      [self.myMatch addToSwapDataDyadmino:dataDyadmino];
      [self.myMatch swapDyadminoesFromCurrentPlayer];
      
      Player *nextPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger nextPlayerIndex = [nextPlayer returnPlayerOrder];
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
      
      [self setupGameForNumberOfPlayers:i];
      
      Player *player = [self.myMatch returnCurrentPlayer];
      NSArray *dataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;
      
      NSUInteger beforePileCount = self.myMatch.pile.count;
      NSUInteger beforeDataDyadminoIndexesCount = dataDyadminoIndexes.count;
      
      NSMutableArray *tempSwappedDataDyads = [NSMutableArray new];
      
      for (NSNumber *index in rackOrderArray) {
        NSUInteger rackOrderIndex = [index unsignedIntegerValue];
        NSUInteger dataDyadminoIndex = [dataDyadminoIndexes[rackOrderIndex] unsignedIntegerValue];
        DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:dataDyadminoIndex];
        [self.myMatch addToSwapDataDyadmino:dataDyad];
        [tempSwappedDataDyads addObject:dataDyad];
      }
      
      NSArray *swappedDataDyads = [NSArray arrayWithArray:tempSwappedDataDyads];
      
        // swapped!
      [self.myMatch swapDyadminoesFromCurrentPlayer];
      
      NSUInteger afterPileCount = self.myMatch.pile.count;
      NSUInteger afterDataDyadminoIndexesCount = [(NSArray *)player.dataDyadminoIndexesThisTurn count];
      
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
    NSMutableArray *tempSwappedDataDyadminoIndexes = [NSMutableArray new];
    Player *player = [self.myMatch returnCurrentPlayer];
    NSArray *dataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;
    
      // exchange all data dyadminoes in rack
    for (NSNumber *index in dataDyadminoIndexes) {
      DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[index unsignedIntegerValue]];
      [tempSwappedDataDyadminoIndexes addObject:index];
      [self.myMatch addToSwapDataDyadmino:dataDyad];
    }
    
    [self.myMatch swapDyadminoesFromCurrentPlayer];
    NSArray *postSwapDataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;

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
        NSUInteger numberToRemove = kPileCount - (i * kNumDyadminoesInRack) - 1 - k;
        [self.myMatch removeFromPileNumberOfDataDyadminoes:numberToRemove];
        
        Player *player = [self.myMatch returnCurrentPlayer];
        NSArray *dataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;
        
          // exchange data dyadminoes
        for (int l = 0; l < j; l++) {
          NSNumber *numberIndex = dataDyadminoIndexes[l];
          DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[numberIndex unsignedIntegerValue]];
          [self.myMatch addToSwapDataDyadmino:dataDyad];
        }
        
        BOOL dyadminoesShouldBeSwapped = (j > 0 && j <= k);
        BOOL dyadminoesWereSwapped = [self.myMatch swapDyadminoesFromCurrentPlayer];
        
        XCTAssertTrue(dyadminoesShouldBeSwapped == dyadminoesWereSwapped, @"Dyadminoes should have been swapped but weren't, or vice versa.");
      }
    }
  }
}

#pragma mark - resign tests

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
        [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
      
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnPlayerOrder];
      NSUInteger currentTurnCount = [(NSArray *)self.myMatch.turns count];
      
      [self.myMatch resignPlayer:currentPlayer];
      
      Player *nextPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger nextPlayerIndex = [nextPlayer returnPlayerOrder];
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
    NSArray *dataDyadminoIndexes = [NSArray arrayWithArray:(NSArray *)player.dataDyadminoIndexesThisTurn];
    
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
        [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
      
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger currentPlayerIndex = [currentPlayer returnPlayerOrder];
      
      [self.myMatch resignPlayer:currentPlayer];
      
        // pass to player before in next round
      for (int k = 0; k < i - 1; k++) {
        [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
      }
      
      Player *afterPlayer = [self.myMatch returnCurrentPlayer];
      NSInteger afterPlayerIndex = [afterPlayer returnPlayerOrder];

      BOOL afterPlayerComesAfter = ((afterPlayerIndex - currentPlayerIndex + i) % i) == 1;
      XCTAssertTrue(afterPlayerComesAfter, @"Resigned player is not skipped over in next round.");
    }
  }
}

#pragma mark - undo tests

-(void)testAddAndUndoDyadminoesToHoldingContainer {
  
  [self setupGameForNumberOfPlayers:1];
  
  Player *player = [self.myMatch returnCurrentPlayer];
  NSArray *dataDyadminoIndexes = [NSArray arrayWithArray:(NSArray *)player.dataDyadminoIndexesThisTurn];
  
    // add dyadminoes to holding container one by one, in sequential order
  for (int i = 0; i < kNumDyadminoesInRack; i++) {
    NSNumber *dataDyadIndex = dataDyadminoIndexes[i];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[dataDyadIndex unsignedIntegerValue]];
    [self.myMatch addToHoldingContainer:dataDyad];

    XCTAssertEqualObjects([self.myMatch.holdingIndexContainer lastObject], dataDyadIndex, @"Data dyadmino index was not added to holding container.");
    XCTAssertTrue([self.myMatch.holdingIndexContainer count] == i + 1, @"Holding container count is incorrect for added dyadmino.");
  }
  
    // undo dyadminoes in holding container one by one, in reverse order
  for (int i = kNumDyadminoesInRack - 1; i >= 0; i--) {
    
    NSNumber *dataDyadIndex = dataDyadminoIndexes[i];
    XCTAssertEqualObjects([self.myMatch.holdingIndexContainer lastObject], dataDyadIndex, @"Data dyadmino index was not removed from holding container after last undo.");
    
    [self.myMatch undoDyadminoToHoldingContainer];
    
    XCTAssertTrue([self.myMatch.holdingIndexContainer count] == i, @"Holding container count is incorrect after undo.");
  }
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
        NSArray *dataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;
        
        NSUInteger beforePileCount = self.myMatch.pile.count;
        NSUInteger beforeDataDyadminoIndexesCount = dataDyadminoIndexes.count;
        
        NSMutableArray *tempPlayedDataDyads = [NSMutableArray new];
        
        for (NSNumber *index in rackOrderArray) {
          NSUInteger rackOrderIndex = [index unsignedIntegerValue];
          NSUInteger dataDyadminoIndex = [dataDyadminoIndexes[rackOrderIndex] unsignedIntegerValue];
          DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:dataDyadminoIndex];
          [self.myMatch addToHoldingContainer:dataDyad];
          [tempPlayedDataDyads addObject:dataDyad];
        }
        
        NSArray *playedDataDyads = [NSArray arrayWithArray:tempPlayedDataDyads];
        
          // played!
        [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
        
        NSUInteger afterPileCount = self.myMatch.pile.count;
        NSUInteger afterDataDyadminoIndexesCount = [(NSArray *)player.dataDyadminoIndexesThisTurn count];
        
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
        NSArray *dataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;
        
        NSUInteger numberToRemove = kPileCount - (i * kNumDyadminoesInRack) - 1 - k;
        [self.myMatch removeFromPileNumberOfDataDyadminoes:numberToRemove];
        
          // play data dyadminoes
        for (int l = 0; l < j; l++) {
          NSNumber *numberIndex = dataDyadminoIndexes[l];
          DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:[numberIndex unsignedIntegerValue]];
          [self.myMatch addToHoldingContainer:dataDyad];
        }
        
        [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
        
        NSUInteger rackCount = [(NSArray *)player.dataDyadminoIndexesThisTurn count];
        
        BOOL pileIsEmptyAndPlayerRackLessThanFullIfMoreDyadminoesPlayedThanLeftInPile = YES;
        
          // number left in pile is less than number played
        if (k < j) {
          if (rackCount == kNumDyadminoesInRack || self.myMatch.pile.count > 0) {
            pileIsEmptyAndPlayerRackLessThanFullIfMoreDyadminoesPlayedThanLeftInPile = NO;
          }
        }
        
        XCTAssertTrue(pileIsEmptyAndPlayerRackLessThanFullIfMoreDyadminoesPlayedThanLeftInPile, @"Pile should be empty and player rack less than full if more dyadminoes were played than there were dyadminoes left in pile.");
        
          // none left in pile or rack, game should end
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
      [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
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
      
      NSUInteger expectedPlayerOrder = [[self.myMatch currentPlayerIndex] unsignedIntegerValue];
      [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
      
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
    
    [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    
    NSDictionary *turn = [(NSArray *)self.myMatch.turns lastObject];
    id indexContainer = [turn objectForKey:@"indexContainer"];
    XCTAssertTrue([indexContainer isKindOfClass:[NSArray class]], @"Index container is not an array.");
    
    NSArray *indexContainerArray = (NSArray *)indexContainer;
    XCTAssertTrue(indexContainerArray.count == 0, @"Index container is not empty for pass.");
  }
}

-(void)testTurnForSwapIsRecordedLikePass {

    // test 1 to 4 players
  for (int i = 1; i <= kMaxNumPlayers; i++) {
    [self setupGameForNumberOfPlayers:i];
    NSInteger numberOfPlayers = self.myMatch.players.count;
    
      // swap needs to have a data dyadmino in
    for (int j = 1; j <= numberOfPlayers; j++) {
      Player *currentPlayer = [self.myMatch returnCurrentPlayer];
      
        // random data dyadmino
      NSUInteger randomDataDyadminoRackIndex = arc4random() % [(NSArray *)currentPlayer.dataDyadminoIndexesThisTurn count];
      NSNumber *randomDataDyadminoIndex = [(NSArray *)currentPlayer.dataDyadminoIndexesThisTurn objectAtIndex:randomDataDyadminoRackIndex];
      DataDyadmino *dataDyadmino = [self.myMatch dataDyadminoForIndex:[randomDataDyadminoIndex unsignedIntegerValue]];
      
      [self.myMatch addToSwapDataDyadmino:dataDyadmino];
      [self.myMatch swapDyadminoesFromCurrentPlayer];
      
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
        [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
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
  [self.myMatch persistChangedPositionForBoardDataDyadmino:firstDataDyad];
  [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
  
  [self.myMatch persistChangedPositionForBoardDataDyadmino:firstDataDyad];
  [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];

  [self.myMatch persistChangedPositionForBoardDataDyadmino:firstDataDyad];
  [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
  
    // should only have one turn change, which records its initial placement
  XCTAssertTrue([(NSArray *)firstDataDyad.turnChanges count] == 1, @"Extra turn change should not have been added.");
}

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
    [self.myMatch persistChangedPositionForBoardDataDyadmino:firstDataDyad];
    [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    
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
    
      [self.myMatch persistChangedPositionForBoardDataDyadmino:firstDataDyad];
      [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    
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
    NSArray *dataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;
    
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
    
    [self.myMatch addToHoldingContainer:dataDyad];
    [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    [self.myMatch persistChangedPositionForBoardDataDyadmino:dataDyad];

    NSDictionary *turnChange = (NSDictionary *)[(NSArray *)dataDyad.turnChanges lastObject];
    
      // if coordinate is different
    if (originalCoord.x != movedCoord.x || originalCoord.y != movedCoord.y) {
      NSInteger returnedX = [[turnChange valueForKey:@"hexX"] integerValue];
      NSInteger returnedY = [[turnChange valueForKey:@"hexY"] integerValue];
      
      XCTAssertEqual(movedCoord.x, returnedX, @"X value not as expected.");
      XCTAssertEqual(movedCoord.y, returnedY, @"Y value not as expected.");
    } else {
      XCTAssertNil([turnChange valueForKey:@"hexX"], @"Should not have object for hexX key.");
      XCTAssertNil([turnChange valueForKey:@"hexY"], @"Should not have object for hexY key.");
    }
    
      // orientation in rack will be different, so object for key will always exist
    DyadminoOrientation returnedOrientation = (DyadminoOrientation)[[turnChange valueForKey:@"orientation"] unsignedIntegerValue];
    XCTAssertEqual(movedOrientation, returnedOrientation, @"Orientation value not as expected.");
    XCTAssertNotNil([turnChange valueForKey:@"orientation"], @"Object for orientation key should not be nil.");

  }
}

#pragma mark - replay tests




#pragma mark - match game end tests

#pragma mark - win tests

#pragma mark - score tests

#pragma mark - persistence tests

#pragma mark - additional setup methods

-(void)setupGameForNumberOfPlayers:(NSUInteger)numberOfPlayers {
  self.myMatch = [NSEntityDescription insertNewObjectForEntityForName:@"Match" inManagedObjectContext:self.myContext];
  
  NSMutableSet *tempSet = [NSMutableSet new];
  for (NSUInteger i = 0; i < numberOfPlayers; i++) {
    Player *newPlayer = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:self.myContext];
    [newPlayer initialUniqueID:@"" andPlayerName:self.playerNames[i] andPlayerOrder:i];
    [tempSet addObject:newPlayer];
  }
  NSSet *players = [NSSet setWithSet:tempSet];
  
  [self.myMatch initialPlayers:players andRules:kGameRulesTonal andSkill:kBeginner withContext:self.myContext];
  
  NSError *error = nil;
  if (![self.myContext save:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
}

-(void)playFullGameOfOneDyadminoPerPlayForNumberOfPlayers:(NSUInteger)numberOfPlayers {
  
  [self setupGameForNumberOfPlayers:numberOfPlayers];
  
  while (![self.myMatch returnGameHasEnded]) {
    Player *player = [self.myMatch returnCurrentPlayer];
    NSArray *dataDyadminoIndexes = (NSArray *)player.dataDyadminoIndexesThisTurn;
    
      // play first dyadmino
    NSUInteger dataDyadminoIndex = [dataDyadminoIndexes[0] unsignedIntegerValue];
    DataDyadmino *dataDyad = [self.myMatch dataDyadminoForIndex:dataDyadminoIndex];
    
      // change coordinate and orientation (there's a chance it's the same as original)
    NSInteger randX = [self randomIntegerUpTo:20] - 10;
    NSInteger randY = [self randomIntegerUpTo:20] - 10;
    HexCoord movedCoord = [self hexCoordFromX:randX andY:randY];
    DyadminoOrientation movedOrientation = (DyadminoOrientation)[self randomIntegerUpTo:5];
    
    dataDyad.myHexCoord = movedCoord;
    dataDyad.myOrientation = [NSNumber numberWithUnsignedInteger:movedOrientation];
    
    [self.myMatch addToHoldingContainer:dataDyad];
    [self.myMatch recordDyadminoesFromCurrentPlayerWithSwap:NO];
    [self.myMatch persistChangedPositionForBoardDataDyadmino:dataDyad];
  }
}

#pragma mark - helper methods

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

#pragma mark - helper test methods

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
  [self playFullGameOfOneDyadminoPerPlayForNumberOfPlayers:4];
}

@end