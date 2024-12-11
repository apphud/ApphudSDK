#import <Foundation/Foundation.h>

#import <AppMetricaCore/AppMetricaCore.h>

#import "AMAJSONSerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMAExternalAttributionConfiguration : NSObject <AMAJSONSerializable>

@property (nonatomic, strong, readonly) AMAAttributionSource source;
@property (nonatomic, strong, readonly) NSDate *timestamp;
@property (nonatomic, strong, readonly) NSString *contentsHash;

- (instancetype)initWithSource:(AMAAttributionSource)source
                     timestamp:(NSDate *)timestamp
                  contentsHash:(NSString *)contentsHash;

@end

NS_ASSUME_NONNULL_END
