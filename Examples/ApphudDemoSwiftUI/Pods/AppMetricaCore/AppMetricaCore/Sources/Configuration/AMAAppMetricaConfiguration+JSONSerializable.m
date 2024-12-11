
#import "AMAAppMetricaConfiguration+JSONSerializable.h"
#import "AMAAppMetricaPreloadInfo+JSONSerializable.h"
#import <CoreLocation/CoreLocation.h>

@implementation AMAAppMetricaConfiguration (JSONSerializable)

NSString *const kAMAAPIKey = @"api.key";
NSString *const kAMAHandleFirstActivationAsUpdate = @"handle.first.activation.as.update";
NSString *const kAMAHandleActivationAsSessionStart = @"handle.activation.as.session.start";
NSString *const kAMASessionsAutoTracking = @"sessions.auto.tracking";
NSString *const kAMADataSendingEnabled = @"data.sending.enabled";
NSString *const kAMAMaximumReportsInDatabaseCount = @"max.reports.in.database.count";
NSString *const kAMALocationTracking = @"location.tracking";
NSString *const kAMAAllowsBackgroundLocationUpdates = @"allows.background.location.updates";
NSString *const kAMAAccurateLocationTracking = @"accurate.location.tracking";
NSString *const kAMADispatchPeriod = @"dispatch.period";
NSString *const kAMACustomLocation = @"custom.location";
NSString *const kAMALatitude = @"latitude";
NSString *const kAMALongitude = @"longitude";
NSString *const kAMASessionTimeout = @"session.timeout";
NSString *const kAMAAppVersion = @"app.version";
NSString *const kAMALogsEnabled = @"logs.enabled";
NSString *const kAMAPreloadInfo = @"preload.info";
NSString *const kAMARevenueAutoTrackingEnabled = @"revenue.auto.tracking.enabled";
NSString *const kAMAAppOpenTrackingEnabled = @"app.open.tracking.enabled";
NSString *const kAMAUserProfileID = @"user.profile.id";
NSString *const kAMAMaxReportsCount = @"max.reports.count";
NSString *const kAMAAppBuildNumber = @"app.build.number";
NSString *const kAMACustomHosts = @"custom.hosts";
NSString *const kAMAAppEnvironment = @"app.environment";


