//
//  PnPViewController.m
//  Dyadminoes
//
//  Created by Bennett Lin on 5/27/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "PnPViewController.h"

@interface PnPViewController ()

@property (weak, nonatomic) IBOutlet UIButton *startGameButton;

@end

@implementation PnPViewController

-(void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
}

-(void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

-(IBAction)startGameTapped:(id)sender {
  [self.delegate startPnPGame];
}

@end
