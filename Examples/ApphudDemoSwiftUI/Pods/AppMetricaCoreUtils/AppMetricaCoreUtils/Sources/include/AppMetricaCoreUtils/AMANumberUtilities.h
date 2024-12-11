
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(NumberUtilities)
@interface AMANumberUtilities : NSObject

+ (NSUInteger)unsignedIntegerForNumber:(NSNumber *)number defaultValue:(NSUInteger)defaultValue;
+ (double)doubleWithNumber:(NSNumber *)value defaultValue:(double)defaultValue;
+ (BOOL)boolForNumber:(NSNumber *)number defaultValue:(BOOL)defaultValue;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
