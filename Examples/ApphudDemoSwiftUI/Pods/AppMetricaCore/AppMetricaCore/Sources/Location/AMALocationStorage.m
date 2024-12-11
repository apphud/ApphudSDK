
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMALocationStorage.h"
#import "AMALocationCollectingConfiguration.h"
#import "AMALocationSerializer.h"
#import "AMALocation.h"
#import "AMADatabaseFactory.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseHelper.h"
#import "AMADatabaseConstants.h"
#import "AMALocationStorageState.h"
#import "AMAErrorsFactory.h"
#import "AMAVisit.h"
#import "AMATypeSafeDictionaryHelper.h"
#import "AMALocationEncoderFactory.h"

static NSString *const kAMANextLocationIdentifierKey = @"next.item.id";
static NSString *const kAMANextVisitIdentifierKey = @"next.visit.id";
static NSString *const kAMANextRequestIdentifierKey = @"next.request.id";
static double const kAMALocationsOverflowPurgingFactor = 0.1;

@interface AMALocationStorage ()

@property (nonatomic, strong, readonly) AMALocationCollectingConfiguration *configuration;
@property (nonatomic, strong, readonly) AMALocationSerializer *serializer;
@property (nonatomic, strong, readonly) id<AMADatabaseProtocol> database;
@property (nonatomic, strong, readonly) id<AMADataEncoding> crypter;

@property (nonatomic, strong) AMALocationStorageState *state;

@end

@implementation AMALocationStorage

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
{
    return [self initWithConfiguration:configuration
                            serializer:[[AMALocationSerializer alloc] init]
                              database:[AMADatabaseFactory locationDatabase]
                               crypter:[AMALocationEncoderFactory encoder]];
}

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
                           serializer:(AMALocationSerializer *)serializer
                             database:(id<AMADatabaseProtocol>)database
                              crypter:(id<AMADataEncoding>)crypter
{
    self = [super init];
    if (self != nil) {
        _configuration = configuration;
        _serializer = serializer;
        
        _database = database;
        [_database.storageProvider addBackingKeys:@[
            kAMANextLocationIdentifierKey,
            kAMANextVisitIdentifierKey,
            kAMANextRequestIdentifierKey,
        ]];
        
        _crypter = crypter;
    }
    return self;
}

#pragma mark - Public -

- (void)addLocations:(NSArray<AMALocation *> *)locations
{
    // Enforce state load
    [self locationStorageState];

    for (AMALocation *location in locations) {
        NSNumber *identifier = @(self.state.locationIdentifier);
        AMALocation *identifiedLocation = [location locationByChangingIdentifier:identifier];
        NSData *data = [self.serializer dataForLocations:@[ identifiedLocation ]];
        NSData *encryptedData = [self.crypter encodeData:data error:NULL];
        if (encryptedData != nil) {
            [self addLocationWithData:encryptedData
                           identifier:identifiedLocation.identifier
                          collectDate:identifiedLocation.collectDate
                       nextIdentifier:self.state.locationIdentifier + 1];
        }
    }
}

- (NSArray<AMALocation *> *)locationsWithLimit:(NSUInteger)locationsLimit
{
    return [self objectsWithLimit:locationsLimit
                        tableName:kAMALocationsTableName
                  deserialization:^id(NSData *data) { return [[self.serializer locationsForData:data] firstObject]; }];
}

- (void)purgeLocationsWithIdentifiers:(NSArray<NSNumber *> *)locationIdentifiers
{
    if (locationIdentifiers.count == 0) {
        return;
    }

    AMALogInfo(@"Purging %lu locations", (unsigned long)locationIdentifiers.count);
    [self inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        NSError *error = nil;
        [AMADatabaseHelper deleteRowsWhereKey:kAMACommonTableFieldOID
                                      inArray:locationIdentifiers
                                    tableName:kAMALocationsTableName
                                           db:db
                                        error:&error];

        NSDate *firstLocationDate = nil;
        NSUInteger locationsCount = 0;
        if (error == nil) {
            firstLocationDate = [self firstLocationDateWithDB:db error:&error];
        }
        if (error == nil) {
            locationsCount = [self locationsCountWithDB:db error:&error];
        }

        if (error == nil) {
            @synchronized (self) {
                self.state = [self.state stateByChangingLocationsCount:locationsCount
                                                     firstLocationDate:firstLocationDate];
            }
        }
        else {
            AMALogError(@"Failed to purge locations: %@", error);
            rollbackHolder.rollback = YES;
        }
    }];
}

