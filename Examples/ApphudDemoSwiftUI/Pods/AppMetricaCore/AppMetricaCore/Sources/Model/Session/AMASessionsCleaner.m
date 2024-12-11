
#import "AMASessionsCleaner.h"
#import "AMASession.h"
#import "AMAEvent.h"
#import "AMAReportEventsBatch.h"
#import "AMAEventLogger.h"
#import "AMAReportRequestModel.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import "AMADatabaseHelper.h"
#import "AMAEventsCleanupInfo.h"
#import "AMAEventsCleaner.h"

@interface AMASessionsCleaner ()

@property (nonatomic, strong, readonly) id<AMADatabaseProtocol> database;
@property (nonatomic, copy, readonly) NSString *apiKey;

@end

@implementation AMASessionsCleaner

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                   eventsCleaner:(AMAEventsCleaner *)eventsCleaner
                          apiKey:(NSString *)apiKey
{
    self = [super init];
    if (self != nil) {
        _database = database;
        _eventsCleaner = eventsCleaner;
        _apiKey = [apiKey copy];
    }
    return self;
}

#pragma mark - Public -

- (void)purgeSessionWithRequestModel:(AMAReportRequestModel *)requestModel
                              reason:(AMAEventsCleanupReasonType)reasonType
{
    [self purgeSessionWithEventsBatches:requestModel.eventsBatches reason:reasonType];
}

- (void)purgeSessionWithEventsBatches:(NSArray <AMAReportEventsBatch *> *)eventsBatches
                               reason:(AMAEventsCleanupReasonType)reasonType
{
    [self purgeEventBatches:eventsBatches reason:reasonType];
    [self purgeEmptySessions];
}

#pragma mark - Private -

- (void)purgeEventBatches:(NSArray<AMAReportEventsBatch *> *)eventBatches
                   reason:(AMAEventsCleanupReasonType)reasonType
{
    AMAEventsCleanupInfo *cleanupInfo = [[AMAEventsCleanupInfo alloc] initWithReasonType:reasonType];
    NSMutableArray *events = [NSMutableArray array];
    for (AMAReportEventsBatch *batch in eventBatches) {
        for (AMAEvent *event in batch.events) {
            [event cleanup];
            if ([cleanupInfo addEvent:event]) {
                [events addObject:event];
            }
        }
    }

    NSError *error = nil;
    [self.eventsCleaner purgeAndReportEventsForInfo:cleanupInfo database:self.database error:&error];

    if (error == nil) {
        for (AMAEvent *event in events) {
            [[AMAEventLogger sharedInstanceForApiKey:self.apiKey] logEventPurged:event];
        }
    }
    else {
        AMALogError(@"Failed to purge events: %@", error);
    }
}

- (void)purgeEmptySessions
{
    [self purgeEmptySessionsWithType:AMASessionTypeGeneral];
    [self purgeEmptySessionsWithType:AMASessionTypeBackground];
}

- (void)purgeEmptySessionsWithType:(AMASessionType)type
{
    NSError *__block error = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        [AMADatabaseHelper deleteRowsMissingRelationsForKey:kAMACommonTableFieldOID
                                                    inTable:kAMASessionTableName
                                           relationTableKey:kAMAEventTableFieldSessionOID
                                          relationTableName:kAMAEventTableName
                                       descendingOrderField:kAMACommonTableFieldOID
                                                      limit:-1
                                                     offset:2
                                                         db:db
                                                      error:&error];
    }];
    if (error != nil) {
        AMALogError(@"Failed to purge empty sessions of type %lu", (unsigned long)type);
    }
}

@end
