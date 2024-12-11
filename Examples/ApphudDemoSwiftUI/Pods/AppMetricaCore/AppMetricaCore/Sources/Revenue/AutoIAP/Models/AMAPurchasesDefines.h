
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMATransactionState) {
    AMATransactionStateUndefined = 0,
    AMATransactionStatePurchased,
    AMATransactionStateRestored,
};

typedef NS_ENUM(NSUInteger, AMAInAppType) {
    AMAInAppTypePurchase,
    AMAInAppTypeSubscription,
};

typedef NS_ENUM(NSUInteger, AMATimeUnit) {
    AMATimeUnitUndefined = 0,
    AMATimeUnitDay,
    AMATimeUnitWeek,
    AMATimeUnitMonth,
    AMATimeUnitYear,
};