- (id<AMALSSLocationsProviding>)locationStorageState
{
    if (self.state == nil) {
        @synchronized (self) {
            if (self.state == nil) {
                [self.database inDatabase:^(AMAFMDatabase *db) {
                    [self ensureStateLoaded:db];
                }];
            }
        }
    }
    return self.state;
}

- (void)addVisit:(AMAVisit *)visit
{
    // Enforce state load
    [self locationStorageState];
    
    NSNumber *identifier = @(self.state.visitIdentifier);
    AMAVisit *identifiedVisit = [visit visitByChangingIdentifier:identifier];
    NSData *data = [self.serializer dataForVisits:@[ identifiedVisit ]];
    NSData *encryptedData = [self.crypter encodeData:data error:NULL];
    if (encryptedData != nil) {
        [self addVisitWithData:encryptedData
                    identifier:identifiedVisit.identifier
                   collectDate:identifiedVisit.collectDate
                nextIdentifier:self.state.visitIdentifier + 1];
    }
}

- (NSArray<AMAVisit *> *)visitsWithLimit:(NSUInteger)visitsLimit
{
    return [self objectsWithLimit:visitsLimit
                        tableName:kAMALocationsVisitsTableName
                  deserialization:^id(NSData *data) { return [self.serializer visitsForData:data].firstObject; }];
}

- (void)purgeVisitsWithIdentifiers:(NSArray<NSNumber *> *)visitIdentifiers
{
    if (visitIdentifiers.count == 0) {
        return;
    }

    AMALogInfo(@"Purging %lu visits", (unsigned long)visitIdentifiers.count);
    [self inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        NSError *error = nil;
        [AMADatabaseHelper deleteRowsWhereKey:kAMACommonTableFieldOID
                                      inArray:visitIdentifiers
                                    tableName:kAMALocationsVisitsTableName
                                           db:db
                                        error:&error];

        NSUInteger visitsCount = 0;
        if (error == nil) {
            visitsCount = [self visitsCountWithDB:db error:&error];
        }

        if (error == nil) {
            @synchronized (self) {
                self.state = [self.state stateByChangingVisitsCount:visitsCount];
            }
        }
        else {
            AMALogError(@"Failed to purge visits: %@", error);
            rollbackHolder.rollback = YES;
        }
    }];
}

- (void)incrementRequestIdentifier
{
    [self.database inDatabase:^(AMAFMDatabase *db) {
        [self ensureStateLoaded:db];
        unsigned long long nextIdentifier = self.state.requestIdentifier + 1;

        NSError *error = nil;
        id<AMAKeyValueStoring> storage = [self.database.storageProvider storageForDB:db];
        [storage saveUnsignedLongLongNumber:@(nextIdentifier)
                                     forKey:kAMANextRequestIdentifierKey
                                      error:&error];

        @synchronized (self) {
            self.state = [self.state stateByChangingRequestIdentifier:nextIdentifier];
        }
        if (error != nil) {
            AMALogError(@"Failed to update request identifier: %@", error);
        }
    }];
}

#pragma mark - Private -

