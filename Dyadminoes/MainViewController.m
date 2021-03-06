//
//  MainTableViewController.m
//  Dyadminoes
//
//  Created by Bennett Lin on 5/19/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "MyScene.h"
#import "MainViewController.h"
#import "NSObject+Helper.h"
#import "UIImage+colouredImage.h"

#import "MatchTableViewCell.h"
#import "SceneViewController.h"

#import "LocalGameViewController.h"
#import "HelpViewController.h"
#import "StoreViewController.h"
#import "RankViewController.h"
#import "SettingsViewController.h"
#import "AboutViewController.h"
#import "Match.h"
#import "Player.h"
#import "CellBackgroundView.h"

#define kTableViewXMargin (kIsIPhone ? 0.f : 60.f)
#define kMainTopBarHeight (kIsIPhone ? 64.f : 86.f)
#define kMainBottomBarHeight (kIsIPhone ? 60.f : 90.f)
#define kActivityIndicatorFrame (kIsIPhone ? 120.f : 150.f)
#define kTopBarPadding (kMainTopBarHeight / kBounceDivisor)
#define kBottomBarPadding (kMainBottomBarHeight / kBounceDivisor)

@interface MainViewController () <SceneViewDelegate, MatchCellDelegate, LocalGameDelegate>

@property (strong, nonatomic) MyScene *myScene;

@property (strong, nonatomic) Match *mostRecentMatch;
@property (strong, nonatomic) NSIndexPath *indexPathForMostRecentMatch;

@property (weak, nonatomic) IBOutlet UILabel *titleLogo; // make custom image eventually

@property (weak, nonatomic) IBOutlet UIView *topBar;
@property (weak, nonatomic) IBOutlet UIView *bottomBar;

@property (weak, nonatomic) IBOutlet UIButton *localGameButton;

@property (weak, nonatomic) IBOutlet UIButton *helpButton;
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;
@property (weak, nonatomic) IBOutlet UIButton *aboutButton;

@property (strong, nonatomic) NSArray *allButtons;
@property (strong, nonatomic) UIButton *highlightedBottomButton;

@property (strong, nonatomic) AboutViewController *aboutVC;
@property (strong, nonatomic) LocalGameViewController *localVC;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) UIView *backgroundView;

@property (nonatomic) BOOL backgroundShouldBeStill;

@end

@implementation MainViewController
@synthesize aboutVC = _aboutVC;
@synthesize localVC = _localVC;

-(void)viewDidLoad {
  [super viewDidLoad];
  
  [self insertImageBackground];
  [self insertGradientBackground];

  self.titleLogo.font = [UIFont fontWithName:kFontModern size:(kIsIPhone ? 30.f : 60.f)];
  self.titleLogo.text = @"Dyadminoes";
  self.titleLogo.textColor = [UIColor whiteColor];
  self.titleLogo.textAlignment = NSTextAlignmentCenter;
  
  self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paper_background.jpg"]];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.showsVerticalScrollIndicator = NO;
  
    // FIXME: set this in viewWillAppear, using natural screen width and height
  self.tableView.frame = CGRectMake(kTableViewXMargin, kMainTopBarHeight, self.screenWidth - kTableViewXMargin * 2, self.screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
  
  self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  self.activityIndicator.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.8f];
  self.activityIndicator.frame = CGRectMake(0, 0, kActivityIndicatorFrame, kActivityIndicatorFrame);
  self.activityIndicator.layer.cornerRadius = kCornerRadius;
  self.activityIndicator.clipsToBounds = YES;
  self.activityIndicator.center = self.view.center;
  [self.view addSubview:self.activityIndicator];
  
//  self.bottomBar.backgroundColor = kMainBarsColour;
  self.topBar.backgroundColor = [UIColor clearColor];
  
  [self addShadowToTableView];
//  [self addShadowToView:self.tableView upsideDown:NO];
  [self addShadowToView:self.bottomBar upsideDown:YES];
  
  self.aboutVC = [[AboutViewController alloc] init];
  
  self.tableView.delegate = self;
  self.tableView.dataSource = self;

      // Create and configure the scene
  self.myScene = [MyScene sharedMySceneWithSize:self.view.bounds.size];
  self.myScene.scaleMode = SKSceneScaleModeAspectFill;
  
  self.allButtons = @[self.localGameButton, self.helpButton, self.settingsButton, self.aboutButton];
  
  for (UIButton *button in self.allButtons) {
    button.titleLabel.font = [UIFont fontWithName:kFontModern size:(kIsIPhone ? 28 : 48)];
    button.tintColor = kMainButtonsColour;
  }

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];

  [self.localGameButton addTarget:self action:@selector(removeNewGameButtonAnimations) forControlEvents:UIControlEventTouchDown];
  [self.localGameButton addTarget:self action:@selector(determineNewGameButtonAnimation) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
}

