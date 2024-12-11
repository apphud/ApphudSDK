
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAEventStorage+Migration.h"
#import "AMAEvent.h"
#import "AMASession.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import "AMADatabaseHelper.h"
#import "AMAEventSerializer.h"
#import "AMAEventNumbersFiller.h"

@interface AMAEventStorage ()

@property (nonatomic, strong, readonly) AMAEventNumbersFiller *eventNumberFiller;

@end

@implementation AMAEventStorage

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                 eventSerializer:(AMAEventSerializer *)eventSerializer
{
    return [self initWithDatabase:database
                  eventSerializer:eventSerializer
                eventNumberFiller:[[AMAEventNumbersFiller alloc] init]];
}

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                 eventSerializer:(AMAEventSerializer *)eventSerializer
               eventNumberFiller:(AMAEventNumbersFiller *)eventNumberFiller
{
    self = [super init];
    if (self != nil) {
        _database = database;
        _eventNumberFiller = eventNumberFiller;
        _eventSerializer = eventSerializer;
    }
    return self;
}

- (BOOL)addEvent:(AMAEvent *)event toSession:(AMASession *)session error:(NSError **)error
{
    NSError *__block internalError = nil;
    [self.database inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        id<AMAKeyValueStoring> storage = [self.database.storageProvider storageForDB:db];
        [self.eventNumberFiller fillNumbersOfEvent:event
                                           session:session
                                           storage:storage
                                          rollback:rollbackHolder
                                             error:&internalError];

        if (rollbackHolder.rollback) {
            AMALogError(@"Failed to fill event number fields: %@ (Event: %@)", internalError, event);
            return;
        }

        BOOL success = YES;
        success = success && [self addEvent:event db:db error:&internalError];
        success = success && [self updateSessionFields:session forLastEvent:event db:db error:&internalError];
        if (success == NO) {
            rollbackHolder.rollback = YES;
            return;
        }
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return internalError == nil;
}

- (BOOL)addEvent:(AMAEvent *)event db:(AMAFMDatabase *)db error:(NSError **)error
{
    NSDictionary *eventDictionary = [self.eventSerializer dictionaryForEvent:event error:error];
    if (eventDictionary == nil) {
        return NO;
    }

    NSNumber *eventOID = [AMADatabaseHelper insertRowWithDictionary:eventDictionary
                                                          tableName:kAMAEventTableName
                                                                 db:db
                                                              error:error];
    if (eventOID != nil) {
        event.oid = eventOID;
    }
    return eventOID != nil;
}

- (BOOL)updateSessionFields:(AMASession *)session
               forLastEvent:(AMAEvent *)event
                         db:(AMAFMDatabase *)db
                      error:(NSError **)error
{
    NSDate *lastEventTime = session.lastEventTime;
    if (lastEventTime == nil
        || [lastEventTime compare:event.createdAt ?: [NSDate distantPast]] != NSOrderedDescending) {
        lastEventTime = event.createdAt;
    }
    else {
        AMALogWarn(@"New event time is smaller than last event time: %@", event);
    }

    NSDictionary *sessionUpdateFields = @{
        kAMASessionTableFieldLastEventTime: @(lastEventTime.timeIntervalSinceReferenceDate),
        kAMASessionTableFieldEventSeq: @(session.eventSeq + 1),
    };
    BOOL success = [AMADatabaseHelper updateFieldsWithDictionary:sessionUpdateFields
                                                        keyField:kAMACommonTableFieldOID
                                                             key:session.oid
                                                       tableName:kAMASessionTableName
                                                              db:db
                                                           error:error];
    if (success) {
        session.lastEventTime = lastEventTime;
        ++session.eventSeq;
    }
    return success;
}

- (NSUInteger)totalCountOfEventsWithTypes:(NSArray *)includedTypes
{
    return [self totalCountOfEventsWithTypes:includedTypes excludingTypes:nil];
}

- (NSUInteger)totalCountOfEventsWithTypes:(NSArray *)includedTypes
                           excludingTypes:(NSArray *)excludedTypes
{
    NSUInteger __block result = 0;
    NSError *__block error = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        result = [AMADatabaseHelper countWhereField:kAMACommonTableFieldType
                                            inArray:includedTypes
                                      andNotInArray:excludedTypes
                                          tableName:kAMAEventTableName
                                                 db:db
                                              error:&error];
    }];
    if (error != nil) {
        AMALogError(@"Failed to fetch events count (including: %@, excluding: %@): %@",
                            includedTypes, excludedTypes, error);
    }
    return result;
}

- (NSArray<AMAEvent*> *)allEvents
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    [self.database inDatabase:^(AMAFMDatabase *db) {
        NSError *error = nil;
        [AMADatabaseHelper enumerateRowsWithFilter:nil
                                             order:nil
                                       valuesArray:@[]
                                         tableName:kAMAEventTableName
                                             limit:INT_MAX
                                                db:db
                                             error:&error
                                             block:^(NSDictionary *dictionary) {
            NSError *deserializationError = nil;
            AMAEvent *event = [self.eventSerializer eventForDictionary:dictionary error:&deserializationError];
            if (deserializationError != nil) {
                AMALogInfo(@"Deserialization error: %@", deserializationError);
            }
            else if (event != nil) {
                [result addObject:event];
            }
        }];
        if (error != nil) {
            AMALogInfo(@"Error: %@", error);
        }
    }];
    return [result copy];
}

#pragma mark - Migration

- (BOOL)addMigratedEvent:(AMAEvent *)event error:(NSError **)error
{
    BOOL __block result = NO;
    NSError *__block internalError = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        result = [self addEvent:event db:db error:&internalError];
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

@end
