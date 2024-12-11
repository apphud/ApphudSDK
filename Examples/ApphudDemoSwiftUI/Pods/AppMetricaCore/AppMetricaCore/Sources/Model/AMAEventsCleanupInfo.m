
#import "AMACore.h"
#import "AMAEventsCleanupInfo.h"
#import "AMAEvent.h"

@interface AMAEventsCleanupInfo ()

@property (nonatomic, assign, readonly) AMAEventsCleanupReasonType reasonType;
@property (nonatomic, strong, readonly) NSMutableArray<NSNumber *> *oids;
@property (nonatomic, strong, readonly) NSMutableArray<NSNumber *> *eventTypes;
@property (nonatomic, strong, readonly) NSMutableArray<NSNumber *> *globalNumbers;
@property (nonatomic, strong, readonly) NSMutableArray<NSNumber *> *numbersOfType;

@property (nonatomic, assign) NSUInteger oidOnlyEventsCount;

@end

@implementation AMAEventsCleanupInfo

- (instancetype)initWithReasonType:(AMAEventsCleanupReasonType)reasonType
{
    self = [super init];
    if (self != nil) {
        _reasonType = reasonType;
        _oids = [NSMutableArray array];
        _eventTypes = [NSMutableArray array];
        _globalNumbers = [NSMutableArray array];
        _numbersOfType = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public -

- (BOOL)addEvent:(AMAEvent *)event
{
    if (event.oid == nil) {
        AMALogError(@"Can't delete event without id");
        return NO;
    }

    [self.oids addObject:event.oid];

    [self.eventTypes addObject:@(event.type)];
    [self.globalNumbers addObject:@(event.globalNumber)];
    [self.numbersOfType addObject:@(event.numberOfType)];

    return YES;
}

- (void)addEventByOid:(NSNumber *)oid
{
    if (oid == nil) {
        AMALogAssert(@"OID can't be nil");
        return;
    }
    [self.oids addObject:oid];
    ++self.oidOnlyEventsCount;
}

#pragma mark - Private -

- (BOOL)shouldReport
{
    switch (self.reasonType) {
        case AMAEventsCleanupReasonTypeSuccessfulReport:
            return NO;

        case AMAEventsCleanupReasonTypeBadRequest:
        case AMAEventsCleanupReasonTypeEntityTooLarge:
        case AMAEventsCleanupReasonTypeDBOverflow:
            return YES;
    }

    AMALogAssert(@"Unexpected reason type");
    return NO;
}

- (NSArray<NSNumber *> *)eventOids
{
    return [self.oids copy];
}

- (NSString *)reasonName
{
    switch (self.reasonType) {
        case AMAEventsCleanupReasonTypeSuccessfulReport:
            return @"successful_report";

        case AMAEventsCleanupReasonTypeBadRequest:
            return @"bad_request";

        case AMAEventsCleanupReasonTypeEntityTooLarge:
            return @"entity_too_large";

        case AMAEventsCleanupReasonTypeDBOverflow:
            return @"db_overflow";
    }
    
    AMALogAssert(@"Unexpected reason type");
    return @"unknown";
}

- (NSDictionary *)cleanupReport
{
    return @{
        @"details": @{
            @"reason": [self reasonName],
            @"cleared": @{
                @"event_type": [self.eventTypes copy],
                @"global_number": [self.globalNumbers copy],
                @"number_of_type": [self.numbersOfType copy],
            },
            @"actual_deleted_number": @(self.actualDeletedNumber),
            @"corrupted_number": @(self.oidOnlyEventsCount),
        },
    };
}

@end
