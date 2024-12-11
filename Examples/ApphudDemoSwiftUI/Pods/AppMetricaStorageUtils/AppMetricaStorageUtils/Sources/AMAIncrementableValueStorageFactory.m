
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>

static long long const kAMADefaultAttributionID = 1;
static long long const kAMADefaultLastSessionID = 10000000000 - 1;
static long long const kAMADefaultGlobalEventNumber = -1;
static long long const kAMADefaultEventNumberOfType = -1;
static long long const kAMADefaultRequestIdentifier = 0;
static long long const kAMADefaultOpenID = 1;

NSString *const kAMAAttributionIDStorageKey = @"attribution.id";
NSString *const kAMALastSessionIDStorageKey = @"session.id";
NSString *const kAMAGlobalEventNumberStorageKey = @"event.number.global";
NSString *const kAMARequestIdentifierStorageKey = @"request.id";
NSString *const kAMAOpenIDStorageKey = @"open.id";

@implementation AMAIncrementableValueStorageFactory

+ (AMAIncrementableValueStorage *)attributionIDStorage
{
    return [[AMAIncrementableValueStorage alloc] initWithKey:kAMAAttributionIDStorageKey
                                                defaultValue:kAMADefaultAttributionID];
}

+ (AMAIncrementableValueStorage *)openIDStorage
{
    return [[AMAIncrementableValueStorage alloc] initWithKey:kAMAOpenIDStorageKey
                                                defaultValue:kAMADefaultOpenID];
}

+ (AMAIncrementableValueStorage *)lastSessionIDStorage
{
    return [[AMAIncrementableValueStorage alloc] initWithKey:kAMALastSessionIDStorageKey
                                                defaultValue:kAMADefaultLastSessionID];
}

+ (AMAIncrementableValueStorage *)globalEventNumberStorage
{
    return [[AMAIncrementableValueStorage alloc] initWithKey:kAMAGlobalEventNumberStorageKey
                                                defaultValue:kAMADefaultGlobalEventNumber];
}

+ (AMAIncrementableValueStorage *)eventNumberOfTypeStorageForEventType:(NSUInteger)eventType
{
    NSString *identifier = [NSString stringWithFormat:@"event.number.type_%lu", (unsigned long)eventType];
    return [[AMAIncrementableValueStorage alloc] initWithKey:identifier
                                                defaultValue:kAMADefaultEventNumberOfType];
}

+ (AMAIncrementableValueStorage *)requestIdentifierStorage
{
    return [[AMAIncrementableValueStorage alloc] initWithKey:kAMARequestIdentifierStorageKey
                                                defaultValue:kAMADefaultRequestIdentifier];
}

@end
