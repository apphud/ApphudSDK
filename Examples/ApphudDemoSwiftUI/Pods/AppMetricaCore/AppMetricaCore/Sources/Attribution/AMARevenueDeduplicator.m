
#import "AMACore.h"
#import "AMARevenueDeduplicator.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAMetricaConfiguration.h"
#import "AMAAttributionModelConfiguration.h"

@interface AMARevenueDeduplicator ()

@property (nonatomic, strong, readonly) AMAAttributionModelConfiguration *config;
@property (nonatomic, strong) NSMutableArray<NSString *> *savedIds;

@end

@implementation AMARevenueDeduplicator

- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config
{
    self = [super init];
    if (self != nil) {
        _config = config;
    }
    return self;
}

# pragma mark - Public -

- (BOOL)checkForID:(NSString *)identifier
{
    @synchronized (self) {
        AMALogInfo(@"Checking existence for identifier %@", identifier);
        if (identifier.length == 0) {
            return YES;
        }
        NSArray<NSString *> *savedIds = self.savedIds;
        AMALogInfo(@"Saved ids count: %tu, max count: %@", savedIds.count, self.config.maxSavedRevenueIDs);

        if ([savedIds containsObject:identifier]) {
            return NO;
        }
        NSMutableArray *newSavedIds = [NSMutableArray arrayWithCapacity:savedIds.count + 1];
        NSUInteger startIndex = 0;
        if (savedIds.count == self.config.maxSavedRevenueIDs.unsignedIntegerValue) {
            startIndex = 1;
        }
        for (size_t index = startIndex; index < savedIds.count; index++) {
            [newSavedIds addObject:savedIds[index]];
        }
        if (newSavedIds.count < self.config.maxSavedRevenueIDs.unsignedIntegerValue) {
            [newSavedIds addObject:identifier];
        }
        self.savedIds = newSavedIds;
        [AMAMetricaConfiguration sharedInstance].persistent.revenueTransactionIds = [newSavedIds copy];
        return YES;
    }
}

# pragma mark - Private -

- (NSArray<NSString *> *)savedIds
{
    if (_savedIds != nil) {
        return _savedIds;
    }
    _savedIds = [[AMAMetricaConfiguration sharedInstance].persistent.revenueTransactionIds mutableCopy];
    if (_savedIds == nil) {
        _savedIds = [NSMutableArray array];
    }
    return _savedIds;
}

@end
