#import "AMAErrorEnvironment.h"

#import "AMACrashLogging.h"

@interface AMAErrorEnvironment ()

@property (nonatomic, strong) NSMutableDictionary *environment;

@end

@implementation AMAErrorEnvironment

static NSInteger const kAMAErrorEnvironmentCountLimit = 30;
static NSInteger const kAMAErrorEnvironmentKeyLengthLimit = 50;
static NSInteger const kAMAErrorEnvironmentValueLengthLimit = 4000;
static NSInteger const kAMAErrorEnvironmentTotalLengthLimit = 4500;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _environment = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)addValue:(NSString *)value forKey:(NSString *)key 
{
    if (key.length == 0) {
        return;
    }

    NSString *truncatedKey = (key.length > kAMAErrorEnvironmentKeyLengthLimit)
        ? [key substringToIndex:kAMAErrorEnvironmentKeyLengthLimit]
        : key;
    NSString *truncatedValue = (value.length > kAMAErrorEnvironmentValueLengthLimit) 
        ? [value substringToIndex:kAMAErrorEnvironmentValueLengthLimit]
        : value;

    if (self.environment.count >= kAMAErrorEnvironmentCountLimit && self.environment[truncatedKey] == nil) {
        AMALogWarn(@"Failed to add environment key %@ with value %@, pairs limit hit", truncatedKey, truncatedValue);
        return;
    }

    __block NSUInteger totalLength = truncatedKey.length + truncatedValue.length;
    [self.environment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        if ([key isEqualToString:truncatedKey] == NO) {
            totalLength += key.length + value.length;
        }
    }];

    if (totalLength > kAMAErrorEnvironmentTotalLengthLimit) {
        AMALogWarn(@"Failed to add environment key %@ with value %@, total length limit hit",
                   truncatedKey, truncatedValue);
        return;
    }

    self.environment[truncatedKey] = truncatedValue;
}

- (void)clearEnvironment 
{
    [self.environment removeAllObjects];
}

- (NSDictionary *)currentEnvironment 
{
    return [self.environment copy];
}

@end
