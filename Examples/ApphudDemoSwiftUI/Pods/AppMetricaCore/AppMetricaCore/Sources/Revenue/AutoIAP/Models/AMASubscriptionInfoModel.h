
#import <Foundation/Foundation.h>

@class AMASubscriptionPeriod;

@interface AMASubscriptionInfoModel : NSObject

@property (nonatomic, assign, readonly) BOOL isAutoRenewing;
@property (nonatomic, strong, readonly) AMASubscriptionPeriod *subscriptionPeriod;

@property (nonatomic, strong, readonly) NSString *introductoryID;
@property (nonatomic, strong, readonly) NSDecimalNumber *introductoryPrice;
@property (nonatomic, strong, readonly) AMASubscriptionPeriod *introductoryPeriod;
@property (nonatomic, assign, readonly) NSUInteger introductoryPeriodCount;

- (instancetype)initWithIsAutoRenewing:(BOOL)isAutoRenewing
                    subscriptionPeriod:(AMASubscriptionPeriod *)subscriptionPeriod
                        introductoryID:(NSString *)introductoryID
                     introductoryPrice:(NSDecimalNumber *)introductoryPrice
                    introductoryPeriod:(AMASubscriptionPeriod *)introductoryPeriod
               introductoryPeriodCount:(NSUInteger)introductoryPeriodCount;


@end
