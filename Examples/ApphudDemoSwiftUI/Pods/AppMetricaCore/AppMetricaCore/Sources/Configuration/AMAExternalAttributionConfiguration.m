#import "AMAExternalAttributionConfiguration.h"

#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

static NSString *const AMAExternalAttributionSourceKey = @"source";
static NSString *const AMAExternalAttributionTimestampKey = @"timestamp";
static NSString *const AMAExternalAttributionContentsHashKey = @"contentsHash";

@implementation AMAExternalAttributionConfiguration

- (instancetype)initWithSource:(AMAAttributionSource)source
                     timestamp:(NSDate *)timestamp
                  contentsHash:(NSString *)contentsHash;
{
    self = [super init];
    if (self != nil) {
        _source = source;
        _timestamp = [self truncateDateToNearestSecond:timestamp];
        _contentsHash = contentsHash;
    }
    return self;
}

#pragma mark - Private -

- (NSDate *)truncateDateToNearestSecond:(NSDate *)date
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear |
                                                         NSCalendarUnitMonth |
                                                         NSCalendarUnitDay |
                                                         NSCalendarUnitHour |
                                                         NSCalendarUnitMinute |
                                                         NSCalendarUnitSecond) fromDate:date];
    return [calendar dateFromComponents:components];
}

#pragma mark - AMAJSONSerializable

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil || [json isKindOfClass:[NSDictionary class]] == NO) {
        return nil;
    }
    
    NSString *sourceString = json[AMAExternalAttributionSourceKey];
    if ([sourceString isKindOfClass:[NSString class]] == NO) {
        return nil;
    }
    
    NSNumber *timestampNumber = json[AMAExternalAttributionTimestampKey];
    if ([timestampNumber isKindOfClass:[NSNumber class]] == NO) {
        return nil;
    }
    
    NSString *contentsHash = json[AMAExternalAttributionContentsHashKey];
    if ([contentsHash isKindOfClass:[NSString class]] == NO) {
        return nil;
    }
    
    NSDate *timestamp = [AMATimeUtilities dateFromUnixTimestampNumber:timestampNumber];
    if (timestamp == nil) {
        return nil;
    }
    
    return [self initWithSource:sourceString timestamp:timestamp contentsHash:contentsHash];
}

- (NSDictionary *)JSON
{
    NSNumber *timestampNumber = [AMATimeUtilities unixTimestampNumberFromDate:self.timestamp];
    
    return @{
        AMAExternalAttributionSourceKey: self.source,
        AMAExternalAttributionTimestampKey: timestampNumber,
        AMAExternalAttributionContentsHashKey: self.contentsHash
    };
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return YES;
    }
    if ([object isKindOfClass:[AMAExternalAttributionConfiguration class]] == NO) {
        return NO;
    }
    AMAExternalAttributionConfiguration *other = (AMAExternalAttributionConfiguration *)object;
    
    NSTimeInterval epsilon = 0.1;
    
    NSTimeInterval timeDifference = fabs([self.timestamp timeIntervalSinceDate:other.timestamp]);
    
    BOOL isTimestampEqual = timeDifference <= epsilon;
    
    return [self.source isEqualToString:other.source] &&
           isTimestampEqual &&
           [self.contentsHash isEqualToString:other.contentsHash];
}


- (NSUInteger)hash
{
    return self.source.hash ^ self.timestamp.hash ^ self.contentsHash.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, source: %@, timestamp: %@, contentsHash: %@>",
            NSStringFromClass([self class]), self, self.source, self.timestamp, self.contentsHash];
}

@end
