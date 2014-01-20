//
//  GameControllerManager.h
//  Nestopia
//
//  Created by Adam Bell on 12/20/2013.
//
//

#import "NestopiaCore.h"

@class GameControllerManager;

typedef void(^GameControllerPauseHandler)(GameControllerManager *gameControllerManager);

@protocol GameControllerManagerDelegate <NSObject>

@required
- (void)gameControllerManagerGamepadDidConnect:(GameControllerManager *)controllerManager;
- (void)gameControllerManagerGamepadDidDisconnect:(GameControllerManager *)controllerManager;

@end

@interface GameControllerManager : NSObject

+(instancetype)sharedInstance;

- (NestopiaPadInput)currentControllerInput;

@property (nonatomic, readonly, getter = isGameControllerConnected) BOOL gameControllerConnected;

@property (nonatomic) BOOL swapAB;

@property (nonatomic, weak) id<GameControllerManagerDelegate> delegate;

@property (nonatomic, copy) GameControllerPauseHandler pauseHandler;

@end
