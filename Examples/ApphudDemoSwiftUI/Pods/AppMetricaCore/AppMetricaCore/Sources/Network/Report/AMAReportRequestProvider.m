
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAReportRequestProvider.h"
#import "AMASessionEventsCollection.h"
#import "AMAEvent.h"
#import "AMASession.h"
#import "AMAReportEventsBatch.h"
#import "AMAReportRequestModel.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMASessionSerializer.h"
#import "AMAEventSerializer.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import "AMADatabaseHelper.h"

@interface AMAReportRequestProvider ()

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, strong, readonly) id<AMADatabaseProtocol> database;
@property (nonatomic, strong, readonly) AMAEventSerializer *eventSerializer;
@property (nonatomic, strong, readonly) AMASessionSerializer *sessionSerializer;

@end

@implementation AMAReportRequestProvider

- (instancetype)initWithApiKey:(NSString *)apiKey
                      database:(id<AMADatabaseProtocol>)database
               eventSerializer:(AMAEventSerializer *)eventSerializer
             sessionSerializer:(AMASessionSerializer *)sessionSerializer
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _database = database;
        _eventSerializer = eventSerializer;
        _sessionSerializer = sessionSerializer;
    }
    return self;
}

#pragma mark - Public -

- (NSArray *)requestModels
{
    NSArray *collections = [self collections];
    NSMutableArray *allBatches = [NSMutableArray array];
    for (AMASessionEventsCollection *collection in collections) {
        NSArray *batches = [self batchEvents:collection.events ofSession:collection.session];
        [allBatches addObjectsFromArray:batches];
    }
    return [self requestModelsForEventBatches:[allBatches copy] apiKey:self.apiKey];
}

- (NSArray *)batchEvents:(NSArray *)events ofSession:(AMASession *)session
{
    NSArray *eventGroups = [self groupItems:events byPredicate:^BOOL(AMAEvent *lhs, AMAEvent *rhs) {
        NSDictionary *lhsAppEnvironment = lhs.appEnvironment;
        NSDictionary *rhsAppEnvironment = rhs.appEnvironment;
        return lhsAppEnvironment == rhsAppEnvironment || [lhsAppEnvironment isEqual:rhsAppEnvironment];
    }];

    NSMutableArray *batches = [NSMutableArray arrayWithCapacity:eventGroups.count];
    for (NSArray *eventGroup in eventGroups) {
        AMAEvent *firstEvent = eventGroup.firstObject;
        AMAReportEventsBatch *batch = [[AMAReportEventsBatch alloc] initWithSession:session
                                                                     appEnvironment:firstEvent.appEnvironment
                                                                             events:eventGroup];
        if (batch != nil) {
            [batches addObject:batch];
        }
    }
    return batches;
}

#pragma mark - Private -

- (NSArray<AMASession *> *)sessionsFromDB:(AMAFMDatabase *)db limit:(NSUInteger)limit error:(NSError **)error
{
    NSMutableArray *result = [NSMutableArray array];
    NSMutableArray *brokenOIDs = [NSMutableArray array];
    [AMADatabaseHelper enumerateRowsWithFilter:nil
                                         order:[NSString stringWithFormat:@"%@ ASC", kAMACommonTableFieldOID]
                                   valuesArray:nil
                                     tableName:kAMASessionTableName
                                         limit:limit
                                            db:db
                                         error:error
                                         block:^(NSDictionary *dictionary) {
        NSError *deserializationError = nil;
        AMASession *session = [self.sessionSerializer sessionForDictionary:dictionary
                                                                     error:&deserializationError];
        if (session != nil) {
            [result addObject:session];
        }
        else {
            AMALogAssert(@"Failed to deserialize session. It will be purged: %@. Error: %@",
                                 dictionary, deserializationError);
            NSNumber *oid = dictionary[kAMACommonTableFieldOID];
            if (oid != nil) {
                [brokenOIDs addObject:oid];
            }
        }
    }];

    if (brokenOIDs.count != 0) {
        NSError *internalError = nil;
        [AMADatabaseHelper deleteRowsWhereKey:kAMACommonTableFieldOID
                                      inArray:brokenOIDs
                                    tableName:kAMASessionTableName
                                           db:db
                                        error:&internalError];
        if (internalError != nil) {
            AMALogError(@"Failed to purge broken sessions: %@", internalError);
        }
    }
    return [result copy];
}

