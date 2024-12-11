
#import <AppMetricaPlatform/AppMetricaPlatform.h>

@interface AMAAppVersionProvider : NSObject

- (instancetype)initWithBundle:(NSBundle *)bundle;

- (NSString *)appID;
- (NSString *)appBuildNumber;
- (NSString *)appVersion;
- (NSString *)appVersionName;

@end
