
#import "AMAAppMetricaConfiguration.h"
#import "AMAJSONSerializable.h"

extern NSString *const kAMAAPIKey;
extern NSString *const kAMAHandleFirstActivationAsUpdate;
extern NSString *const kAMAHandleActivationAsSessionStart;
extern NSString *const kAMASessionsAutoTracking;
extern NSString *const kAMADataSendingEnabled;
extern NSString *const kAMAMaximumReportsInDatabaseCount;
extern NSString *const kAMALocationTracking;
extern NSString *const kAMAAllowsBackgroundLocationUpdates;
extern NSString *const kAMAAccurateLocationTracking;
extern NSString *const kAMADispatchPeriod;
extern NSString *const kAMACustomLocation;
extern NSString *const kAMALatitude;
extern NSString *const kAMALongitude;
extern NSString *const kAMASessionTimeout;
extern NSString *const kAMAAppVersion;
extern NSString *const kAMALogsEnabled;
extern NSString *const kAMAPreloadInfo;
extern NSString *const kAMARevenueAutoTrackingEnabled;
extern NSString *const kAMAAppOpenTrackingEnabled;
extern NSString *const kAMAUserProfileID;
extern NSString *const kAMAMaxReportsCount;
extern NSString *const kAMAAppBuildNumber;
extern NSString *const kAMACustomHosts;
extern NSString *const kAMAAppEnvironment;

@interface AMAAppMetricaConfiguration (JSONSerializable) <AMAJSONSerializable>
@end
