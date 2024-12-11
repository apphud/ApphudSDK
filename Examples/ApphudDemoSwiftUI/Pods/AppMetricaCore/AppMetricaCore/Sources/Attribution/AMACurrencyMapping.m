
#import "AMACore.h"
#import "AMACurrencyMapping.h"

@interface AMACurrencyMapping()

@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSDecimalNumber *> *mapping;

@end

NSString *const kAMAAttributionCurrencyErrorDomain = @"io.appmetrica.AMAAttributionCurrency";
static NSString *const kAMAKeyMapping = @"mapping";

@implementation AMACurrencyMapping

- (instancetype)initWithJSON:(NSDictionary *)json
{
    NSDictionary<NSString *, NSString *> *mappingJSON = json[kAMAKeyMapping];
    NSMutableDictionary<NSString *, NSDecimalNumber *> *mapping = [[NSMutableDictionary alloc] init];
    for (NSString *key in mappingJSON) {
        mapping[key] = [NSDecimalNumber decimalNumberWithString:mappingJSON[key]];
    }
    return [self initWithMapping:mapping];
}

- (instancetype)initWithMapping:(NSDictionary<NSString *, NSDecimalNumber *> *)mapping
{
    self = [super init];
    if (self != nil) {
        _mapping = [mapping copy];
    }
    return self;
}

- (NSDecimalNumber *)convert:(NSDecimalNumber *)number
                    currency:(NSString *)currency
                       scale:(NSInteger)scale
                       error:(NSError **)error
{
    NSDecimalNumber *divisor = self.mapping[currency];
    AMALogInfo(@"For %@ %@ divisor is %@.", number, currency, divisor);
    if (divisor == nil) {
        *error = [NSError errorWithDomain:kAMAAttributionCurrencyErrorDomain
                                     code:AMAAttributionCurrencyErrorUnknownCurrency
                                 userInfo:@{ @"currency" : currency ?: @"nil" }];
        return [NSDecimalNumber zero];
    } else  {
        NSDecimalNumber *scaledNumber = [AMADecimalUtils decimalNumber:number
                                                 bySafelyMultiplyingBy:[[NSDecimalNumber alloc] initWithInteger:scale]
                                                                    or:[NSDecimalNumber zero]];
        return [AMADecimalUtils decimalNumber:scaledNumber
                           bySafelyDividingBy:divisor
                                           or:[NSDecimalNumber zero]];
    }
}

- (NSDictionary *)JSON
{
    NSMutableDictionary<NSString *, NSString *> *mappingJSON = [[NSMutableDictionary alloc] init];
    for (NSString * key in self.mapping) {
        mappingJSON[key] = self.mapping[key].stringValue;
    }
    return @{ kAMAKeyMapping : [mappingJSON copy] };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.mapping=%@", self.mapping];
    [description appendString:@">"];
    return description;
}


@end
