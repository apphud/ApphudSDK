
#import "AMAReporterProviding.h"

@interface AMASharedReporterProvider : NSObject <AMAReporterProviding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey;

@end
