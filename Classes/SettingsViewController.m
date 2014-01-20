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

#import "SettingsViewController.h"
#import "GamePlayViewController.h"
#import "DisclosureIndicator.h"

typedef NS_ENUM(NSInteger, SettingsSection) {
    SettingsSectionGlobalSettings = 0,
    SettingsSectionGameGenie,
    SettingsSectionFavorites,
    SettingsSectionCount
};

typedef NS_ENUM(NSInteger, GlobalSetting) {
    GlobalSettingIntegralScale = 0,
    GlobalSettingAspectRatio,
    GlobalSettingAntiAliasing,
    GlobalSettingSwapAB,
    GlobalSettingStickyController,
    GlobalSettingControllers,
    GlobalSettingCount
};

const NSInteger MAX_GAME_GENIE_CODES = 4;

@interface SettingsViewController ()<UITextFieldDelegate,MultiValueViewControllerDelegate> {
    int controllerLayoutIndex;
	bool raised;
}

@property (nonatomic, strong) NSArray *gameGenieCodeControls;
@property (nonatomic, strong) UITextField *controllerLayout;
@property (nonatomic, strong) UISwitch *controllerStickControl;
@property (nonatomic, strong) UISwitch *swapABControl;
@property (nonatomic, strong) UISwitch *integralScaleControl;
@property (nonatomic, strong) UISwitch *aspectRatioControl;
@property (nonatomic, strong) UISwitch *gameGenieControl;
@property (nonatomic, strong) UISwitch *antiAliasControl;

@property (nonatomic, strong) UIBarButtonItem *leftButton;
@property (nonatomic, strong) NSArray *controllerLayoutDescriptions;

@end

@implementation SettingsViewController

#pragma mark - Settings Persistence

- (void)loadSettings {
    NSDictionary *settings;
    
    if (self.game) {
        self.title = self.game.title;
        settings = self.game.settings;
    } else {
        self.title = @"Settings";
        settings = [Game globalSettings];
    }

    /* Global Settings */
    
    self.swapABControl.on = [[settings objectForKey: @"swapAB"] boolValue];
    self.antiAliasControl.on = [[settings objectForKey: @"antiAliasing"] boolValue];
    self.controllerStickControl.on = [[settings objectForKey: @"controllerStickControl"] boolValue];
    self.integralScaleControl.on = [[settings objectForKey: @"integralScale"] boolValue];
    self.aspectRatioControl.on = ([settings objectForKey: @"aspectRatio"] == nil) ? YES : [[settings objectForKey: @"aspectRatio"] boolValue];
    
    controllerLayoutIndex =  [[settings objectForKey: @"controllerLayout"] intValue];
    self.controllerLayout.text = [self.controllerLayoutDescriptions objectAtIndex: controllerLayoutIndex];
    
    /* Game-Specific Settings */
    
    if (self.game) {
        self.gameGenieControl.on = [[settings objectForKey: @"gameGenie"] boolValue];
        for(int i = 0; i < MAX_GAME_GENIE_CODES; i++) {
            UITextField *gameGenieCodeControl = self.gameGenieCodeControls[i];
            gameGenieCodeControl.text = [settings objectForKey: [NSString stringWithFormat: @"gameGenieCode%d", i]];
        }
    }
}

- (void)saveSettings {
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    
    [settings setObject:@(self.swapABControl.on) forKey:@"swapAB"];
    [settings setObject:@(self.integralScaleControl.on) forKey:@"integralScale"];
    [settings setObject:@(self.aspectRatioControl.on) forKey:@"aspectRatio"];
    [settings setObject:@(self.antiAliasControl.on) forKey:@"antiAliasing"];
    [settings setObject:@(self.controllerStickControl.on) forKey:@"controllerStickControl"];
    [settings setObject:@(controllerLayoutIndex) forKey:@"controllerLayout"];
    
    if (self.game) {
        [settings setObject:@(self.gameGenieControl.on) forKey:@"gameGenie"];
        for (int i = 0; i < MAX_GAME_GENIE_CODES; i++) {
            UITextField *gameGenieCodeControl = self.gameGenieCodeControls[i];
            [settings setObject:(gameGenieCodeControl.text ?: @"") forKey:[NSString stringWithFormat: @"gameGenieCode%d", i]];
        }
	}
    
    if (self.game) {
        self.game.settings = settings;
    } else {
        [Game saveGlobalSettings:settings];
    }
}

