
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(IdentifierValidator)
@interface AMAIdentifierValidator : NSObject

+ (BOOL)isValidUUIDKey:(NSString *)key;

+ (BOOL)isValidNumericKey:(NSString *)key;

+ (BOOL)isValidVendorIdentifier:(NSString *)identifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
