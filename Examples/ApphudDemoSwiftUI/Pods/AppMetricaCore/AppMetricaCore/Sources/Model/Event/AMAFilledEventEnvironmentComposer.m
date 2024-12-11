
#import "AMAFilledEventEnvironmentComposer.h"
#import "AMAReporterStateStorage.h"
#import "AMACore.h"

@interface AMAFilledEventEnvironmentComposer ()

@property(nonatomic, strong, readonly)AMAReporterStateStorage *stateStorage;

@end

@implementation AMAFilledEventEnvironmentComposer

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage
{
    self = [super init];
    if (self != nil) {
        _stateStorage = storage;
    }
    return self;
}

- (NSDictionary *)compose
{
    NSDictionary *eventEnvironment = self.stateStorage.eventEnvironment.dictionaryEnvironment;
    return eventEnvironment.count != 0 ? eventEnvironment : nil;
}

@end
