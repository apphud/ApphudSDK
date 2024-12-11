
#import "AMACore.h"
#import "AMAEventSumBoundBasedModelHelper.h"
#import "AMABoundMapping.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMABoundMappingChecker.h"

@interface AMAEventSumBoundBasedModelHelper ()

@property (nonatomic, strong, readonly) AMABoundMappingChecker *boundMappingChecker;

@end

@implementation AMAEventSumBoundBasedModelHelper

- (instancetype)init
{
    return [self initWithBoundMappingChecker:[[AMABoundMappingChecker alloc] init]];
}

- (instancetype)initWithBoundMappingChecker:(AMABoundMappingChecker *)boundMappingChecker
{
    self = [super init];
    if (self != nil) {
        _boundMappingChecker = boundMappingChecker;
    }
    return self;
}

- (NSNumber *)calculateNewConversionValue:(NSDecimalNumber *)sumAddition
                            boundMappings:(NSArray<AMABoundMapping *> *)boundMappings
{
    NSDecimalNumber *eventSum = [AMAMetricaConfiguration sharedInstance].persistent.eventSum;
    AMALogInfo(@"Old sum: %@, addition: %@", eventSum, sumAddition);
    NSDecimalNumber *newSum = [AMADecimalUtils decimalNumber:eventSum
                                              bySafelyAdding:sumAddition
                                                          or:eventSum];
    [AMAMetricaConfiguration sharedInstance].persistent.eventSum = newSum;
    NSNumber *result = [self.boundMappingChecker check:newSum mappings:boundMappings];
    AMALogInfo(@"For %@ result is %@", newSum, result);
    return result;
}

@end
