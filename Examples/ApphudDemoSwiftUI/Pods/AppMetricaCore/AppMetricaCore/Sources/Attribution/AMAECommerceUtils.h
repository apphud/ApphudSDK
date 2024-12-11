
#import <Foundation/Foundation.h>
#import "AMAECommerce+Internal.h"
#import "Ecommerce.pb-c.h"

extern const AMAECommerceEventType kAMADefaultECommerceEventType;
extern NSString *const kAMAConvertingErrorDomain;
extern NSUInteger kAMACodeInvalidData;

typedef NS_ENUM(NSInteger, AMAECommmerceConvertingErrorCode) {
    AMAInvalidData,
};

@interface AMAECommerceUtils : NSObject

+ (AMAECommerceEventType)convertECommerceEventProtoType:(Ama__ECommerceEvent__ECommerceEventType)type
                                                  error:(NSError **)error;
+ (BOOL)isFirstECommerceEvent:(Ama__ECommerceEvent *)eCommerceData;
+ (NSArray<AMAECommerceAmount *>*)getECommerceMoneyFromOrder:(Ama__ECommerceEvent__OrderInfo *)orderInfo;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
