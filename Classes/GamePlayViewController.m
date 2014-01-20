/*
 Nestopia for iOS
 Copyright (c) 2013, Jonathan A. Zdziarski
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */

#import <Foundation/NSFileManager.h>

#import "GamePlayViewController.h"
#import "NestopiaAppDelegate.h"
#import "NestopiaCore.h"
#import "AudioPlayer.h"
#import "ScreenView.h"
#import "SettingsViewController.h"
#import "PadDirectionButton.h"
#import "PadSingleButton.h"
#import "PadRoundTextButton.h"
#import "RoundTextMaskView.h"


@interface GamePlayViewController () <UIActionSheetDelegate, NestopiaCoreInputDelegate>

@property (nonatomic, strong) Game *game;
@property (nonatomic, assign) BOOL shouldLoadState;

@property (nonatomic, strong) ScreenView *screenView;
@property (nonatomic, strong) UIView *buttonsView;
@property (nonatomic, strong) PadDirectionButton *directionButton;
@property (nonatomic, strong) PadRoundTextButton *aButton;
@property (nonatomic, strong) PadRoundTextButton *bButton;
@property (nonatomic, strong) PadRoundTextButton *selectButton;
@property (nonatomic, strong) PadRoundTextButton *startButton;
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) RoundTextMaskView *menuMaskView;
@property (nonatomic, strong) UIActionSheet *saveStateSheet;
@property (nonatomic, strong) NestopiaCore *nestopiaCore;

@end


@implementation GamePlayViewController {
    bool pad1;
    
    AudioPlayer *audioPlayer;
    
    GameControllerManager *gameControllerManager;
}

#pragma mark Init

- (id)initWithGame:(Game *)game loadState:(BOOL)loadState {
    if ((self = [super init])) {
        _game = game;
        _shouldLoadState = loadState;
        
        self.title = self.game.title;
        
        [self setupEmulator];
        
        gameControllerManager = [GameControllerManager sharedInstance];
        gameControllerManager.delegate = self;
    }
    return self;
}

- (void)setupEmulator {
    _nestopiaCore = [NestopiaCore sharedCore];
    
    _nestopiaCore.gamePath = self.game.path;
    _nestopiaCore.gameSavePath = self.game.savePath;
    BOOL success = [_nestopiaCore powerOn];
	
    NSLog(@"%s loading image at path %@", __PRETTY_FUNCTION__, self.game.path);
    
	if (!success) {
        UIAlertView *myAlert = [[UIAlertView alloc]
								initWithTitle:@"Unable to Load Game ROM"
								message: @"There was an error loading the selected game image."
								delegate: self
								cancelButtonTitle: nil
								otherButtonTitles: @"OK", nil];
		[myAlert show];
		return;
	}
    
	if (self.shouldLoadState) {
		[_nestopiaCore loadState];
	}
    
    audioPlayer = [[AudioPlayer alloc] init];
    _nestopiaCore.audioDelegate = audioPlayer;
    
    _nestopiaCore.inputDelegate = self;
    
    pad1 = YES;
}

- (void)updateGameGenieCodes {
    if ([[self.game.settings objectForKey:@"gameGenie"] boolValue]) {
        NSMutableArray *gameGenieCodes = [NSMutableArray array];
        for (int i = 0; i < 4; i++) {
            NSString *code = [self.game.settings objectForKey:[NSString stringWithFormat: @"gameGenieCode%d", i]];
            if (code) {
                [gameGenieCodes addObject:code];
            }
        }
        
        _nestopiaCore.gameGenieCodes = gameGenieCodes;
    } else {
        _nestopiaCore.gameGenieCodes = nil;
    }
}

#pragma mark - Dealloc

- (void)dealloc {
    [_nestopiaCore powerOff];
}

#pragma mark - Life cycle

