
#import "AMALightRevenueEvent.h"

@implementation AMALightRevenueEvent

- (instancetype)initWithPriceMicros:(NSDecimalNumber *)priceMicros
                           currency:(NSString *)currency
                           quantity:(NSUInteger)quantity
                      transactionID:(NSString *)transactionID
                             isAuto:(BOOL)isAuto
                          isRestore:(BOOL)isRestore
{
    self = [super init];
    if (self != nil) {
        _priceMicros = priceMicros;
        _currency = [currency copy];
        _quantity = quantity;
        _transactionID = [transactionID copy];
        _isAuto = isAuto;
        _isRestore = isRestore;
    }
    return self;
}

@end
