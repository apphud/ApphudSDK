
#import "AMASubscriptionInfoModel.h"

@interface AMASubscriptionInfoModel ()

@property (nonatomic, assign, readwrite) BOOL isAutoRenewing;
@property (nonatomic, strong, readwrite) AMASubscriptionPeriod *subscriptionPeriod;

@property (nonatomic, strong, readwrite) NSString *introductoryID;
@property (nonatomic, strong, readwrite) NSDecimalNumber *introductoryPrice;
@property (nonatomic, strong, readwrite) AMASubscriptionPeriod *introductoryPeriod;
@property (nonatomic, assign, readwrite) NSUInteger introductoryPeriodCount;

@end

@implementation AMASubscriptionInfoModel

- (instancetype)initWithIsAutoRenewing:(BOOL)isAutoRenewing
                    subscriptionPeriod:(AMASubscriptionPeriod *)subscriptionPeriod
                        introductoryID:(NSString *)introductoryID
                     introductoryPrice:(NSDecimalNumber *)introductoryPrice
                    introductoryPeriod:(AMASubscriptionPeriod *)introductoryPeriod
               introductoryPeriodCount:(NSUInteger)introductoryPeriodCount
{
    self = [super init];
    if (self != nil) {
        _isAutoRenewing = isAutoRenewing;
        _subscriptionPeriod = subscriptionPeriod;
        _introductoryID = introductoryID;
        _introductoryPrice = introductoryPrice;
        _introductoryPeriod = introductoryPeriod;
        _introductoryPeriodCount = introductoryPeriodCount;
    }

    return self;
}


@end