- (void)loadView {
    [super loadView];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.screenView = [[ScreenView alloc] init];
    self.screenView.antialiasing = [[self.game.settings objectForKey:@"antiAliasing"] boolValue];
    _nestopiaCore.videoDelegate = self.screenView;
    [self.view addSubview:self.screenView];
    
    self.buttonsView = [[UIView alloc] init];
    self.buttonsView.alpha = 0.3;
    [self.view addSubview:self.buttonsView];
    
    self.directionButton = [[PadDirectionButton alloc] init];
    //self.directionButton.stickControl = [[self.game.settings objectForKey:@"controllerStickControl"] boolValue];
	[self.buttonsView addSubview:self.directionButton];
    
    UIFont *abButtonFont = [self abButtonFont];
    UIFont *specialButtonFont = [self specialButtonFont];
    
    self.aButton = [[PadRoundTextButton alloc] init];
    self.aButton.singleInput = NestopiaPadInputA;
    self.aButton.font = abButtonFont;
    self.aButton.text = @"A";
    [self.buttonsView addSubview:self.aButton];
    
    self.bButton = [[PadRoundTextButton alloc] init];
    self.bButton.singleInput = NestopiaPadInputB;
    self.bButton.font = abButtonFont;
    self.bButton.text = @"B";
    [self.buttonsView addSubview:self.bButton];
    
    BOOL swapAB = [[self.game.settings objectForKey:@"swapAB"] boolValue];
    if (swapAB) {
        id temp = self.aButton;
        self.aButton = self.bButton;
        self.bButton = temp;
    }
    gameControllerManager.swapAB = swapAB;
    
    self.selectButton = [[PadRoundTextButton alloc] init];
    self.selectButton.singleInput = NestopiaPadInputSelect;
    self.selectButton.font = specialButtonFont;
    self.selectButton.text = @"Select";
    [self.buttonsView addSubview:self.selectButton];
    
    self.startButton = [[PadRoundTextButton alloc] init];
    self.startButton.singleInput = NestopiaPadInputStart;
    self.startButton.font = specialButtonFont;
    self.startButton.text = @"Start";
    [self.buttonsView addSubview:self.startButton];
    
    self.menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.menuButton addTarget:self action:@selector(menuButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.buttonsView addSubview:self.menuButton];
    
    self.menuMaskView = [[RoundTextMaskView alloc] init];
    self.menuMaskView.userInteractionEnabled = NO;
    self.menuMaskView.text = @"Menu";
    self.menuMaskView.font = specialButtonFont;
    self.menuMaskView.color = [UIColor redColor];
    [self.menuButton addSubview:self.menuMaskView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self setButtonsHiddenForGamepad:gameControllerManager.isGameControllerConnected];
    
    if (gameControllerManager.isGameControllerConnected) {
        [self setupGameControllerPauseHandler];
    }

    [self updateGameGenieCodes];
    [_nestopiaCore startEmulation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_nestopiaCore stopEmulation];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.screenView.frame = [self frameForScreenView];
    
    self.buttonsView.frame = self.view.bounds;
    
    CGFloat directionButtonRadius = [self directionButtonRadius];
    CGFloat abButtonRadius = [self abButtonRadius];
    CGFloat specialButtonRadius = [self specialButtonRadius];
    CGFloat top = [self respondsToSelector:@selector(topLayoutGuide)] ? [self.topLayoutGuide length] : 0;
    
    CGFloat padLayoutBaseLine;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        padLayoutBaseLine = CGRectGetMaxY(self.view.bounds) - directionButtonRadius - 5;
    } else {
        padLayoutBaseLine = CGRectGetMaxY(self.view.bounds) - 300;
    }
    
    CGFloat specialButtonIndent;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        specialButtonIndent = 5;
    } else {
        specialButtonIndent = 25;
    }
    
    self.directionButton.bounds = CGRectMake(0, 0, 2*directionButtonRadius, 2*directionButtonRadius);
    self.aButton.bounds = CGRectMake(0, 0, 2*abButtonRadius, 2*abButtonRadius);
    self.bButton.bounds = CGRectMake(0, 0, 2*abButtonRadius, 2*abButtonRadius);
    self.selectButton.bounds = CGRectMake(0, 0, 2*specialButtonRadius, 2*specialButtonRadius);
    self.startButton.bounds = CGRectMake(0, 0, 2*specialButtonRadius, 2*specialButtonRadius);
    
    self.directionButton.center = CGPointMake(directionButtonRadius + 5, padLayoutBaseLine);
    self.aButton.center = CGPointMake(CGRectGetMaxX(self.view.bounds) - abButtonRadius - 5, padLayoutBaseLine - 20);
    self.bButton.center = CGPointMake(CGRectGetMaxX(self.view.bounds) - 3*abButtonRadius - 15, padLayoutBaseLine + 20);
    self.selectButton.center = CGPointMake(specialButtonRadius + 5, padLayoutBaseLine - directionButtonRadius - specialButtonRadius - specialButtonIndent);
    self.startButton.center = CGPointMake(CGRectGetMaxX(self.view.bounds) - specialButtonRadius - 5, padLayoutBaseLine - directionButtonRadius - specialButtonRadius - specialButtonIndent);
    
    self.menuButton.bounds = CGRectMake(0, 0, 2*specialButtonRadius, 2*specialButtonRadius);
    self.menuButton.center = CGPointMake(CGRectGetMaxX(self.view.bounds) - specialButtonRadius - 5, specialButtonRadius + 5 + top);
    self.menuMaskView.frame = self.menuButton.bounds;
}

