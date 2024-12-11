
#import "AMATransactionInfoModel.h"

@interface AMATransactionInfoModel ()

@property (nonatomic, strong, readwrite) NSString *transactionID;
@property (nonatomic, strong, readwrite) NSDate *transactionTime;
@property (nonatomic, assign, readwrite) AMATransactionState transactionState;
@property (nonatomic, strong, readwrite) NSString *secondaryID;
@property (nonatomic, strong, readwrite) NSDate *secondaryTime;

@end

@implementation AMATransactionInfoModel

- (instancetype)initWithTransactionID:(NSString *)transactionID
                      transactionTime:(NSDate *)transactionTime
                     transactionState:(AMATransactionState)transactionState
                          secondaryID:(NSString *)secondaryID
                        secondaryTime:(NSDate *)secondaryTime
{
    self = [super init];
    if (self != nil) {
        _transactionID = transactionID;
        _transactionTime = transactionTime;
        _transactionState = transactionState;
        _secondaryID = secondaryID;
        _secondaryTime = secondaryTime;
    }

    return self;
}


@end