#pragma mark - application active and background methods

-(void)didBecomeActive {
//  NSLog(@"did become active method called");
  [self startAnimatingBackground];
  [self resetView];
}

-(void)didEnterBackground {
//  NSLog(@"did enter background method called");
  [self stopAnimatingBackground];
  [self removeNewGameButtonAnimations];
}

-(void)startAnimatingBackground {
  self.backgroundShouldBeStill = NO;
  [self animateBackgroundViewFirstTime:YES];
}

-(void)stopAnimatingBackground {
  self.backgroundShouldBeStill = YES;
  [self.backgroundView.layer removeAllAnimations];
}

-(void)removeNewGameButtonAnimations {
  [self.localGameButton.layer removeAllAnimations];
}

#pragma mark - view methods

-(void)viewWillAppear:(BOOL)animated {
//  NSLog(@"view will appear method called");
  [super viewWillAppear:animated];
  
  [self resetView];
}

-(void)resetView {
  self.cellsShouldBeEditable = YES;
  
  [self resetActivityIndicator];
  
  self.titleLogo.frame = CGRectMake(0, 0, self.screenWidth, kMainTopBarHeight);
  self.titleLogo.center = CGPointMake(self.screenWidth / 2, kMainTopBarHeight / 2);
  
  self.tableView.transform = CGAffineTransformMakeScale(1.f, 1.f);
  self.tableView.alpha = 1.f;
  
  self.topBar.frame = CGRectMake(-kTopBarPadding, -kTopBarPadding, self.screenWidth + (2 * kTopBarPadding), kMainTopBarHeight + kTopBarPadding);
  
  self.bottomBar.frame = CGRectMake(-kBottomBarPadding, self.screenHeight - kMainBottomBarHeight, self.screenWidth + (2 * kBottomBarPadding), kMainBottomBarHeight + kBottomBarPadding);
  
  NSArray *buttons = @[self.localGameButton, self.helpButton, self.settingsButton, self.aboutButton];
  const CGFloat bottomBarXMargin = kIsIPhone ? 10.f : 20.f;
  const CGFloat paddingBetweenButtons = bottomBarXMargin;
  const CGFloat buttonWidth = (self.screenWidth - (bottomBarXMargin * 2) - (paddingBetweenButtons * 3)) / 4;
  
  for (int i = 0; i < buttons.count; i++) {
    
    CGFloat xOrigin = bottomBarXMargin + (buttonWidth * i) + (paddingBetweenButtons * i);
    UIButton *button = buttons[i];
    button.frame = CGRectMake(xOrigin, 0, buttonWidth, kMainBottomBarHeight * 0.5f);
    button.titleLabel.font = [UIFont fontWithName:kFontModern size:kMainBottomBarHeight * 0.5f];
    [button.titleLabel sizeToFit];
    button.center = CGPointMake(button.center.x, kMainBottomBarHeight / 2);
  }
  
//  [self addGradientToView:self.topBar WithColour:kMainBarsColour andUpsideDown:YES];
  [self addGradientToView:self.bottomBar WithColour:kMainBarsColour andUpsideDown:NO];
  
  self.tableView.frame = CGRectMake(kTableViewXMargin, kMainTopBarHeight, self.screenWidth - kTableViewXMargin * 2, self.screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
  
  [self determineNewGameButtonAnimation];
}

-(void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
//  __weak typeof(self) weakSelf = self;
//  
//  if (self.mostRecentMatch) {
//    dispatch_async(dispatch_get_main_queue(), ^{
//      [weakSelf.tableView scrollToRowAtIndexPath:weakSelf.indexPathForMostRecentMatch atScrollPosition:UITableViewScrollPositionTop animated:YES];
//    });
//  }
}

#pragma mark - Table view delegate and data source

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return self.fetchedResultsController.sections.count;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
  return [sectionInfo numberOfObjects];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return kCellRowHeight + kCellSeparatorBuffer;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  
  static NSString *CellIdentifier = @"matchCell";
  MatchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
  [self configureCell:cell atIndexPath:indexPath];
  
  return cell;
}