- (CGFloat)directionButtonRadius {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return 80;
    } else {
        return 100;
    }
}

- (CGFloat)abButtonRadius {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return 35;
    } else {
        return 50;
    }
}

- (CGFloat)specialButtonRadius {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return 25;
    } else {
        return 35;
    }
}

- (UIFont *)abButtonFont {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return [UIFont boldSystemFontOfSize:30];
    } else {
        return [UIFont boldSystemFontOfSize:40];
    }
}

- (UIFont *)specialButtonFont {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return [UIFont systemFontOfSize:15];
    } else {
        return [UIFont systemFontOfSize:20];
    }
}

- (CGRect)frameForScreenView {
    CGSize nativeSize = _nestopiaCore.nativeResolution;
    CGFloat nativeRatio = nativeSize.width / nativeSize.height;
    
    CGSize viewSize = self.view.bounds.size;
    CGFloat viewRatio = viewSize.width / viewSize.height;
    
    CGFloat scale;
    if (viewRatio > nativeRatio) {
        scale = viewSize.height / nativeSize.height;
    } else {
        scale = viewSize.width / nativeSize.width;
    }
    
    if ([[self.game.settings objectForKey:@"integralScale"] boolValue]) {
        scale = floor(scale);
    }
    
    CGSize screenSize = CGSizeMake(nativeSize.width * scale, nativeSize.height * scale);
    CGPoint screenOrigin = CGPointMake(floor((viewSize.width - screenSize.width) / 2),
                                       floor((viewSize.height - screenSize.height) / 2));
    
    return CGRectMake(screenOrigin.x, screenOrigin.y, screenSize.width, screenSize.height);
}

