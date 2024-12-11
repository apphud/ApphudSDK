
#import "AMACore.h"
#import "AMAEventNumbersFiller.h"
#import "AMAEvent.h"
#import "AMASession.h"

@interface AMAEventNumbersFiller ()

@property (nonatomic, strong, readonly) AMAIncrementableValueStorage *globalEventNumberStorage;
@property (nonatomic, strong, readonly) NSMutableDictionary *eventNumberOfTypeStorages;

@end

@implementation AMAEventNumbersFiller

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _globalEventNumberStorage = [AMAIncrementableValueStorageFactory globalEventNumberStorage];
        _eventNumberOfTypeStorages = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)shouldUseGlobalNumberCounterForType:(NSUInteger)eventType
{
    switch (eventType) {
        case AMAEventTypeProtobufCrash:
            return NO;

        default:
            return YES;
    }
}

- (AMAIncrementableValueStorage *)storageOfType:(NSUInteger)eventType
{
    NSNumber *key = @(eventType);
    AMAIncrementableValueStorage *storage = self.eventNumberOfTypeStorages[key];
    if (storage == nil) {
        storage = [AMAIncrementableValueStorageFactory eventNumberOfTypeStorageForEventType:eventType];
        self.eventNumberOfTypeStorages[key] = storage;
    }
    return storage;
}

- (void)fillNumbersOfEvent:(AMAEvent *)event
                   session:(AMASession *)session
                   storage:(id<AMAKeyValueStoring>)storage
                  rollback:(AMARollbackHolder *)rollbackHolder
                     error:(NSError **)error
{
    NSUInteger originalSequenceNumber = event.sequenceNumber;
    event.sequenceNumber = session.eventSeq;
    [rollbackHolder subscribeOnRollback:^{
        event.sequenceNumber = originalSequenceNumber;
    }];

    if ([self shouldUseGlobalNumberCounterForType:event.type]) {
        event.globalNumber =
            [[self.globalEventNumberStorage nextInStorage:storage
                                                 rollback:rollbackHolder
                                                    error:error] unsignedIntegerValue];
    }
    event.numberOfType =
        [[[self storageOfType:event.type] nextInStorage:storage
                                               rollback:rollbackHolder
                                                  error:error] unsignedIntegerValue];
}

@end
