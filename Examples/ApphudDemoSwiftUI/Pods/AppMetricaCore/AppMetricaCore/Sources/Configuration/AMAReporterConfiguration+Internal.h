
#import "AMAReporterConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMAReporterConfiguration (Internal)

@property (nonatomic, strong, nullable, readonly) NSNumber *dataSendingEnabledState;

- (instancetype)initWithoutAPIKey;

@end

@interface AMAMutableReporterConfiguration (Internal)

/** Application key used to initialize the configuration.
 */
@property (nonatomic, copy, nullable) NSString *APIKey;

@end

NS_ASSUME_NONNULL_END
