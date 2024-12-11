
#import "AMAStorageEventsTrimTransaction.h"
#import "AMAEventTypes.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import "AMADatabaseHelper.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAEventsCleaner.h"
#import "AMAEventsCleanupInfo.h"
#import "AMAEventSerializer.h"

@interface AMAStorageEventsTrimTransaction ()

@property (nonatomic, strong, readonly) AMAEventsCleaner *cleaner;
@property (nonatomic, assign, readonly) double trimPercent;
@property (nonatomic, copy, readonly) NSDictionary *importantEventTypePriorities;
@property (nonatomic, strong, readonly) AMAEventSerializer *eventSerializer;

@end

@implementation AMAStorageEventsTrimTransaction

- (instancetype)initWithCleaner:(AMAEventsCleaner *)cleaner
{
    NSDictionary *importantEventTypePriorities = @{
        @2: @[
            @(AMAEventTypeInit),
            @(AMAEventTypeUpdate),
            @(AMAEventTypeFirst),
        ],
        @1: @[
            @(AMAEventTypeCleanup),
        ],
    };
    return [self initWithCleaner:cleaner
                     trimPercent:[AMAMetricaConfiguration sharedInstance].inMemory.trimEventsPercent
    importantEventTypePriorities:importantEventTypePriorities];
}

- (instancetype)initWithCleaner:(AMAEventsCleaner *)cleaner
                    trimPercent:(double)trimPercent
   importantEventTypePriorities:(NSDictionary *)importantEventTypePriorities
{
    self = [super init];
    if (self != nil) {
        _cleaner = cleaner;
        _trimPercent = trimPercent;
        _importantEventTypePriorities = [importantEventTypePriorities copy];
        _eventSerializer = [[AMAEventSerializer alloc] init];
    }
    return self;
}

#pragma mark - Public -

- (void)performTransactionInDatabase:(id<AMADatabaseProtocol>)database
{
    AMAEventsCleanupInfo *__block cleanupInfo = nil;
    [database inDatabase:^(AMAFMDatabase *db) {
        NSError *error = nil;
        cleanupInfo = [self cleanupInfoForDatabase:db error:&error];

        if (cleanupInfo == nil && error != nil) {
            AMALogError(@"Failed to collect events for trimming with error: %@", error);
            return;
        }
    }];

    if (cleanupInfo != nil) {
        NSError *error = nil;
        BOOL success = [self.cleaner purgeAndReportEventsForInfo:cleanupInfo database:database error:&error];
        if (success == NO) {
            AMALogError(@"Failed to trim events with error: %@", error);
        }
    }
    else {
        AMALogInfo(@"Cleanup is not required");
    }
}

#pragma mark - Private -

- (AMAEventsCleanupInfo *)cleanupInfoForDatabase:(AMAFMDatabase *)db error:(NSError **)error
{
    NSError *internalError = nil;
    NSUInteger count = [AMADatabaseHelper countWhereField:nil
                                                  inArray:nil
                                                tableName:kAMAEventTableName
                                                       db:db
                                                    error:&internalError];
    if (internalError != nil) {
        AMALogError(@"Failed to count events: %@", internalError);
        return nil;
    }

    NSUInteger trimCount = (NSUInteger)ceil(count * self.trimPercent);
    if (trimCount == 0) {
        return nil;
    }

    NSMutableArray *valuesArray = [NSMutableArray array];
    NSString *priorityOrder = [self priorityOrderWithValuesArray:valuesArray];
    NSString *order = [NSString stringWithFormat:@"%@ ASC, %@ ASC", priorityOrder, kAMACommonTableFieldOID];

    AMAEventsCleanupInfo *cleanupInfo =
        [[AMAEventsCleanupInfo alloc] initWithReasonType:AMAEventsCleanupReasonTypeDBOverflow];
    [AMADatabaseHelper enumerateRowsWithFilter:nil
                                         order:order
                                   valuesArray:valuesArray
                                     tableName:kAMAEventTableName
                                         limit:trimCount
                                            db:db
                                         error:&internalError
                                         block:^(NSDictionary * _Nonnull dictionary) {
        NSError *deserializationError = nil;
        AMAEvent *event = [self.eventSerializer eventForDictionary:dictionary error:&deserializationError];
        if (deserializationError == nil) {
            [cleanupInfo addEvent:event];
        }
        else {
            AMALogWarn(@"Failed to deserialize event from dictionary: %@", dictionary);
            NSNumber *eventOid = dictionary[kAMACommonTableFieldOID];
            if ([eventOid isKindOfClass:[NSNumber class]]) {
                [cleanupInfo addEventByOid:eventOid];
            }
            else {
                AMALogWarn(@"Failed to get event oid");
            }
        }
    }];

    if (internalError != nil) {
        AMALogError(@"Failed to enumerate events: %@", internalError);
        return nil;
    }

    return cleanupInfo;
}

- (NSString *)priorityOrderWithValuesArray:(NSMutableArray *)valuesArray
{
    NSMutableArray *cases = [NSMutableArray array];
    [self.importantEventTypePriorities enumerateKeysAndObjectsUsingBlock:^(NSNumber *priority, NSArray *eventTypes, BOOL *stop) {
        NSArray *placeholders = [AMACollectionUtilities mapArray:eventTypes withBlock:^id(id item) {
            return @"?";
        }];
        NSString *caseString = [NSString stringWithFormat:@"WHEN %@ IN (%@) THEN %@",
                                kAMACommonTableFieldType, [placeholders componentsJoinedByString:@","], priority];
        [cases addObject:caseString];
        [valuesArray addObjectsFromArray:eventTypes];
    }];
    return [NSString stringWithFormat:@"CASE %@ ELSE 0 END", [cases componentsJoinedByString:@" "]];
}

@end
