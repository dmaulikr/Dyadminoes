//
//  MainTableViewController.m
//  Dyadminoes
//
//  Created by Bennett Lin on 5/19/14.
//  Copyright (c) 2014 Bennett Lin. All rights reserved.
//

#import "MyScene.h"
#import "MainViewController.h"
//#import "Model.h"
#import "NSObject+Helper.h"
#import "MatchTableViewCell.h"
#import "SceneViewController.h"

#import "LocalGameViewController.h"
#import "HelpViewController.h"
#import "StoreViewController.h"
#import "RankViewController.h"
#import "OptionsViewController.h"
#import "AboutViewController.h"
#import "Match.h"
#import "Player.h"
#import "CellBackgroundView.h"
#import "UIImage+colouredImage.h"

#define kTableViewXMargin (kIsIPhone ? 0.f : 60.f)
#define kMainTopBarHeight (kIsIPhone ? 64.f : 86.f)
#define kMainBottomBarHeight (kIsIPhone ? 60.f : 90.f)
#define kActivityIndicatorFrame (kIsIPhone ? 120.f : 150.f)

#define kViewControllerSpeed 0.225f

@interface MainViewController () <SceneViewDelegate, MatchCellDelegate, LocalGameDelegate>

@property (strong, nonatomic) MyScene *myScene;
@property (strong, nonatomic) UIViewController *childVC;

//@property (strong, nonatomic) Model *myModel;
@property (strong, nonatomic) Match *mostRecentMatch;
@property (strong, nonatomic) NSIndexPath *indexPathForMostRecentMatch;

@property (weak, nonatomic) IBOutlet UILabel *titleLogo; // make custom image eventually

@property (weak, nonatomic) IBOutlet UIView *topBar;
@property (weak, nonatomic) IBOutlet UIView *bottomBar;

@property (weak, nonatomic) IBOutlet UIButton *localGameButton;
@property (weak, nonatomic) IBOutlet UIButton *helpButton;
@property (weak, nonatomic) IBOutlet UIButton *optionsButton;
@property (weak, nonatomic) IBOutlet UIButton *aboutButton;

@property (strong, nonatomic) NSArray *allButtons;

@property (strong, nonatomic) UIButton *highlightedBottomButton;
@property (strong, nonatomic) UIButton *darkOverlay;
@property (nonatomic) BOOL vcIsAnimating;

@property (strong, nonatomic) LocalGameViewController *localVC;
@property (strong, nonatomic) HelpViewController *helpVC;
@property (strong, nonatomic) OptionsViewController *optionsVC;
@property (strong, nonatomic) AboutViewController *aboutVC;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) UIView *backgroundView;

@property (nonatomic) BOOL backgroundShouldBeStill;

@end

@implementation MainViewController {
  CGFloat _screenWidth;
  CGFloat _screenHeight;
  BOOL _overlayEnabled;
}

