
#import <Foundation/Foundation.h>
#import "AMAECommerce+Internal.h"

@interface AMALightECommerceEvent : NSObject

@property (nonatomic, assign, readonly) AMAECommerceEventType type;
@property (nonatomic, copy, readonly) NSArray<AMAECommerceAmount *> *amounts;
@property (nonatomic, assign, readonly) BOOL isFirst;

- (instancetype)initWithType:(AMAECommerceEventType)type
                     amounts:(NSArray<AMAECommerceAmount *> *)amounts
                     isFirst:(BOOL)isFirst;

@end