- (void)addLocationWithData:(NSData *)data
                 identifier:(NSNumber *)identifier
                collectDate:(NSDate *)collectDate
             nextIdentifier:(unsigned long long)nextIdentifier
{
    AMALogInfo(@"Add location with identifier: %@", identifier);
    [self inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        NSError *error = nil;
        NSUInteger count = self.state.locationsCount;
        NSDate *firstLocationDate = self.state.firstLocationDate ?: collectDate;
        if (count == self.configuration.maxRecordsToStoreLocally) {
            count -= [self purgeFirstLocationsInDB:db error:&error];
            firstLocationDate = [self firstLocationDateWithDB:db error:&error] ?: collectDate;
        }
        if (error == nil) {
            NSDictionary *locationDictionary = @{
                kAMACommonTableFieldOID : identifier,
                kAMALocationsTableFieldTimestamp : @(collectDate.timeIntervalSince1970),
                kAMACommonTableFieldData : data,
            };
            [AMADatabaseHelper insertRowWithDictionary:locationDictionary
                                             tableName:kAMALocationsTableName
                                                    db:db
                                                 error:&error];
            ++count;
        }
        if (error == nil) {
            id<AMAKeyValueStoring> storage = [self.database.storageProvider storageForDB:db];
            [storage saveUnsignedLongLongNumber:@(nextIdentifier)
                                         forKey:kAMANextLocationIdentifierKey
                                          error:&error];
        }
        if (error == nil) {
            @synchronized (self) {
                self.state = [self.state stateByChangingLocationIdentifier:nextIdentifier
                                                            locationsCount:count
                                                         firstLocationDate:firstLocationDate];
            }
        }
        else {
            AMALogError(@"Failed to save location: %@", error);
            rollbackHolder.rollback = YES;
        }
    }];
}

- (void)addVisitWithData:(NSData *)data
              identifier:(NSNumber *)identifier
             collectDate:(NSDate *)collectDate
          nextIdentifier:(unsigned long long)nextIdentifier
{
    AMALogInfo(@"Add visit with identifier: %@", identifier);
    [self inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        NSError *error = nil;
        NSDictionary *visitDictionary = @{
            kAMACommonTableFieldOID : identifier,
            kAMALocationsTableFieldTimestamp : @(collectDate.timeIntervalSince1970),
            kAMACommonTableFieldData : data,
        };
        [AMADatabaseHelper insertRowWithDictionary:visitDictionary
                                         tableName:kAMALocationsVisitsTableName
                                                db:db
                                             error:&error];
        if (error == nil) {
            id<AMAKeyValueStoring> storage = [self.database.storageProvider storageForDB:db];
            [storage saveUnsignedLongLongNumber:@(nextIdentifier)
                                         forKey:kAMANextVisitIdentifierKey
                                          error:&error];
        }
        if (error == nil) {
            @synchronized (self) {
                self.state = [self.state stateByChangingVisitIdentifier:nextIdentifier
                                                            visitsCount:self.state.visitsCount + 1];
            }
        }
        else {
            AMALogError(@"Failed to save visit: %@", error);
            rollbackHolder.rollback = YES;
        }
    }];
}

- (NSArray *)objectsWithLimit:(NSUInteger)limit
                    tableName:(NSString *)tableName
              deserialization:(id (^)(NSData *))deserialization
{
    if (limit == 0) {
        return @[];
    }
    NSArray *__block objects = nil;
    AMALogInfo(@"Collecting pending objects from '%@' table", tableName);
    [self.database inDatabase:^(AMAFMDatabase *db) {

        NSMutableArray *mutableArray = [NSMutableArray array];
        NSError *error = nil;
        
        __auto_type callback = ^void(NSDictionary *dictionary) {
            NSData *encryptedData = dictionary[kAMACommonTableFieldData];
            if (encryptedData == (id)[NSNull null]) {
                encryptedData = nil;
            }
            else if (encryptedData != nil && [encryptedData isKindOfClass:[NSData class]] == NO) {
                AMALogError(@"Invalid type for %s: expected %s but was %@",
                                    "encryptedData", "NSData", [encryptedData class]);
            }
            else {
                NSData *data = [self.crypter decodeData:encryptedData error:NULL];
                id object = deserialization(data);
                if (object != nil) {
                    [mutableArray addObject:object];
                }
                else {
                    AMALogError(@"Failed to deserialize object from '%@' table", tableName);
                }
            }
        };
        [AMADatabaseHelper enumerateRowsWithFilter:nil
                                             order:self.order
                                       valuesArray:nil
                                         tableName:tableName
                                             limit:limit
                                                db:db
                                             error:&error
                                             block:callback];
        if (error == nil) {
            objects = [mutableArray copy];
        }
        else {
            AMALogError(@"Failed to collect objects from '%@' table: %@", tableName, error);
        }
    }];
    return objects;
}