-(void)viewDidLoad {
  
  [super viewDidLoad];
  
  _screenWidth = [UIScreen mainScreen].bounds.size.width;
  _screenHeight = [UIScreen mainScreen].bounds.size.height;
  
  [self insertImageBackground];
  [self insertGradientBackground];

  self.titleLogo.font = [UIFont fontWithName:kFontModern size:(kIsIPhone ? 30.f : 60.f)];
  self.titleLogo.attributedText = [self stringWithAccidentals:@"Dyadminoes C(#)/D(b)-F(#)/G(b)" fontSize:(kIsIPhone ? 30.f : 60.f)];
  self.titleLogo.frame = CGRectMake(20, 20, 768, 60);
  
  self.tableView.backgroundColor = [UIColor clearColor];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.showsVerticalScrollIndicator = NO;
  
    // FIXME: set this in viewWillAppear, using natural screen width and height
  self.tableView.frame = CGRectMake(kTableViewXMargin, kMainTopBarHeight, _screenWidth - kTableViewXMargin * 2, _screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
  
  self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  self.activityIndicator.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.8f];
  self.activityIndicator.frame = CGRectMake(0, 0, kActivityIndicatorFrame, kActivityIndicatorFrame);
  self.activityIndicator.layer.cornerRadius = kCornerRadius;
  self.activityIndicator.clipsToBounds = YES;
  self.activityIndicator.center = self.view.center;
  [self.view addSubview:self.activityIndicator];
  
  self.bottomBar.backgroundColor = kMainBarsColour;
  [self addGradientToView:self.bottomBar WithColour:kMainBarsColour andUpsideDown:NO];
  self.topBar.backgroundColor = kMainBarsColour;
  [self addGradientToView:self.topBar WithColour:kMainBarsColour andUpsideDown:YES];
  
  [self addShadowToView:self.topBar upsideDown:NO];
  [self addShadowToView:self.bottomBar upsideDown:YES];
  
  self.localVC = [self.storyboard instantiateViewControllerWithIdentifier:@"LocalViewController"];
  self.localVC.delegate = self;
  
  self.helpVC = [self.storyboard instantiateViewControllerWithIdentifier:@"HelpViewController"];
  self.helpVC.view.backgroundColor = [UIColor redColor];
  
  self.optionsVC = [self.storyboard instantiateViewControllerWithIdentifier:@"OptionsViewController"];
  self.optionsVC.view.backgroundColor = kPlayerGreen;
  
  self.aboutVC = [[AboutViewController alloc] init];
  self.aboutVC.view.backgroundColor = [UIColor blueColor];
  
  self.darkOverlay = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, _screenWidth, _screenHeight)];
  [self.darkOverlay addTarget:self action:@selector(backToMatches) forControlEvents:UIControlEventTouchDown];
  self.vcIsAnimating = NO;
  
  self.tableView.delegate = self;
  self.tableView.dataSource = self;

      // Create and configure the scene
  self.myScene = [MyScene sceneWithSize:self.view.bounds.size];
  self.myScene.scaleMode = SKSceneScaleModeAspectFill;
  
  self.allButtons = @[self.localGameButton, self.helpButton, self.optionsButton, self.aboutButton];
  
  for (UIButton *button in self.allButtons) {
    button.titleLabel.font = [UIFont fontWithName:kFontModern size:(kIsIPhone ? 28 : 48)];
    button.tintColor = kMainButtonsColour;
  }
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startAnimatingBackground) name:UIApplicationDidBecomeActiveNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopAnimatingBackground) name:UIApplicationWillResignActiveNotification object:nil];
  
//  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getModel) name:UIApplicationWillEnterForegroundNotification object:nil];
//  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveModel) name:UIApplicationDidEnterBackgroundNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeChildVCUponEnteringBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
//  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveModel) name:UIApplicationWillTerminateNotification object:nil];
}

-(void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [self resetActivityIndicatorAndDarkOverlay];
  self.topBar.frame = CGRectMake(0, 0, _screenWidth, kMainTopBarHeight);
  self.bottomBar.frame = CGRectMake(0, _screenHeight - kMainBottomBarHeight, _screenWidth, kMainTopBarHeight);
  self.tableView.frame = CGRectMake(kTableViewXMargin, kMainTopBarHeight, _screenWidth - kTableViewXMargin * 2, _screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
  
  _overlayEnabled = YES;
  
//  self.myModel = [Model getMyModel];
//  if (!self.myModel) {
//    self.myModel = [Model new];
//  }
//  
//  [self.myModel sortMyMatches];
//  [self.tableView reloadData];
}

-(void)viewDidAppear:(BOOL)animated {
  
  __weak typeof(self) weakSelf = self;
  
  if (self.mostRecentMatch) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [weakSelf.tableView scrollToRowAtIndexPath:weakSelf.indexPathForMostRecentMatch atScrollPosition:UITableViewScrollPositionTop animated:YES];
    });
  }
}

-(void)startAnimatingBackground {
  self.backgroundShouldBeStill = NO;
  [self animateBackgroundViewFirstTime:YES];
}

-(void)stopAnimatingBackground {
  self.backgroundShouldBeStill = YES;
  [self.backgroundView.layer removeAllAnimations];
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
    
//    Match *match = [self.fetchedResultsController objectAtIndexPath:indexPath];
//    [self.tableView beginUpdates];
//    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
//    [self removeMatch:match];
//    [self.tableView endUpdates];
  }
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
  return @"Remove game";
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
//  sceneVC.myModel = self.myModel;
  sceneVC.myMatch = match;
  sceneVC.delegate = self;
}

-(void)backToMatches {
  [self backToMatchesWithAnimateRemoveVC:NO];
}