-(void)configureCell:(MatchTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {

  cell.delegate = self;
  
  Match *myMatch = [self.fetchedResultsController objectAtIndexPath:indexPath];
  cell.myMatch = myMatch;
  if (cell.myMatch == self.mostRecentMatch) {
    self.indexPathForMostRecentMatch = indexPath;
  }
  [cell setViewProperties];
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  MatchTableViewCell *matchCell = (MatchTableViewCell *)cell;
  [matchCell setViewProperties];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  Match *match = [self.fetchedResultsController objectAtIndexPath:indexPath];
  GameType type = [match returnType];
  return ([match returnGameHasEnded] || (type != kGCFriendGame && type != kGCRandomGame));
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    [self.managedObjectContext deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
    
    NSError *error = nil;
    if (![self.managedObjectContext save:&error]) {
      NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
      abort();
    }
  }
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
  return @"Remove game";
}

-(void)reloadTable {
  [self.tableView reloadData];
}

#pragma mark - Navigation

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  
  if ([segue.identifier isEqualToString:@"sceneSegue"]) {
    [self activityIndicatorStart:YES];
    
    SceneViewController *sceneVC = [segue destinationViewController];
    sceneVC.myScene = self.myScene;

      // sender is either match or tableViewCell
    [sender isKindOfClass:[Match class]] ?
        [self segue:segue ToMatch:sender withIndexPath:nil] :
        [self segue:segue ToMatch:nil withIndexPath:[self.tableView indexPathForCell:sender]];
  }
}

-(void)segue:(UIStoryboardSegue *)segue ToMatch:(Match *)match withIndexPath:(NSIndexPath *)indexPath {
  
    // match will be nil when sent from tableViewCell
  match = match ? match : [self.fetchedResultsController objectAtIndexPath:indexPath];;
  SceneViewController *sceneVC = [segue destinationViewController];
  sceneVC.managedObjectContext = self.managedObjectContext;
  sceneVC.myMatch = match;
  sceneVC.delegate = self;
}

-(void)backToParentViewWithAnimateRemoveVC:(BOOL)animateRemoveVC {
  
  if (!self.vcIsAnimating && self.childVC && self.overlayEnabled) {
    
    if (animateRemoveVC) {
      [self slideTopBarAndBottomBarOut:NO];
      [self scaleTableviewOut:NO];
      
    } else { // dismiss soloVC after starting new game
      [self performSelectorInBackground:@selector(removeChildViewController:) withObject:self.childVC];
    }
        
      // so that overlay doesn't register when user dismisses keyboard
  } else if (self.overlayEnabled) {
    (self.childVC == self.localVC) ? [self.localVC resignTextField:nil] : nil;
  }
  
  [super backToParentViewWithAnimateRemoveVC:animateRemoveVC];
}

-(void)presentChildViewController:(ChildViewController *)childVC {
  if (![self.darkOverlay superview]) {
    [self slideTopBarAndBottomBarOut:YES];
    [self scaleTableviewOut:YES];
  }
  
  [super presentChildViewController:childVC];
}

-(void)removeChildVCUponEnteringBackground {
  [super removeChildVCUponEnteringBackground];
  
  if (self.childVC) {
    self.topBar.frame = CGRectMake(0, 0, self.screenWidth, kMainTopBarHeight);
    self.bottomBar.frame = CGRectMake(0, self.screenHeight - kMainBottomBarHeight, self.screenWidth, kMainTopBarHeight);
    self.tableView.frame = CGRectMake(kTableViewXMargin, kMainTopBarHeight, self.screenWidth - kTableViewXMargin * 2, self.screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
  }
}

#pragma mark - view animation methods

-(void)fadeOverlayIn:(BOOL)fadeIn {
    // FIXME: this method overrides parent method for now, but can be more DRY
  __weak typeof(self) weakSelf = self;
  
  if (fadeIn) {
    
    CGFloat overlayAlpha = kIsIPhone ? 0.2f : 0.5f;
    weakSelf.darkOverlay.backgroundColor = [UIColor clearColor];
    [weakSelf.view insertSubview:self.darkOverlay belowSubview:weakSelf.activityIndicator]; // this part is different in superclass VC
    [UIView animateWithDuration:kViewControllerSpeed * 0.8f delay:0.f options:UIViewAnimationOptionCurveEaseInOut animations:^{
      weakSelf.darkOverlay.backgroundColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:overlayAlpha];
    } completion:nil];
    
  } else {
    
    [UIView animateWithDuration:kViewControllerSpeed * 0.7f delay:0.f options:UIViewAnimationOptionCurveEaseInOut animations:^{
      weakSelf.darkOverlay.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
      [weakSelf.darkOverlay removeFromSuperview];
    }];
  }
}

