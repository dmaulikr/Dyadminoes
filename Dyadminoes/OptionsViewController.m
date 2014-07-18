//
//  OptionsViewController.m
//  Dyadminoes
//
//  Created by Bennett Lin on 5/27/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "OptionsViewController.h"

@interface OptionsViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *showPivotGuideSwitch;
@property (weak, nonatomic) IBOutlet UISegmentedControl *notationControl;
@property (weak, nonatomic) IBOutlet UISlider *musicSlider;
@property (weak, nonatomic) IBOutlet UISlider *soundEffectsSlider;

@property (weak, nonatomic) IBOutlet UIButton *removeDefaultsButton;

@property (strong, nonatomic) NSUserDefaults *defaults;

@end

@implementation OptionsViewController

-(void)viewDidLoad {
  [super viewDidLoad];
  
//  [self.showPivotGuideSwitch addTarget:self action:@selector(pivotGuideSwitched) forControlEvents:UIControlEventValueChanged];
  
  self.defaults = [NSUserDefaults standardUserDefaults];
}

-(void)viewWillAppear:(BOOL)animated {
  
    // if first time setting values...
  if (![self.defaults objectForKey:@"pivotGuide"]) {
    [self.defaults setBool:YES forKey:@"pivotGuide"];
    [self.defaults synchronize];
  }
  [self.showPivotGuideSwitch setOn:[self.defaults boolForKey:@"pivotGuide"] animated:NO];
  
  if (![self.defaults objectForKey:@"notation"]) {
    [self.defaults setInteger:0 forKey:@"notation"];
    [self.defaults synchronize];
  }
  self.notationControl.selectedSegmentIndex = [self.defaults integerForKey:@"notation"];
  
  if (![self.defaults objectForKey:@"music"]) {
    [self.defaults setFloat:0.5f forKey:@"music"];
    [self.defaults synchronize];
  }
  [self.musicSlider setValue:[self.defaults floatForKey:@"music"]];
  
  if (![self.defaults objectForKey:@"soundEffects"]) {
    [self.defaults setFloat:0.5f forKey:@"soundEffects"];
    [self.defaults synchronize];
  }
  [self.soundEffectsSlider setValue:[self.defaults floatForKey:@"soundEffects"]];
}

-(IBAction)pivotGuideSwitched {
  [self.defaults setBool:self.showPivotGuideSwitch.isOn forKey:@"pivotGuide"];
  [self.defaults synchronize];
}

-(IBAction)notationChanged:(UISegmentedControl *)sender {
  NSLog(@"selected segment is %li", (long)sender.selectedSegmentIndex);
  [self.defaults setInteger:sender.selectedSegmentIndex forKey:@"notation"];
  [self.defaults synchronize];
}

-(IBAction)musicSliderChanged:(UISlider *)sender {
  NSLog(@"slider value is %.2f", sender.value);
  [self.defaults setFloat:sender.value forKey:@"music"];
  [self.defaults synchronize];
}

-(IBAction)soundEffectsSliderChanged:(UISlider *)sender {
  NSLog(@"slider value is %.2f", sender.value);
  [self.defaults setFloat:sender.value forKey:@"soundEffects"];
  [self.defaults synchronize];
}

-(IBAction)removeDefaultsTapped:(UIButton *)sender {
  [self.defaults removeObjectForKey:@"pivotGuide"];
  [self.defaults removeObjectForKey:@"notation"];
  [self.defaults removeObjectForKey:@"music"];
  [self.defaults removeObjectForKey:@"soundEffects"];
  [self.defaults synchronize];
  
  [self.showPivotGuideSwitch setOn:YES animated:NO];
  self.notationControl.selectedSegmentIndex = 0;
  [self.soundEffectsSlider setValue:0.5f];
  [self.musicSlider setValue:0.5f];
}




@end
