
#import "AMACore.h"
#import "AMAAdRevenueInfoModelValidator.h"
#import "AMAAdRevenueInfoModel.h"
#import "AMAAdRevenueInfoProcessingLogger.h"
#import "AMAErrorsFactory.h"

@interface AMAAdRevenueInfoModelValidator ()

@property (nonatomic, strong, readonly) AMAAdRevenueInfoProcessingLogger *logger;

@end

@implementation AMAAdRevenueInfoModelValidator

- (instancetype)init
{
    return [self initWithLogger:[[AMAAdRevenueInfoProcessingLogger alloc] init]];
}

- (instancetype)initWithLogger:(AMAAdRevenueInfoProcessingLogger *)logger
{
    self = [super init];
    if (self != nil) {
        _logger = logger;
    }
    return self;
}

- (BOOL)validateAdRevenueInfoModel:(AMAAdRevenueInfoModel *)model error:(NSError **)error
{
    NSError *internalError = nil;
    if ([AMAValidationUtilities validateISO4217Currency:model.currency] == NO) {
        internalError = [AMAErrorsFactory invalidAdRevenueCurrencyError:model.currency];
        [self.logger logInvalidCurrency:model.currency];
    }

    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return internalError == nil;
}

@end
