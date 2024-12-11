
#import <Foundation/Foundation.h>
#import "AMAPurchasesDefines.h"

@interface AMATransactionInfoModel : NSObject

@property (nonatomic, strong, readonly) NSString *transactionID;
@property (nonatomic, strong, readonly) NSDate *transactionTime;
@property (nonatomic, assign, readonly) AMATransactionState transactionState;
@property (nonatomic, strong, readonly) NSString *secondaryID;
@property (nonatomic, strong, readonly) NSDate *secondaryTime;

- (instancetype)initWithTransactionID:(NSString *)transactionID
                      transactionTime:(NSDate *)transactionTime
                     transactionState:(AMATransactionState)transactionState
                          secondaryID:(NSString *)secondaryID
                        secondaryTime:(NSDate *)secondaryTime;

@end