-(void)fadeOverlayOutWithNewMatch:(Match *)newMatch {
    // FIXME: trying to get overlay to fade out right when activity indicator starts
    // unfortunately, it's not working at the moment
    // if it doesn't work, then this doesn't need to be its own method
  
  __weak typeof(self) weakSelf = self;
  if (weakSelf.darkOverlay.superview == self.view) {
    [UIView animateWithDuration:kViewControllerSpeed * 0.7f delay:0.f options:UIViewAnimationOptionCurveEaseInOut animations:^{
      weakSelf.darkOverlay.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
      [weakSelf performSegueWithIdentifier:@"sceneSegue" sender:newMatch];
      [weakSelf.darkOverlay removeFromSuperview];
    }];
  }
}

-(void)slideTopBarAndBottomBarOut:(BOOL)out {
  
  if (out) { // slide out
    [self removeNewGameButtonAnimations];
  
    [self slideAnimateView:self.topBar toDestinationYPosition:-(kMainTopBarHeight + kTopBarPadding) durationConstant:kViewControllerSpeed];
    [self slideAnimateView:self.bottomBar toDestinationYPosition:self.screenHeight durationConstant:kViewControllerSpeed];
    
  } else { // slide in
    [self determineNewGameButtonAnimation];
    
    [self slideAnimateView:self.topBar toDestinationYPosition:-kTopBarPadding durationConstant:kViewControllerSpeed];
    [self slideAnimateView:self.bottomBar toDestinationYPosition:(self.screenHeight - kMainBottomBarHeight) durationConstant:kViewControllerSpeed];
  }
}

-(void)scaleTableviewOut:(BOOL)out {
  [self scaleAnimateView:self.tableView goOut:out durationConstant:kViewControllerSpeed];
}

-(void)activityIndicatorStart:(BOOL)start {
  if (start) {
    [NSThread detachNewThreadSelector:@selector(transitionToSceneAnimationNewThread:) toTarget:self withObject:nil];
    [self slideTopBarAndBottomBarOut:YES];
    [self scaleTableviewOut:YES];
  } else {
    [self resetActivityIndicator];
    [self resetDarkOverlay];
    [self stopAnimatingBackground];
  }
}

-(void)transitionToSceneAnimationNewThread:(id)data {
  self.activityIndicator.hidden = NO;
  [self.activityIndicator startAnimating];
}

-(void)resetActivityIndicator {
  [self.activityIndicator stopAnimating];
  self.activityIndicator.hidden = YES;
}

#pragma mark - button methods

-(void)determineNewGameButtonAnimation {
    // this method is called before view appears
    // and also after removing a match, if that was the only match
    // it is also called when top bar comes in
  
  id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[0];
  if ([sectionInfo numberOfObjects] == 0) {
    
    const CGFloat unit = 0.08f;
    const CGFloat degrees = 4;
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [UIView animateKeyframesWithDuration:18 * unit delay:0.f options: UIViewKeyframeAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction animations:^{
        
        [UIView addKeyframeWithRelativeStartTime:0 relativeDuration:1 / 18.f animations:^{
          weakSelf.localGameButton.transform = CGAffineTransformRotate(weakSelf.localGameButton.transform, [weakSelf getRadiansFromDegree:degrees]);
          weakSelf.localGameButton.transform = CGAffineTransformScale(weakSelf.localGameButton.transform, kDyadminoHoverResizeFactor, kDyadminoHoverResizeFactor);
        }];
        
        for (int i = 1; i <= 3; i++) {
          [UIView addKeyframeWithRelativeStartTime:(((i * 2) - 1) - 0.5f) / 18.f relativeDuration:1 / 18.f animations:^{
            weakSelf.localGameButton.transform = CGAffineTransformRotate(weakSelf.localGameButton.transform, [weakSelf getRadiansFromDegree:degrees * -2]);
          }];
          [UIView addKeyframeWithRelativeStartTime:((i * 2) - 0.5f) / 18.f relativeDuration:1 / 18.f animations:^{
            weakSelf.localGameButton.transform = CGAffineTransformRotate(weakSelf.localGameButton.transform, [weakSelf getRadiansFromDegree:degrees * 2]);
          }];
        }
        
        [UIView addKeyframeWithRelativeStartTime:6.5f / 18.f relativeDuration:1 / 18.f animations:^{
          weakSelf.localGameButton.transform = CGAffineTransformRotate(weakSelf.localGameButton.transform, [weakSelf getRadiansFromDegree:-degrees]);
          weakSelf.localGameButton.transform = CGAffineTransformScale(weakSelf.localGameButton.transform, 1 / kDyadminoHoverResizeFactor, 1 / kDyadminoHoverResizeFactor);
        }];
        
        [UIView addKeyframeWithRelativeStartTime:7.5f / 18.f relativeDuration:1 / 18.f animations:^{
        }];
        
      } completion:nil];
    });
  }
}