- (NSUInteger)purgeFirstLocationsInDB:(AMAFMDatabase *)db error:(NSError **)error
{
    NSUInteger limit = (NSUInteger)ceil(self.state.locationsCount * kAMALocationsOverflowPurgingFactor);
    AMALogInfo(@"Locations limit is reached. Purging first %lu rows.", (unsigned long)limit);
    [AMADatabaseHelper deleteFirstRowsWithCount:limit
                                         filter:nil
                                          order:self.order
                                    valuesArray:nil
                                      tableName:kAMALocationsTableName
                                             db:db
                                          error:error];
    return limit;
}

- (void)inTransaction:(void (^)(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder))block
{
    [self.database inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        [self ensureStateLoaded:db];
        block(db, rollbackHolder);
    }];
}

- (void)ensureStateLoaded:(AMAFMDatabase *)db
{
    if (self.state != nil) {
        return;
    }

    NSError *error = nil;
    NSArray *identifierKeys = @[
        kAMANextVisitIdentifierKey,
        kAMANextLocationIdentifierKey,
        kAMANextRequestIdentifierKey,
    ];
    id<AMAKeyValueStoring> identifiers = [self.database.storageProvider nonPersistentStorageForKeys:identifierKeys
                                                                                                 db:db
                                                                                              error:&error];
    unsigned long long nextLocationIdentifier = [[identifiers unsignedLongLongNumberForKey:kAMANextLocationIdentifierKey
                                                                                     error:nil] unsignedLongLongValue];
    unsigned long long nextVisitIdentifier = [[identifiers unsignedLongLongNumberForKey:kAMANextVisitIdentifierKey
                                                                                  error:nil] unsignedLongLongValue];
    unsigned long long nextRequestIdentifier = [[identifiers unsignedLongLongNumberForKey:kAMANextRequestIdentifierKey
                                                                                    error:nil] unsignedLongLongValue];
    NSDate *firstLocationDate = [self firstLocationDateWithDB:db error:&error];
    NSUInteger locationsCount = [self locationsCountWithDB:db error:&error];
    NSUInteger visitsCount = [self visitsCountWithDB:db error:&error];

    if (error != nil) {
        AMALogError(@"Failed to load one or more identifiers: %@", error);
    }

    @synchronized (self) {
        self.state = [[AMALocationStorageState alloc] initWithLocationIdentifier:nextLocationIdentifier
                                                                 visitIdentifier:nextVisitIdentifier
                                                               requestIdentifier:nextRequestIdentifier
                                                                  locationsCount:locationsCount
                                                               firstLocationDate:firstLocationDate
                                                                     visitsCount:visitsCount];
    }
}

- (NSDate *)firstLocationDateWithDB:(AMAFMDatabase *)db error:(NSError **)error
{
    NSDate *firstLocationDate = nil;
    NSError *internalError = nil;
    NSDictionary *firstLocationDictionary = [AMADatabaseHelper firstRowWithFilter:nil
                                                                            order:self.order
                                                                      valuesArray:nil
                                                                        tableName:kAMALocationsTableName
                                                                               db:db
                                                                            error:&internalError];
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber, timestamp, firstLocationDictionary[kAMALocationsTableFieldTimestamp]);
    if (timestamp != nil) {
        firstLocationDate = [NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue];
    }
    if (internalError != nil) {
        AMALogError(@"Failed to load first location date");
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return firstLocationDate;
}

- (NSUInteger)locationsCountWithDB:(AMAFMDatabase *)database error:(NSError **)error
{
    return [self countForTable:kAMALocationsTableName db:database error:error];
}

- (NSUInteger)visitsCountWithDB:(AMAFMDatabase *)database error:(NSError **)error
{
    return [self countForTable:kAMALocationsVisitsTableName db:database error:error];
}

- (NSUInteger)countForTable:(NSString *)tableName db:(AMAFMDatabase *)db error:(NSError **)error
{
    NSError *internalError = nil;
    NSUInteger locationsCount = [AMADatabaseHelper countWhereField:nil
                                                           inArray:nil
                                                         tableName:tableName
                                                                db:db
                                                             error:&internalError];
    if (internalError != nil) {
        AMALogError(@"Failed to load '%@' table count", tableName);
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return locationsCount;
}

- (NSString *)order
{
    return [NSString stringWithFormat:@"%@ ASC, %@ ASC", kAMALocationsTableFieldTimestamp, kAMACommonTableFieldOID];
}

@end
