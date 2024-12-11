
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAKeychainStoring <NSObject>

- (void)setStringValue:(NSString *)value forKey:(NSString *)key error:(NSError **)error;
- (nullable NSString *)stringValueForKey:(NSString *)key error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