- (NSArray<AMAEvent *> *)eventsForSessionID:(NSNumber *)sessionID
                                         db:(AMAFMDatabase *)db
                                      limit:(NSUInteger)limit
                                      error:(NSError **)error
{
    NSMutableArray *result = [NSMutableArray array];
    NSMutableArray *brokenOIDs = [NSMutableArray array];
    [AMADatabaseHelper enumerateRowsWithFilter:[NSString stringWithFormat:@"%@ = ?", kAMAEventTableFieldSessionOID]
                                         order:[NSString stringWithFormat:@"%@ ASC", kAMACommonTableFieldOID]
                                   valuesArray:@[ sessionID ]
                                     tableName:kAMAEventTableName
                                         limit:limit
                                            db:db
                                         error:error
                                         block:^(NSDictionary *dictionary) {
        NSError *deserializationError = nil;
        AMAEvent *event = [self.eventSerializer eventForDictionary:dictionary error:&deserializationError];
        if (event != nil) {
            [result addObject:event];
        }
        else {
            AMALogAssert(@"Failed to deserialize event. It will be purged: %@. Error: %@",
                                 dictionary, deserializationError);
            NSNumber *oid = dictionary[kAMACommonTableFieldOID];
            if (oid != nil) {
                [brokenOIDs addObject:oid];
            }
        }
    }];

    if (brokenOIDs.count != 0) {
        NSError *internalError = nil;
        [AMADatabaseHelper deleteRowsWhereKey:kAMACommonTableFieldOID
                                      inArray:brokenOIDs
                                    tableName:kAMAEventTableName
                                           db:db
                                        error:&internalError];
        if (internalError != nil) {
            AMALogError(@"Failed to purge broken sessions: %@", internalError);
        }
    }
    return [result copy];
}

- (NSArray<AMASessionEventsCollection *> *)collections
{
    __block NSMutableArray *result = [NSMutableArray array];
    NSUInteger limit = [AMAMetricaConfiguration sharedInstance].inMemory.batchSize;
    NSError *__block error = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        NSArray *sessions = [self sessionsFromDB:db limit:limit error:&error];
        NSUInteger limitLeft = limit;
        for (AMASession *session in sessions) {
            NSArray *events = [self eventsForSessionID:session.oid db:db limit:limitLeft error:&error];
            if (events.count > 0) {
                AMASessionEventsCollection *collection = [[AMASessionEventsCollection alloc] initWithSession:session
                                                                                                      events:events];
                if (collection != nil) {
                    [result addObject:collection];
                }

                limitLeft -= events.count;
                if (limitLeft <= 0) {
                    break;
                }
            }
        }
    }];
    if (error != nil) {
        AMALogError(@"Failed to fetch collections: %@", error);
    }
    return result;
}

- (NSArray *)requestModelsForEventBatches:(NSArray *)batches apiKey:(NSString *)apiKey
{
    NSArray *groupedBatches = [self groupItems:batches byPredicate:^BOOL(AMAReportEventsBatch *lhs, AMAReportEventsBatch *rhs) {
        AMAApplicationState *lhsAppState = lhs.session.appState;
        AMAApplicationState *rhsAppState = rhs.session.appState;
        NSString *lhsAttributionID = lhs.session.attributionID;
        NSString *rhsAttributionID = rhs.session.attributionID;
        return (lhsAppState == rhsAppState               || [lhsAppState isEqual:rhsAppState]) &&
               (lhsAttributionID == rhsAttributionID     || [lhsAttributionID isEqual:rhsAttributionID]) &&
               (lhs.appEnvironment == rhs.appEnvironment || [lhs.appEnvironment isEqual:rhs.appEnvironment]);
    }];

    BOOL inMemoryDatabase = self.database.databaseType == AMADatabaseTypeInMemory;
    NSMutableArray *requestModels = [NSMutableArray array];
    for (NSArray<AMAReportEventsBatch *> *batchesGroup in groupedBatches) {
        AMAReportEventsBatch *firstBatch = batchesGroup.firstObject;
        AMASession *session = firstBatch.session;
        AMAApplicationState *batchAppState = session.appState ?: AMAApplicationStateManager.applicationState;

        AMAReportRequestModel *requestModel =
            [AMAReportRequestModel reportRequestModelWithApiKey:apiKey
                                                  attributionID:session.attributionID
                                                 appEnvironment:firstBatch.appEnvironment
                                                       appState:batchAppState
                                               inMemoryDatabase:inMemoryDatabase
                                                  eventsBatches:batchesGroup];
        if (requestModel != nil) {
            [requestModels addObject:requestModel];
        }
    }
    return requestModels;
}

- (NSArray *)groupItems:(NSArray *)items byPredicate:(BOOL (^)(id, id))predicate {
    NSMutableArray *groups = [NSMutableArray array];
    NSMutableArray *group = nil;
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSUInteger idx = 0; idx < items.count; ++idx) {
        if ([indexSet containsIndex:idx] == NO) {
            id item = items[idx];
            group = [NSMutableArray arrayWithObject:item];
            for (NSUInteger secondIdx = idx + 1; secondIdx < items.count; ++secondIdx) {
                if ([indexSet containsIndex:secondIdx] == NO) {
                    id secondItem = items[secondIdx];
                    if (predicate(item, secondItem)) {
                        [group addObject:secondItem];
                        [indexSet addIndex:secondIdx];
                    }
                }
            }
            [groups addObject:group];
        }
    }
    return groups;
}

@end
