
#import <Foundation/Foundation.h>
#import "AMAECommerce+Internal.h"
#import "AMAAttributionModelType.h"
#import "AMAEventTypes.h"
#import "AMARevenueSource.h"

extern NSString *const kAMAAttributionConvertingErrorDomain;

typedef NS_ENUM(NSInteger, AMAAttributionConvertingErrorCode) {
    AMAAttributionConvertingErrorUnknownInput,
};

@interface AMAAttributionConvertingUtils : NSObject

+ (NSString *)stringForECommerceType:(AMAECommerceEventType)type;
+ (AMAECommerceEventType)eCommerceTypeForString:(NSString *)type error:(NSError **)error;
+ (AMAAttributionModelType)modelTypeForString:(NSString *)type;
+ (AMAEventType)eventTypeForString:(NSString *)type error:(NSError **)error;
+ (AMARevenueSource)revenueSourceForString:(NSString *)source error:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
