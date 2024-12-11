
#import "AMAFilledAppEnvironmentComposer.h"
#import "AMAReporterStateStorage.h"
#import "AMACore.h"

@interface AMAFilledAppEnvironmentComposer()

@property(nonatomic, strong, readonly) AMAReporterStateStorage *stateStorage;

@end

@implementation AMAFilledAppEnvironmentComposer

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
    NSDictionary *appEnvironment = self.stateStorage.appEnvironment.dictionaryEnvironment;
    return appEnvironment.count != 0 ? appEnvironment : nil;
}

@end