#pragma mark - Initialization

- (id) init {
    self = [super initWithStyle: UITableViewStyleGrouped];
	
	if (self != nil) {
        UIImage *tabBarImage = [UIImage imageNamed: @"Settings.png"];
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle: @"Default Settings" image: tabBarImage tag: 2];

        self.controllerLayoutDescriptions = [[NSArray alloc] initWithObjects: @"Game Pad + Zapper", @"Zapper Only", nil];
		raised = NO;
		self.swapABControl = [[UISwitch alloc] initWithFrame: CGRectZero];
		self.integralScaleControl = [[UISwitch alloc] initWithFrame: CGRectZero];
		self.aspectRatioControl = [[UISwitch alloc] initWithFrame: CGRectZero];
		self.gameGenieControl = [[UISwitch alloc] initWithFrame: CGRectZero];
        self.antiAliasControl = [[UISwitch alloc] initWithFrame: CGRectZero];
        self.controllerStickControl = [[UISwitch alloc] initWithFrame: CGRectZero];

        self.controllerLayout = [[UITextField alloc] initWithFrame: CGRectMake(-170, -12.0, 160.0, 30.0)];
        self.controllerLayout.textColor = [UIColor colorWithHue: .6027 saturation: .63 brightness: .52 alpha: 1.0];
        self.controllerLayout.enabled = NO;
		self.controllerLayout.textAlignment = NSTextAlignmentRight;
		self.controllerLayout.contentVerticalAlignment = UIControlContentVerticalAlignmentBottom;
        
        [self loadSettings];
        [self saveSettings];
	}
	return self;
}

#pragma mark - View Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    
    self.navigationController.navigationBar.hidden = NO;

    [self loadSettings];
}

