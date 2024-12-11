
#import <Foundation/Foundation.h>

@interface AMAMetricaParametersScanner : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (BOOL)scanAPIKey:(uint32_t *)APIKey inString:(NSString *)APIKeyCandidate;
+ (BOOL)scanAppBuildNumber:(uint32_t *)appBuildNumber inString:(NSString *)AppBuildNumberCandidate;

@end
