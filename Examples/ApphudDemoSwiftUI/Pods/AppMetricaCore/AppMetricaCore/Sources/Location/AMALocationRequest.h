
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@interface AMALocationRequest : AMAGenericRequest

@property (nonatomic, strong, readonly) NSNumber *requestIdentifier;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *locationIdentifiers;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *visitIdentifiers;
@property (nonatomic, copy, readonly) NSData *data;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithRequestIdentifier:(NSNumber *)requestIdentifier
                      locationIdentifiers:(NSArray<NSNumber *> *)locationIdentifiers
                         visitIdentifiers:(NSArray<NSNumber *> *)visitIdentifiers
                                     data:(NSData *)data;

@end
