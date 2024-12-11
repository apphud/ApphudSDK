
#import "AMACore.h"
#import "AMAEnvironmentLimiter.h"

static NSInteger const kAMAEnvironmentCountLimit = 30;
static NSInteger const kAMAEnvironmentKeyLengthLimit = 50;
static NSInteger const kAMAEnvironmentValueLengthLimit = 4000;
static NSInteger const kAMAEnvironmentTotalLengthLimit = 4500;

@interface AMAEnvironmentLimiter ()

@property (nonatomic, strong, readonly) id<AMAStringTruncating> keyTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> valueTruncator;
@property (nonatomic, assign, readonly) NSUInteger pairsLimit;
@property (nonatomic, assign, readonly) NSUInteger totalLengthLimit;

@end

@implementation AMAEnvironmentLimiter

- (instancetype)init
{
    return [self initWithCountLimit:kAMAEnvironmentCountLimit
                   totalLengthLimit:kAMAEnvironmentTotalLengthLimit
                           keyLimit:kAMAEnvironmentKeyLengthLimit
                         valueLimit:kAMAEnvironmentValueLengthLimit];
}

- (instancetype)initWithCountLimit:(NSUInteger)pairCount
                  totalLengthLimit:(NSUInteger)totalLengthLimit
                          keyLimit:(NSUInteger)keyLimit
                        valueLimit:(NSUInteger)valueLimit
{
    return [self initWithCountLimit:pairCount
                   totalLengthLimit:totalLengthLimit
                       keyTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:keyLimit]
                     valueTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:valueLimit]];
}

- (instancetype)initWithCountLimit:(NSUInteger)pairsLimit
                  totalLengthLimit:(NSUInteger)totalLengthLimit
                      keyTruncator:(id<AMAStringTruncating>)keyTruncator
                    valueTruncator:(id<AMAStringTruncating>)valueTruncator
{
    self = [super init];
    if (self) {
        _pairsLimit = pairsLimit;
        _keyTruncator = keyTruncator;
        _valueTruncator = valueTruncator;
        _totalLengthLimit = totalLengthLimit;
    }

    return self;
}

#pragma mark - Private -

- (NSDictionary *)limitEnvironment:(NSDictionary *)environment
                  afterAddingValue:(NSString *)value
                            forKey:(NSString *)key
{
    NSString *truncatedValue = [self.valueTruncator truncatedString:value onTruncation:^(NSUInteger length) {
        AMALogWarn(@"Truncating value '%@', value is too long", value);
    }];
    NSString *truncatedKey = [self.keyTruncator truncatedString:key onTruncation:^(NSUInteger length) {
        AMALogWarn(@"Truncating key '%@', key is too long", key);
    }];
    if (truncatedKey == nil || truncatedValue == nil) {
        return environment;
    }

    NSDictionary *resultEnvironment = environment;

    if (environment.count >= self.pairsLimit && environment[truncatedKey] == nil) {
        AMALogWarn(@"Failed to add environment key %@ with value %@, pairs limit hit",
                           truncatedKey, truncatedValue);
    }
    else if ([self lengthForEnvironment:environment
                       afterAddingValue:truncatedValue
                                 forKey:truncatedKey] > self.totalLengthLimit) {
        AMALogWarn(@"Failed to add environment key %@ with value %@, total length limit hit",
                           truncatedKey, truncatedValue);
    }
    else {
        NSMutableDictionary *limitedEnvironment = [environment mutableCopy] ?: [NSMutableDictionary dictionary];
        limitedEnvironment[truncatedKey] = truncatedValue;
        resultEnvironment = [limitedEnvironment copy];
    }

    return resultEnvironment;
}

#pragma mark - Private -

- (NSUInteger)lengthForEnvironment:(NSDictionary *)environment
                  afterAddingValue:(NSString *)newValue
                            forKey:(NSString *)newKey
{
    NSUInteger __block length = newKey.length + newValue.length;
    [environment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        if ([key isEqualToString:newKey] == NO) {
            length += key.length + value.length;
        }
    }];
    return length;
}

@end