- (instancetype)initWithJSON:(NSDictionary *)json 
{
    if (json == nil || [json isKindOfClass:[NSDictionary class]] == NO) {
        return nil;
    }
    
    NSString *apiKey = json[kAMAAPIKey];
    if (apiKey == nil) {
        return nil;
    }

    self = [[AMAAppMetricaConfiguration alloc] initWithAPIKey:apiKey];
    
    if (self != nil) {
        if (json[kAMAHandleFirstActivationAsUpdate] != nil) {
            self.handleFirstActivationAsUpdate = [json[kAMAHandleFirstActivationAsUpdate] boolValue];
        }
        
        if (json[kAMAHandleActivationAsSessionStart] != nil) {
            self.handleActivationAsSessionStart = [json[kAMAHandleActivationAsSessionStart] boolValue];
        }
        
        if (json[kAMASessionsAutoTracking] != nil) {
            self.sessionsAutoTracking = [json[kAMASessionsAutoTracking] boolValue];
        }
        
        if (json[kAMADataSendingEnabled] != nil) {
            self.dataSendingEnabled = [json[kAMADataSendingEnabled] boolValue];
        }
        
        if (json[kAMAMaximumReportsInDatabaseCount] != nil) {
            self.maxReportsInDatabaseCount = [json[kAMAMaximumReportsInDatabaseCount] unsignedIntegerValue];
        }
        
        if (json[kAMALocationTracking] != nil) {
            self.locationTracking = [json[kAMALocationTracking] boolValue];
        }
        
        if (json[kAMAAllowsBackgroundLocationUpdates] != nil) {
            self.allowsBackgroundLocationUpdates = [json[kAMAAllowsBackgroundLocationUpdates] boolValue];
        }
        
        if (json[kAMAAccurateLocationTracking] != nil) {
            self.accurateLocationTracking = [json[kAMAAccurateLocationTracking] boolValue];
        }
        if (json[kAMADispatchPeriod] != nil) {
            self.dispatchPeriod = [json[kAMADispatchPeriod] unsignedIntegerValue];
        }
        
        if (json[kAMASessionTimeout] != nil) {
            self.sessionTimeout = [json[kAMASessionTimeout] unsignedIntegerValue];
        }
        
        if (json[kAMALogsEnabled] != nil) {
            self.logsEnabled = [json[kAMALogsEnabled] boolValue];
        }
        
        if (json[kAMAPreloadInfo] != nil) {
            self.preloadInfo = [[AMAAppMetricaPreloadInfo alloc] initWithJSON:json[kAMAPreloadInfo]];
        }
        
        if (json[kAMARevenueAutoTrackingEnabled] != nil) {
            self.revenueAutoTrackingEnabled = [json[kAMARevenueAutoTrackingEnabled] boolValue];
        }
        
        if (json[kAMAAppOpenTrackingEnabled] != nil) {
            self.appOpenTrackingEnabled = [json[kAMAAppOpenTrackingEnabled] boolValue];
        }
        
        if (json[kAMAMaxReportsCount] != nil) {
            self.maxReportsCount = [json[kAMAMaxReportsCount] unsignedIntegerValue];
        }
        
        NSDictionary *locationDict = json[kAMACustomLocation];
        if (locationDict) {
            double latitude = [locationDict[kAMALatitude] doubleValue];
            double longitude = [locationDict[kAMALongitude] doubleValue];
            self.customLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
        }
        
        NSString *userProfileID = json[kAMAUserProfileID];
        if ([userProfileID isKindOfClass:[NSString class]]) {
            self.userProfileID = userProfileID;
        }
        
        NSString *appVersion = json[kAMAAppVersion];
        if ([appVersion isKindOfClass:[NSString class]]) {
            self.appVersion = appVersion;
        }
        
        NSString *appBuildNumber = json[kAMAAppBuildNumber];
        if ([userProfileID isKindOfClass:[NSString class]]) {
            self.appBuildNumber = appBuildNumber;
        }
        
        NSArray *customHosts = json[kAMACustomHosts];
        if ([customHosts isKindOfClass:[NSArray class]]) {
            NSMutableArray *stringArray = [NSMutableArray array];
            for (NSString *host in customHosts) {
                if ([host isKindOfClass:[NSString class]]) {
                    [stringArray addObject:host];
                } else {
                    [stringArray addObject:host];
                }
            }
            self.customHosts = [stringArray copy];
        }
        
        NSDictionary *appEnvironment = json[kAMAAppEnvironment];
        if ([appEnvironment isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary<NSString *, NSString *> *validEnvDict = [NSMutableDictionary dictionary];
            
            for (NSString *key in appEnvironment) {
                id value = appEnvironment[key];
                if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                    validEnvDict[key] = value;
                }
            }
            
            self.appEnvironment = [validEnvDict copy];
        }
    }
    return self;
}

- (NSDictionary *)JSON
{
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];

    json[kAMAAPIKey] = self.APIKey;
    json[kAMAHandleFirstActivationAsUpdate] = @(self.handleFirstActivationAsUpdate);
    json[kAMAHandleActivationAsSessionStart] = @(self.handleActivationAsSessionStart);
    json[kAMASessionsAutoTracking] = @(self.sessionsAutoTracking);
    json[kAMADataSendingEnabled] = @(self.dataSendingEnabled);
    json[kAMAMaximumReportsInDatabaseCount] = @(self.maxReportsInDatabaseCount);
    json[kAMALocationTracking] = @(self.locationTracking);
    json[kAMAAllowsBackgroundLocationUpdates] = @(self.allowsBackgroundLocationUpdates);
    json[kAMAAccurateLocationTracking] = @(self.accurateLocationTracking);
    json[kAMADispatchPeriod] = @(self.dispatchPeriod);

    if (self.customLocation) {
        json[kAMACustomLocation] = @{
            kAMALatitude: @(self.customLocation.coordinate.latitude),
            kAMALongitude: @(self.customLocation.coordinate.longitude)
        };
    }

    json[kAMASessionTimeout] = @(self.sessionTimeout);
    json[kAMAAppVersion] = self.appVersion ?: [NSNull null];
    json[kAMALogsEnabled] = @(self.areLogsEnabled);
    json[kAMAPreloadInfo] = self.preloadInfo ? [self.preloadInfo JSON] : [NSNull null];
    json[kAMARevenueAutoTrackingEnabled] = @(self.revenueAutoTrackingEnabled);
    json[kAMAAppOpenTrackingEnabled] = @(self.appOpenTrackingEnabled);
    json[kAMAUserProfileID] = self.userProfileID ?: [NSNull null];
    json[kAMAMaxReportsCount] = @(self.maxReportsCount);
    json[kAMAAppBuildNumber] = self.appBuildNumber ?: [NSNull null];
    json[kAMACustomHosts] = self.customHosts ?: [NSNull null];
    json[kAMAAppEnvironment] = self.appEnvironment ?: [NSNull null];

    return [json copy];
}

@end
