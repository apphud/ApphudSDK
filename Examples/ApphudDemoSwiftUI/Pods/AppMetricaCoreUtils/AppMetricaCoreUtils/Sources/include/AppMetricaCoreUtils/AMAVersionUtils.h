
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(VersionUtils)
@interface AMAVersionUtils : NSObject

+ (BOOL)isOSVersionMajorAtLeast:(NSInteger)major;
+ (BOOL)isOSVersionAtLeast:(NSOperatingSystemVersion)version;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
