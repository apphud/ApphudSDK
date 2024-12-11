#import <Foundation/Foundation.h>

#import <AppMetricaCore/AppMetricaCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface AMAExternalAttributionSerializer : NSObject

- (nullable NSData *)serializeExternalAttribution:(NSDictionary *)data
                                           source:(AMAAttributionSource)source
                                            error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
