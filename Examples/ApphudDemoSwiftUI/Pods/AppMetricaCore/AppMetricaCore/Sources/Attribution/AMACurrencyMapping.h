
#import <Foundation/Foundation.h>
#import "AMAJSONSerializable.h"

extern NSString *const kAMAAttributionCurrencyErrorDomain;

typedef NS_ENUM(NSInteger, AMAAttributionCurrencyErrorCode) {
    AMAAttributionCurrencyErrorUnknownCurrency,
    AMAAttributionCurrencyErrorBadInput,
};

@interface AMACurrencyMapping : NSObject<AMAJSONSerializable>

- (instancetype)initWithMapping:(NSDictionary<NSString *, NSDecimalNumber *> *)mapping;
- (NSDecimalNumber *)convert:(NSDecimalNumber *)number
                    currency:(NSString *)currency
                       scale:(NSInteger)scale
                       error:(NSError **)error;

@end