- (void)menuButtonClicked {
    [_nestopiaCore stopEmulation];
    
    _saveStateSheet = [[UIActionSheet alloc] init];
    _saveStateSheet.title = self.game.title;
    
    if (strstr([self.game.path cStringUsingEncoding: NSASCIIStringEncoding], "(VS)")) {
        [_saveStateSheet addButtonWithTitle: @"Insert Coin"];
    }
    
    if (pad1) {
        [_saveStateSheet addButtonWithTitle: @"Switch to Player 2"];
    } else {
        [_saveStateSheet addButtonWithTitle: @"Switch to Player 1"];
    }
    
    [_saveStateSheet addButtonWithTitle: @"Game Settings"];
    [_saveStateSheet addButtonWithTitle: @"Save and Exit"];
    [_saveStateSheet addButtonWithTitle: @"Exit Game"];
    
    [_saveStateSheet addButtonWithTitle: @"Resume"];
    
    _saveStateSheet.cancelButtonIndex = 4;
    _saveStateSheet.destructiveButtonIndex = 3;
    _saveStateSheet.delegate = self;
    
    [_saveStateSheet showInView: self.view];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self.delegate gamePlayViewControllerDidFinish:self];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (actionSheet == _saveStateSheet) {
        if (!strstr([self.game.path cStringUsingEncoding: NSASCIIStringEncoding], "(VS)")) {
            buttonIndex++;
        }
        
		if (buttonIndex == 3) { /* Save and Exit Game */
			[_nestopiaCore saveState];
            [self.delegate gamePlayViewControllerDidFinish:self];
            return;
		} else if (buttonIndex == 2) { /* Game Settings */
            SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
            settingsVC.game = self.game;
            settingsVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(settingsDoneButtonClicked)];
            
            UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:settingsVC];
            [self presentViewController:navCon animated:YES completion:nil];
            return;
        } else if (buttonIndex == 0) { /* Insert Coin */
            [_nestopiaCore startEmulation];
            //[emulatorCore insertCoin1]; // TODO
            
            return;
        } else if (buttonIndex == 1) { /* Controller Toggle */
            if (pad1) {
                [_nestopiaCore activatePad2];
                pad1 = NO;
            } else {
                pad1 = YES;
                [_nestopiaCore activatePad1];
            }
            
            [_nestopiaCore startEmulation];
            return;
        } else if (buttonIndex == 5) { /* Resume Game */
            [_nestopiaCore startEmulation];
            return;
        } else {
            [self.delegate gamePlayViewControllerDidFinish:self];
            return;
        }

        _saveStateSheet = nil;
	}
}

- (NSUInteger)supportedInterfaceOrientations {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskLandscape;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [_nestopiaCore stopEmulation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self updateGameGenieCodes];
    [_nestopiaCore startEmulation];
}

- (void)settingsDoneButtonClicked {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return gameControllerManager.gameControllerConnected;
}

#pragma mark - GameController Management

- (void)setupGameControllerPauseHandler {
    __typeof__(self) __weak weakSelf = self;
    
    gameControllerManager.pauseHandler = ^(GameControllerManager *manager) {
        if (weakSelf.saveStateSheet) {
            weakSelf.saveStateSheet.delegate = nil;
            [weakSelf.saveStateSheet dismissWithClickedButtonIndex:0 animated:YES];
            [weakSelf.nestopiaCore startEmulation];
            weakSelf.saveStateSheet = nil;
        } else {
            [weakSelf menuButtonClicked];
        }
    };
}

- (void)setButtonsHiddenForGamepad:(BOOL)hidden {
    self.directionButton.hidden = hidden;
    self.aButton.hidden = hidden;
    self.bButton.hidden = hidden;
    
    [self setNeedsStatusBarAppearanceUpdate];

    if (hidden) {   //  Need to disable the idle timer
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
}

- (void)gameControllerManagerGamepadDidConnect:(GameControllerManager *)controllerManager {
    [self setButtonsHiddenForGamepad:YES];
    [self setupGameControllerPauseHandler];
}

- (void)gameControllerManagerGamepadDidDisconnect:(GameControllerManager *)controllerManager {
    [self setButtonsHiddenForGamepad:NO];
    gameControllerManager.pauseHandler = nil;
}

#pragma mark - NestopiaCoreInputDelegate

- (NestopiaInput)nestopiaCoreCallbackInput {
    NestopiaPadInput padInput = 0;
    padInput |= self.directionButton.input;
    padInput |= self.selectButton.input;
    padInput |= self.startButton.input;
    padInput |= self.aButton.input;
    padInput |= self.bButton.input;
    
    padInput |= [gameControllerManager currentControllerInput];
    
    NestopiaInput input;
    input.pad1 = pad1 ? padInput : 0;
    input.pad2 = pad1 ? 0 : padInput;
    input.zapper = 0; // TODO
    input.zapperX = 0;
    input.zapperY = 0;
    return input;
}

@end

