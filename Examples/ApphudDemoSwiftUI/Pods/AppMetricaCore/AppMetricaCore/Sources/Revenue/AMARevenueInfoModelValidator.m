
#import "AMACore.h"
#import "AMARevenueInfoModelValidator.h"
#import "AMARevenueInfoModel.h"
#import "AMARevenueInfoProcessingLogger.h"
#import "AMAErrorsFactory.h"

@interface AMARevenueInfoModelValidator ()

@property (nonatomic, strong, readonly) AMARevenueInfoProcessingLogger *logger;

@end

@implementation AMARevenueInfoModelValidator

- (instancetype)init
{
    return [self initWithLogger:[[AMARevenueInfoProcessingLogger alloc] init]];
}

- (instancetype)initWithLogger:(AMARevenueInfoProcessingLogger *)logger
{
    self = [super init];
    if (self != nil) {
        _logger = logger;
    }
    return self;
}

- (BOOL)validateRevenueInfoModel:(AMARevenueInfoModel *)model error:(NSError **)error
{
    NSError *internalError = nil;
    if (model.quantity == 0) {
        internalError = [AMAErrorsFactory zeroRevenueQuantityError];
        [self.logger logZeroQuantity];
    }
    else if ([AMAValidationUtilities validateISO4217Currency:model.currency] == NO) {
        internalError = [AMAErrorsFactory invalidRevenueCurrencyError:model.currency];
        [self.logger logInvalidCurrency:model.currency];
    }
    else if (model.transactionID == nil && model.receiptData != nil) {
        [self.logger logTransactionIDIsMissing];
    }
    else if (model.receiptData == nil && model.transactionID != nil) {
        [self.logger logReceiptDataIsMissing];
    }

    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return internalError == nil;
}

@end