-(IBAction)menuButtonPressedIn:(id)sender {
}

-(IBAction)menuButtonLifted:(UIButton *)sender {
  
  ChildViewController *buttonVC;
  if (sender == self.helpButton) {
    buttonVC = self.helpVC;
  } else if (sender == self.settingsButton) {
    buttonVC = self.settingsVC;
  } else if (sender == self.aboutButton) {
    buttonVC = self.aboutVC;
  } else if (sender == self.localGameButton) {
    buttonVC = self.localVC;
  }

  if (!self.vcIsAnimating && self.childVC != buttonVC) {
    [self presentChildViewController:buttonVC];
  }
}

#pragma mark - match creation methods

-(void)startSelfOrPnPGameWithPlayerNames:(NSArray *)playerNames {
  
  [self backToParentViewWithAnimateRemoveVC:NO];
  
  Match *newMatch = [NSEntityDescription insertNewObjectForEntityForName:@"Match" inManagedObjectContext:self.managedObjectContext];
  
  NSMutableSet *tempSet = [NSMutableSet new];
  for (NSUInteger i = 0; i < playerNames.count; i++) {
    Player *newPlayer = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:self.managedObjectContext];
    [newPlayer initialUniqueID:@"" andName:playerNames[i] andOrder:i];
    [tempSet addObject:newPlayer];
  }
  NSSet *players = [NSSet setWithSet:tempSet];
  
  [newMatch initialPlayers:players andRules:kGameRulesTonal andSkill:kBeginner withContext:self.managedObjectContext forTest:NO];
  
  NSError *error = nil;
  if (![self.managedObjectContext save:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
  
  [self fadeOverlayOutWithNewMatch:newMatch];
}

#pragma mark - helper methods

-(void)addShadowToTableView {
  
  const CGFloat padding = 10.f;
  
  self.tableView.layer.masksToBounds = NO;
  self.tableView.layer.shadowColor = [UIColor blackColor].CGColor;
  self.tableView.layer.shadowOffset = CGSizeMake(0, 5);
  self.tableView.layer.shadowOpacity = 0.15f;
  self.tableView.layer.shadowRadius = 3.f;
  
  UIBezierPath *path = [UIBezierPath bezierPath];
  
  
    // top left, then top right, then bottom right, then bottom left
  [path moveToPoint:CGPointMake(-padding, -padding)];
  [path addLineToPoint:CGPointMake(CGRectGetWidth(self.tableView.frame) + padding, -padding)];
  [path addLineToPoint:CGPointMake(CGRectGetWidth(self.tableView.frame) + padding, CGRectGetHeight(self.tableView.frame) + padding)];
  [path addLineToPoint:CGPointMake(-padding, CGRectGetHeight(self.tableView.frame) + padding)];
  [path closePath];
  
  self.tableView.layer.shadowPath = path.CGPath;
}

#pragma mark - background view methods

-(void)animateBackgroundViewFirstTime:(BOOL)firstTime {
  
  __weak typeof(self) weakSelf = self;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if (firstTime) {
      [weakSelf.backgroundView.layer removeAllAnimations];
      weakSelf.backgroundView.frame = CGRectOffset(weakSelf.backgroundView.frame, -weakSelf.backgroundView.frame.size.width / 2, -weakSelf.backgroundView.frame.size.height / 2);
    }
    
    CGFloat seconds = 30;
    [UIView animateWithDuration:seconds delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionRepeat animations:^{
      weakSelf.backgroundView.frame = CGRectOffset(weakSelf.backgroundView.frame, weakSelf.backgroundView.frame.size.width / 2, weakSelf.backgroundView.frame.size.height / 2);
    } completion:^(BOOL finished) {
      
      if (finished) {
        weakSelf.backgroundView.frame = CGRectOffset(weakSelf.backgroundView.frame, -weakSelf.backgroundView.frame.size.width / 2, -weakSelf.backgroundView.frame.size.height / 2);
      }
    }];
  });
}

