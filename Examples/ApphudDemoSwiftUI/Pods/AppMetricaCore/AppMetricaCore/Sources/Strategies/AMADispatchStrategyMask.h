
typedef NS_OPTIONS(NSUInteger, AMADispatchStrategyMask) {
    AMADispatchStrategyTypeCount = 1 << 0,
    AMADispatchStrategyTypeTimer = 1 << 1,
    AMADispatchStrategyTypeUrgent = 1 << 2
};
