//
//  HelpContentViewController.h
//  Dyadminoes
//
//  Created by Bennett Lin on 5/28/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChildViewController.h"

@interface HelpContentViewController : UIViewController

//@property (weak, nonatomic) IBOutlet UIImageView *backgroundImageView;
//@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (strong, nonatomic) UIScrollView *scrollView;

@property (assign, nonatomic) NSUInteger pageIndex;
@property (strong, nonatomic) NSString *titleText;
@property (strong, nonatomic) NSString *imageFile;

-(NSString *)titleTextBasedOnPageIndex;

@end
