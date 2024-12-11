
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(BuildUID)
@interface AMABuildUID : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, copy, readonly) NSString *stringValue;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithString:(NSString *)buildUIDString;
- (instancetype)initWithDate:(NSDate *)buildUIDDate;

- (NSComparisonResult)compare:(AMABuildUID *)other;

+ (instancetype)buildUID;

@end

NS_ASSUME_NONNULL_END
