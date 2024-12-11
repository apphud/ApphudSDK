
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>

@interface AMAIncrementableValueStorage ()

@property (nonatomic, assign, readonly) long long defaultValue;

@property (nonatomic, strong) NSNumber *currentValue;

@end

@implementation AMAIncrementableValueStorage

- (instancetype)initWithKey:(NSString *)key defaultValue:(long long)defaultValue
{
    self = [super init];
    if (self != nil) {
        _key = [key copy];
        _defaultValue = defaultValue;
    }
    return self;
}

- (void)restoreFromStorage:(id<AMAReadonlyKeyValueStoring>)storage
{
    if (self.currentValue == nil) {
        @synchronized (self) {
            if (self.currentValue == nil) {
                self.currentValue =
                    [storage longLongNumberForKey:self.key error:nil] ?: [NSNumber numberWithLongLong:self.defaultValue];
            }
        }
    }
}

- (NSNumber *)valueWithStorage:(id<AMAKeyValueStoring>)storage
{
    @synchronized (self) {
        [self restoreFromStorage:storage];
        return self.currentValue;
    }
}

- (NSNumber *)nextInStorage:(id<AMAKeyValueStoring>)storage
                   rollback:(AMARollbackHolder *)rollbackHolder
                      error:(NSError **)error
{
    @synchronized (self) {
        [self restoreFromStorage:storage];
        long long currentValue = [self.currentValue longLongValue];
        long long nextValue = currentValue + 1;
        self.currentValue = [NSNumber numberWithLongLong:nextValue];
        BOOL result = [storage saveLongLongNumber:self.currentValue forKey:self.key error:error];

        if (rollbackHolder != nil) {
            rollbackHolder.rollback = result == NO;
            [rollbackHolder subscribeOnRollback:^{
                self.currentValue = [NSNumber numberWithLongLong:currentValue];
            }];
        }
    }
    return self.currentValue;
}

#pragma mark - Migration

- (BOOL)updateValue:(NSNumber *)value storage:(id<AMAKeyValueStoring>)storage error:(NSError **)error
{
    @synchronized (self) {
        self.currentValue = value;
        return [storage saveLongLongNumber:value forKey:self.key error:error];
    }
}

@end
