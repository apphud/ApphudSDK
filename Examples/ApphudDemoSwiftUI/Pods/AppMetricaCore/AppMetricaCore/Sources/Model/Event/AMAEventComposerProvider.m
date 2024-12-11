
#import "AMAEventComposerProvider.h"
#import "AMAEventComposer.h"
#import "AMAEventComposerBuilder.h"
#import "AMADummyLocationComposer.h"
#import "AMADummyAppEnvironmentComposer.h"
#import "AMAFilledEventEnvironmentComposer.h"
#import "AMAEventTypes.h"
#import "AMAReporterStateStorage.h"

@interface AMAEventComposerProvider ()

@property(nonatomic, strong, readonly) AMAReporterStateStorage *stateStorage;
@property(nonatomic, strong, readonly) NSDictionary<NSNumber *, AMAEventComposer *> *composers;

@end

@implementation AMAEventComposerProvider

- (instancetype)initWithStateStorage:(AMAReporterStateStorage *)storage
{
    self = [super init];
    if (self != nil) {

        AMAEventComposerBuilder *crashComposerBuilder = [AMAEventComposerBuilder defaultBuilderWithStorage:storage];
        [crashComposerBuilder addAppEnvironmentComposer:[AMADummyAppEnvironmentComposer new]];
        AMAEventComposer *crashComposer = [crashComposerBuilder build];

        AMAEventComposerBuilder *noLocationComposerBuilder =
            [AMAEventComposerBuilder defaultBuilderWithStorage:storage];
        [noLocationComposerBuilder addLocationComposer:[AMADummyLocationComposer new]];
        AMAEventComposer *noLocationComposer = [noLocationComposerBuilder build];

        AMAEventComposerBuilder *errorComposerBuilder = [AMAEventComposerBuilder defaultBuilderWithStorage:storage];
        [errorComposerBuilder addEventEnvironmentComposer:
                                  [[AMAFilledEventEnvironmentComposer alloc] initWithStorage:storage]];
        AMAEventComposer *errorComposer = [errorComposerBuilder build];

        _stateStorage = storage;
        _composers = @{
                @(AMAEventTypeAlive) : noLocationComposer,
                @(AMAEventTypeProtobufCrash) : crashComposer,
                @(AMAEventTypeProtobufANR) : crashComposer,
                @(AMAEventTypeProtobufError) : errorComposer,
                @(28) : noLocationComposer,
        };
    }
    return self;
}

- (AMAEventComposer *)composerForType:(NSUInteger)type
{
    AMAEventComposer *composer = self.composers[@(type)];
    if (!composer) {
        composer = [[AMAEventComposerBuilder defaultBuilderWithStorage:self.stateStorage] build];
    }
    return composer;
}

@end
