#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAStringTruncating;
@protocol AMADataTruncating;

NS_SWIFT_NAME(TruncatorsFactory)
@interface AMATruncatorsFactory : NSObject

+ (id<AMAStringTruncating>)eventNameTruncator;
+ (id<AMAStringTruncating>)eventStringValueTruncator;
+ (id<AMADataTruncating>)eventBinaryValueTruncator;
+ (id<AMADataTruncating>)fullValueTruncator;
+ (id<AMAStringTruncating>)extrasMigrationTruncator;
+ (id<AMAStringTruncating>)profileIDTruncator;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