-(void)backToMatchesWithAnimateRemoveVC:(BOOL)animateRemoveVC {
  
  if (!self.vcIsAnimating && self.childVC && _overlayEnabled) {
    
    if (!animateRemoveVC) {
      [self fadeOverlayIn:NO];
      [self slideInTopBarAndBottomBar];
      [self slideInTableview];
      [self removeChildViewController:self.childVC];
      
    } else { // dismiss soloVC after starting new game
      [self performSelectorInBackground:@selector(removeChildViewController:) withObject:self.childVC];
//      [self removeChildViewController:self.childVC];
    }

    self.childVC = nil;
    
      // so that overlay doesn't register when user dismisses keyboard
  } else if (!_overlayEnabled) {
    (self.childVC == self.localVC) ? [self.localVC resignTextField:nil] : nil;
  }
}

-(void)presentChildViewController:(UIViewController *)childVC {
  
  self.vcIsAnimating = YES;
  (self.childVC && self.childVC != childVC) ? [self removeChildViewController:self.childVC] : nil;
  
  self.childVC = childVC;
  if (![self.darkOverlay superview]) {
    [self fadeOverlayIn:YES];
    [self slideOutTopBarAndBottomBar];
    [self slideOutTableview];
  }
  
  CGFloat viewWidth = _screenWidth * 4 / 5;
  CGFloat viewHeight = kIsIPhone ? _screenHeight * 5 / 7 : _screenHeight * 4 / 5;
  
  childVC.view.frame = CGRectMake(0, 0, viewWidth, viewHeight);
  childVC.view.center = CGPointMake(self.view.center.x - _screenWidth, self.view.center.y);
  childVC.view.layer.cornerRadius = kCornerRadius;
  childVC.view.layer.masksToBounds = YES;

  [self.view addSubview:childVC.view];
  [self animatePresentVC:childVC];
}

-(void)animatePresentVC:(UIViewController *)childVC {
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseIn animations:^{
    childVC.view.center = self.view.center;
  } completion:^(BOOL finished) {
    self.vcIsAnimating = NO;
  }];
}

-(void)removeChildViewController:(UIViewController *)childVC {
  
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseOut animations:^{
    childVC.view.center = CGPointMake(self.view.center.x + _screenWidth, self.view.center.y);
  } completion:^(BOOL finished) {
    [childVC.view removeFromSuperview];
  }];
}

-(void)removeChildVCUponEnteringBackground {
  if (self.childVC) {
    self.darkOverlay.backgroundColor = [UIColor clearColor];
    [self.darkOverlay removeFromSuperview];
    _overlayEnabled = YES;
    
    self.topBar.frame = CGRectMake(0, 0, _screenWidth, kMainTopBarHeight);
    self.bottomBar.frame = CGRectMake(0, _screenHeight - kMainBottomBarHeight, _screenWidth, kMainTopBarHeight);
    self.tableView.frame = CGRectMake(kTableViewXMargin, kMainTopBarHeight, _screenWidth - kTableViewXMargin * 2, _screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
    [self.childVC.view removeFromSuperview];
    self.childVC = nil;
  }
}

#pragma mark - view animation methods

-(void)slideOutTopBarAndBottomBar {
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseOut animations:^{
    self.topBar.frame = CGRectMake(0, -kMainTopBarHeight, _screenWidth, kMainTopBarHeight);
  } completion:nil];
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseOut animations:^{
    self.bottomBar.frame = CGRectMake(0, _screenHeight, _screenWidth, kMainBottomBarHeight);
  } completion:nil];
}

-(void)slideInTopBarAndBottomBar {
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseIn animations:^{
    self.topBar.frame = CGRectMake(0, 0, _screenWidth, kMainTopBarHeight);
  } completion:nil];
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseIn animations:^{
    self.bottomBar.frame = CGRectMake(0, _screenHeight - kMainBottomBarHeight, _screenWidth, kMainTopBarHeight);
  } completion:nil];
}

-(void)slideOutTableview {
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.tableView.frame = CGRectMake(kTableViewXMargin, _screenHeight, _screenWidth - kTableViewXMargin * 2, _screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
  } completion:nil];
}

-(void)slideInTableview {
  [UIView animateWithDuration:kViewControllerSpeed delay:0.f options:UIViewAnimationOptionCurveEaseIn animations:^{
    self.tableView.frame = CGRectMake(kTableViewXMargin, kMainTopBarHeight, _screenWidth - kTableViewXMargin * 2, _screenHeight - kMainTopBarHeight - kMainBottomBarHeight);
  } completion:nil];
}