-(void)insertImageBackground {
  UIImage *backgroundImage = [UIImage imageNamed:@"BachMassBackgroundCropped"];
  
    // make sure that view size is even multiple of backgroundImage
  self.backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, backgroundImage.size.width * 4, backgroundImage.size.height * 4)];
  self.backgroundView.backgroundColor = [[UIColor colorWithPatternImage:backgroundImage] colorWithAlphaComponent:0.25f];
  self.backgroundView.center = CGPointMake(self.screenWidth, self.screenHeight);
  [self.view insertSubview:self.backgroundView belowSubview:self.tableView];
}

-(void)insertGradientBackground {
  
    // background gradient
  UIView *gradientView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.screenWidth, self.screenHeight)];
  
  UIColor *darkGradient;
  UIColor *lightGradient;
  
  darkGradient = [kScrollingBackgroundFade colorWithAlphaComponent:1.f];
  lightGradient = [kScrollingBackgroundFade colorWithAlphaComponent:0.5f];
  
  CAGradientLayer *gradientLayer = [CAGradientLayer layer];
  gradientLayer.frame = gradientView.frame;
  gradientLayer.colors = @[(id)darkGradient.CGColor, (id)lightGradient.CGColor, (id)lightGradient.CGColor, (id)darkGradient.CGColor];
  gradientLayer.startPoint = CGPointMake(0.3, 0.0);
  gradientLayer.endPoint = CGPointMake(0.7, 1.0);
  gradientLayer.locations = @[@0.f, @0.4f, @0.6f, @1.f];
  
  [gradientView.layer addSublayer:gradientLayer];
  gradientLayer.zPosition = -1;
  [self.view insertSubview:gradientView belowSubview:self.tableView];
}

#pragma mark - delegate methods

-(void)disableOverlay {
  self.overlayEnabled = NO;
}

-(void)enableOverlay {
  self.overlayEnabled = YES;
}

-(void)rememberMostRecentMatch:(Match *)match {
  self.mostRecentMatch = match;
}

#pragma mark - Fetched results controller

-(NSFetchedResultsController *)fetchedResultsController {
  if (_fetchedResultsController != nil) {
    return _fetchedResultsController;
  }
  
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Match" inManagedObjectContext:self.managedObjectContext];
  [fetchRequest setEntity:entity];
  
    // Set the batch size to a suitable number.
  [fetchRequest setFetchBatchSize:20];

    // sort first by whether game has ended, and then by lastPlayed date
  NSSortDescriptor *gameEndedSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"gameHasEnded" ascending:YES];
  NSSortDescriptor *lastPlayedSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastPlayed" ascending:YES];
  NSArray *sortDescriptors = @[gameEndedSortDescriptor, lastPlayedSortDescriptor];
  
  [fetchRequest setSortDescriptors:sortDescriptors];
  
  NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Match"];
  fetchedResultsController.delegate = self;
  self.fetchedResultsController = fetchedResultsController;
  
  NSError *error = nil;
  if (![self.fetchedResultsController performFetch:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
  
  return _fetchedResultsController;
}

-(void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView beginUpdates];
}

-(void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeDelete:
      [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
    default:
      return;
  }
}

-(void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
      atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
     newIndexPath:(NSIndexPath *)newIndexPath {
  
    // will not get called from scene
  if (self.cellsShouldBeEditable) {

    switch(type) {
      case NSFetchedResultsChangeInsert:
        [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
        break;
      case NSFetchedResultsChangeDelete:
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        break;
      case NSFetchedResultsChangeUpdate:
        [self configureCell:(MatchTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
        break;
      case NSFetchedResultsChangeMove:
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
        break;
    }
    
    [self determineNewGameButtonAnimation];
  }
}

-(void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView endUpdates];
}

#pragma mark - accessor methods


-(void)setAboutVC:(AboutViewController *)aboutVC {
  _aboutVC = aboutVC;
}

-(AboutViewController *)aboutVC {
  if (!_aboutVC) {
    _aboutVC = [[AboutViewController alloc] init];
  }
  return _aboutVC;
}


-(void)setLocalVC:(LocalGameViewController *)localVC {
  _localVC = localVC;
}

-(LocalGameViewController *)localVC {
  if (!_localVC) {
    _localVC = [self.storyboard instantiateViewControllerWithIdentifier:@"LocalViewController"];
    _localVC.delegate = self;
  }
  return _localVC;
}

-(void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  self.aboutVC = nil;
  self.localVC = nil;
}

@end
