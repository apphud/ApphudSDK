
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMACore.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAStartupClientIdentifierFactory.h"
#import "AMAStartupClientIdentifier.h"
#import "AMAAdProvider.h"

@implementation AMAApplicationStateManager

#pragma mark - Public -

+ (AMAApplicationState *)applicationState
{
    AMAMutableApplicationState *mutableState = [AMAMutableApplicationState new];
    [self.class updateApplicationState:mutableState];
    return mutableState.copy;
}

+ (AMAApplicationState *)quickApplicationState
{
    AMAMutableApplicationState *mutableState = [AMAMutableApplicationState new];
    [self.class quickUpdateApplicationState:mutableState];
    return mutableState.copy;
}

+ (AMAApplicationState *)stateWithFilledEmptyValues:(AMAApplicationState *)appState
{
    AMAApplicationState *currentState = self.class.applicationState;
    NSMutableDictionary *currentStateDictionary = currentState.dictionaryRepresentation.mutableCopy;
    NSMutableDictionary *appStateDictionary = appState.dictionaryRepresentation.mutableCopy;
    [currentStateDictionary removeObjectsForKeys:appStateDictionary.allKeys];
    [appStateDictionary addEntriesFromDictionary:currentStateDictionary];
    return [AMAApplicationState objectWithDictionaryRepresentation:appStateDictionary];
}

#pragma mark - Private -

+ (void)updateApplicationState:(AMAMutableApplicationState *)mutableState
{
    [self.class quickUpdateApplicationState:mutableState];

    AMAStartupClientIdentifier *startupClientID = AMAStartupClientIdentifierFactory.startupClientIdentifier;
    mutableState.UUID = startupClientID.UUID;
    mutableState.deviceID = startupClientID.deviceID;
    
    mutableState.IFV = startupClientID.IFV;
    mutableState.IFA = [[[AMAAdProvider sharedInstance] advertisingIdentifier] UUIDString];
    mutableState.LAT = [AMAAdProvider sharedInstance].isAdvertisingTrackingEnabled == NO;
}

+ (void)quickUpdateApplicationState:(AMAMutableApplicationState *)mutableState
{
    mutableState.appVersionName = [AMAMetricaConfiguration sharedInstance].inMemory.appVersion;
    mutableState.appDebuggable = [AMAPlatformDescription appDebuggable];
    mutableState.kitVersionName = [AMAPlatformDescription SDKVersionName];
    mutableState.kitBuildNumber = [AMAPlatformDescription SDKBuildNumber];
    mutableState.kitBuildType = [AMAPlatformDescription SDKBuildType];
    mutableState.OSVersion = [AMAPlatformDescription OSVersion];
    mutableState.OSAPILevel = [AMAPlatformDescription OSAPILevel];
    mutableState.locale = [AMAPlatformLocaleState fullLocaleIdentifier];
    mutableState.isRooted = [AMAPlatformDescription isDeviceRooted];

    uint32_t appBuildNumber = [AMAMetricaConfiguration sharedInstance].inMemory.appBuildNumber;
    mutableState.appBuildNumber = @(appBuildNumber).stringValue;
}

@end