- (void)viewWillDisappear:(BOOL)animated {
	
	NSLog(@"%s saving settings", __func__);
	
	[self saveSettings];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSArray *)gameGenieCodeControls {
    if (!_gameGenieCodeControls) {
        NSMutableArray *gameGenieCodeControls = [[NSMutableArray alloc] init];

        for(int i = 0; i < MAX_GAME_GENIE_CODES; i++) {
			UITextField *gameGenieCodeControl = [[UITextField alloc] initWithFrame: CGRectMake(100.0, 5.0, 200.0, 35.0)];
			gameGenieCodeControl.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
			gameGenieCodeControl.delegate = self;
			gameGenieCodeControl.placeholder = @"Empty";
			gameGenieCodeControl.returnKeyType = UIReturnKeyDone;

            [gameGenieCodeControls addObject:gameGenieCodeControl];
		}

        _gameGenieCodeControls = [gameGenieCodeControls copy];
    }
    
    return _gameGenieCodeControls;
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (!self.game) {
        return 1;
    } else {
        return SettingsSectionCount;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SettingsSection settingsSection = section;

    switch (settingsSection) {
        case(SettingsSectionGlobalSettings):
			return GlobalSettingCount;
			break;
		case(SettingsSectionGameGenie):
			return MAX_GAME_GENIE_CODES + 1;
			break;
        case(SettingsSectionFavorites):
            return 1;
            break;
        default:
            return 0;
	}
	
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    SettingsSection settingsSection = section;
	switch (settingsSection) {
		case(SettingsSectionGlobalSettings):
			return @"Global Settings";
		case(SettingsSectionGameGenie):
			return @"Game Genie";
        default:
            return nil;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SettingsSection section = indexPath.section;

	NSString *CellIdentifier = [NSString stringWithFormat: @"%d:%d", [indexPath indexAtPosition: 0],
								[indexPath indexAtPosition:1]];
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: CellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textAlignment = NSTextAlignmentLeft;;

        DisclosureIndicator *accessory = [DisclosureIndicator accessoryWithColor: [UIColor colorWithHue: 0 saturation: 0 brightness: .5 alpha: 1.0]];
        accessory.highlightedColor = [UIColor blackColor];

		switch (section) {
			case(SettingsSectionGlobalSettings): {
                GlobalSetting row = indexPath.row;

				switch(row) {
					case(GlobalSettingIntegralScale):
						cell.accessoryView = self.integralScaleControl;
						cell.textLabel.text = @"Integral Scale";
						break;
					case(GlobalSettingAspectRatio):
						cell.accessoryView = self.aspectRatioControl;
						cell.textLabel.text = @"Aspect Ratio";
						break;
                    case(GlobalSettingAntiAliasing):
                        cell.accessoryView = self.antiAliasControl;
                        cell.textLabel.text = @"Anti-Aliasing";
                        break;
                    case(GlobalSettingSwapAB):
						cell.accessoryView = self.swapABControl;
						cell.textLabel.text = @"Swap A/B";
						break;
                    case(GlobalSettingStickyController):
                        cell.accessoryView = self.controllerStickControl;
                        cell.textLabel.text = @"Sticky Controller";
                        break;
                    case(GlobalSettingControllers):
                        cell.accessoryView = accessory;
                        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                            cell.textLabel.text = @"Controller Layout";
                        } else {
                            cell.textLabel.text = @"Controllers";
                        }
                        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                        [cell.accessoryView addSubview:self.controllerLayout];
                    default: {
                        //  DO NOTHING
                    }
				}
            }
				break;
			case(SettingsSectionGameGenie):
				if ([indexPath indexAtPosition: 1] == 0) {  //  Switch for activating Game Genie
                    cell.accessoryView = self.gameGenieControl;
                    cell.textLabel.text = @"Game Genie";
                    break;
				} else {    //  Fields for adding codes
                    UITextField *gameGenieCodeControl = self.gameGenieCodeControls[[indexPath indexAtPosition: 1]-1];
					[cell addSubview: gameGenieCodeControl];
					if (!self.game) {
						gameGenieCodeControl.text = nil;
						gameGenieCodeControl.placeholder = @"None";
						gameGenieCodeControl.enabled = NO;
					} else {
						gameGenieCodeControl.placeholder = @"Empty";
						gameGenieCodeControl.enabled = YES;
					}

					cell.textLabel.text = [NSString stringWithFormat: @"Code #%d", [indexPath indexAtPosition: 1]];
				}
                break;
            case(SettingsSectionFavorites):
            {
                if (! self.game.favorite) {
                    cell.textLabel.text = @"Add to Favorites";
                } else {
                    cell.textLabel.text = @"Remove from Favorites";
                }
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.selectionStyle  = UITableViewCellSelectionStyleBlue;
                break;
            }
            default: {
                //  DO NOTHING
            }
		}
	}
	
    return cell;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == SettingsSectionGlobalSettings && !self.game) {
        return @"To access Game Genie settings, enter settings from within the active game play menu.";
    }
    return nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath: indexPath];

    if (indexPath.section == SettingsSectionGlobalSettings && indexPath.row == GlobalSettingControllers) {
		MultiValueViewController *viewController = [[MultiValueViewController alloc] initWithStyle: UITableViewStyleGrouped];
        viewController.options = [NSArray arrayWithArray:self.controllerLayoutDescriptions];
        viewController.selectedItemIndex = controllerLayoutIndex;
        viewController.delegate = self;
		[self.navigationController pushViewController: viewController animated: YES];
    }
    
    if (indexPath.section == SettingsSectionFavorites && indexPath.row == 0) {
        self.game.favorite = !self.game.favorite;
        
        if (!self.game.favorite) {
            cell.textLabel.text = @"Add to Favorites";
        } else {
            cell.textLabel.text = @"Remove from Favorites";
        }
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    CGRect location = textField.frame;
    CGRect tableViewCoordinates = [textField.superview convertRect:location toView:self.tableView];

    [self.tableView scrollRectToVisible:tableViewCoordinates animated:YES];
}

#pragma mark - MultiValueViewControllerDelegate

- (void) didSelectItemFromList: (MultiValueViewController *)multiValueViewController selectedItemIndex:(int)selectedItemIndex identifier:(id)identifier
{
    controllerLayoutIndex = selectedItemIndex;
    self.controllerLayout.text = [self.controllerLayoutDescriptions objectAtIndex:controllerLayoutIndex];
    [self saveSettings];
    // [self.tableView reloadData];
}

@end
