
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppMetricaPreloadInfo)
@interface AMAAppMetricaPreloadInfo : NSObject <NSCopying>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/** Initialize Preload info with specific publisher and tracking identifiers.
 If case of invalid identifiers constructor returns nil in release and raises an exception in debug

 @param trackingID Tracking identifier
 */
- (nullable instancetype)initWithTrackingIdentifier:(NSString *)trackingID;

/** Setting key - value data to be used as additional information, associated with preload info.

 @param info Additional preload info.
 @param key Additional preload key.
 */
- (void)setAdditionalInfo:(NSString *)info
                   forKey:(NSString *)key NS_SWIFT_NAME(setAdditionalInfo(info:for:));

@end

NS_ASSUME_NONNULL_END
