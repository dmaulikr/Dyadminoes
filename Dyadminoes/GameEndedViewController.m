//
//  GameEndedViewController.m
//  Dyadminoes
//
//  Created by Bennett Lin on 8/20/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "GameEndedViewController.h"

@interface GameEndedViewController ()

@end

@implementation GameEndedViewController

-(void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = kEndedMatchCellDarkColour;
  self.startingQuadrant = kQuadrantCenter;
  
}

-(void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

-(void)dealloc {
  NSLog(@"Game Ended VC deallocated.");
}

@end