-(void)fadeOverlayIn:(BOOL)fadeIn {
  
  __weak typeof(self) weakSelf = self;
  
  if (fadeIn) {
    CGFloat overlayAlpha = kIsIPhone ? 0.2f : 0.5f;
    self.darkOverlay.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:self.darkOverlay belowSubview:self.activityIndicator];
    [UIView animateWithDuration:0.1f delay:0.f options:UIViewAnimationOptionCurveEaseInOut animations:^{
      self.darkOverlay.backgroundColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:overlayAlpha];
    } completion:nil];
  } else {
    [UIView animateWithDuration:0.1f delay:0.f options:UIViewAnimationOptionCurveEaseInOut animations:^{
      self.darkOverlay.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
      [weakSelf.darkOverlay removeFromSuperview];
    }];
  }
}

-(void)activityIndicatorStart:(BOOL)start {
  if (start) {
    [NSThread detachNewThreadSelector:@selector(transitionToSceneAnimationNewThread:) toTarget:self withObject:nil];
  } else {
    [self resetActivityIndicatorAndDarkOverlay];
    [self stopAnimatingBackground];
  }
}

-(void)transitionToSceneAnimationNewThread:(id)data {
  self.activityIndicator.hidden = NO;
  [self.activityIndicator startAnimating];
  [self slideOutTopBarAndBottomBar];
  [self slideOutTableview];
}

-(void)resetActivityIndicatorAndDarkOverlay {
  [self.activityIndicator stopAnimating];
  self.activityIndicator.hidden = YES;
  self.darkOverlay.backgroundColor = [UIColor clearColor];
  [self.darkOverlay removeFromSuperview];
}

#pragma mark - button methods

-(IBAction)menuButtonPressedIn:(id)sender {
//  NSLog(@"button pressed in");
}

-(IBAction)menuButtonLifted:(UIButton *)sender {
  UIViewController *buttonVC;
  if (sender == self.helpButton) {
    buttonVC = self.helpVC;
  } else if (sender == self.optionsButton) {
    buttonVC = self.optionsVC;
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

//-(void)getModel {
//  NSLog(@"getModel");
//  self.myModel = [Model getMyModel];
//}
//
//-(void)saveModel {
//  NSLog(@"saveModel");
//  [Model saveMyModel:self.myModel];
//}

-(void)startLocalGameWithPlayerNames:(NSArray *)playerNames {
  [self backToMatchesWithAnimateRemoveVC:YES];
  
//  Match *newMatch = [self.myModel instantiateNewLocalMatchWithNames:playerNames andRules:kGameRulesTonal andSkill:kBeginner];
  
  Match *newMatch = [NSEntityDescription insertNewObjectForEntityForName:@"Match" inManagedObjectContext:self.managedObjectContext];
  
  NSMutableSet *tempSet = [NSMutableSet new];
  for (NSUInteger i = 0; i < playerNames.count; i++) {
    Player *newPlayer = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:self.managedObjectContext];
    [newPlayer initialUniqueID:@"" andPlayerName:playerNames[i] andPlayerOrder:i];
    [tempSet addObject:newPlayer];
  }
  NSSet *players = [NSSet setWithSet:tempSet];
  
  [newMatch initialPlayers:players andRules:kGameRulesTonal andSkill:kBeginner withContext:self.managedObjectContext];
  
  NSError *error = nil;
  if (![self.managedObjectContext save:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
  
//  [self.tableView reloadData];
  [self performSegueWithIdentifier:@"sceneSegue" sender:newMatch];
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
  self.backgroundView.center = CGPointMake(_screenWidth, _screenHeight);
  [self.view insertSubview:self.backgroundView belowSubview:self.tableView];
}

-(void)insertGradientBackground {
  
    // background gradient
  UIView *gradientView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _screenWidth, _screenHeight)];
  
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
  _overlayEnabled = NO;
}

-(void)enableOverlay {
  _overlayEnabled = YES;
}

//-(void)removeMatch:(Match *)match {
//  [self.myModel.myMatches removeObject:match];
//  [self saveModel];
//}

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
}

-(void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
  [self.tableView endUpdates];
}

#pragma mark - system methods

-(BOOL)prefersStatusBarHidden {
  return YES;
}

-(void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  NSLog(@"matches VC did receive memory warning");
//  [Model saveMyModel:self.myModel];
}

-(void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
