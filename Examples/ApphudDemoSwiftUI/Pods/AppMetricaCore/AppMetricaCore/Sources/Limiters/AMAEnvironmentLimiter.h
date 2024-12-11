
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAStringTruncating;

@interface AMAEnvironmentLimiter : NSObject

- (instancetype)initWithCountLimit:(NSUInteger)pairCount
                  totalLengthLimit:(NSUInteger)totalLengthLimit
                          keyLimit:(NSUInteger)keyLimit
                        valueLimit:(NSUInteger)valueLimit;

- (instancetype)initWithCountLimit:(NSUInteger)pairsLimit
                  totalLengthLimit:(NSUInteger)totalLengthLimit
                      keyTruncator:(id<AMAStringTruncating>)keyTruncator
                    valueTruncator:(id<AMAStringTruncating>)valueTruncator NS_DESIGNATED_INITIALIZER;

- (NSDictionary *)limitEnvironment:(NSDictionary *)environment
                  afterAddingValue:(NSString *)value
                            forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
