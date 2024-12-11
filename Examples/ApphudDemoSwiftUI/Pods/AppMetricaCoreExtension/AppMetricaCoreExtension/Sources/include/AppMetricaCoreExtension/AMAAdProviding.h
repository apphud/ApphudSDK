
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AMATrackingManagerAuthorizationStatus) {
    AMATrackingManagerAuthorizationStatusNotDetermined = 0,
    AMATrackingManagerAuthorizationStatusRestricted,
    AMATrackingManagerAuthorizationStatusDenied,
    AMATrackingManagerAuthorizationStatusAuthorized
} API_AVAILABLE(ios(14.0), tvos(14.0)) NS_SWIFT_NAME(TrackingManagerAuthorizationStatus);

NS_SWIFT_NAME(AdProviding)
@protocol AMAAdProviding <NSObject>

- (BOOL)isAdvertisingTrackingEnabled;
- (nullable NSUUID *)advertisingIdentifier;
- (AMATrackingManagerAuthorizationStatus)ATTStatus API_AVAILABLE(ios(14.0), tvos(14.0));

@end

NS_ASSUME_NONNULL_END
