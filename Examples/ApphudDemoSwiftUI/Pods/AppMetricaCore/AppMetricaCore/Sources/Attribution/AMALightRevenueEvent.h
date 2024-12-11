
#import <Foundation/Foundation.h>

@interface AMALightRevenueEvent : NSObject

@property (nonatomic, strong, readonly) NSDecimalNumber *priceMicros;
@property (nonatomic, copy, readonly) NSString *currency;
@property (nonatomic, assign, readonly) NSUInteger quantity;
@property (nonatomic, copy, readonly) NSString *transactionID;
@property (nonatomic, assign, readonly) BOOL isAuto;
@property (nonatomic, assign, readonly) BOOL isRestore;

- (instancetype)initWithPriceMicros:(NSDecimalNumber *)priceMicros
                           currency:(NSString *)currency
                           quantity:(NSUInteger)quantity
                      transactionID:(NSString *)transactionID
                             isAuto:(BOOL)isAuto
                          isRestore:(BOOL)isRestore;

@end
