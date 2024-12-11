
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMASessionStorage+Migration.h"
#import "AMADatabaseProtocol.h"
#import "AMADatabaseConstants.h"
#import "AMASessionSerializer.h"
#import "AMAReporterStateStorage.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMADate.h"
#import "AMADatabaseHelper.h"

@interface AMASessionStorage ()

@property (nonatomic, strong, readonly) id<AMADatabaseProtocol> database;
@property (nonatomic, strong, readonly) AMASessionSerializer *serializer;
@property (nonatomic, strong, readonly) AMAReporterStateStorage *stateStorage;

@end

@implementation AMASessionStorage

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                      serializer:(AMASessionSerializer *)serializer
                    stateStorage:(AMAReporterStateStorage *)stateStorage
{
    self = [super init];
    if (self != nil) {
        _database = database;
        _serializer = serializer;
        _stateStorage = stateStorage;
    }
    return self;
}

- (AMASession *)newGeneralSessionCreatedAt:(NSDate *)date error:(NSError **)error
{
    return [self newSessionWithType:AMASessionTypeGeneral startDate:date incrementAttributionID:NO error:error];
}

- (AMASession *)newBackgroundSessionCreatedAt:(NSDate *)date error:(NSError **)error
{
    AMALogInfo(@"Creating new background session");
    return [self newSessionWithType:AMASessionTypeBackground startDate:date incrementAttributionID:NO error:error];
}

- (AMASession *)newFinishedBackgroundSessionCreatedAt:(NSDate *)date
                                             appState:(AMAApplicationState *)appState
                                                error:(NSError **)error
{
    return [self newSessionWithType:AMASessionTypeBackground
                          startDate:date
                           finished:YES
                           appState:appState
             incrementAttributionID:NO
                              error:error];
}

- (AMASession *)newSessionWithNextAttributionIDCreatedAt:(NSDate *)date
                                                    type:(AMASessionType)type
                                                   error:(NSError **)error
{
    return [self newSessionWithType:type startDate:date incrementAttributionID:YES error:error];
}

- (AMASession *)lastSessionWithError:(NSError **)error
{
    AMASession *session = [self lastSessionWithFilter:nil values:@[] error:error];
    if (session != nil) {
        [self configureStateValuesForSession:session];
    }
    return session;
}

- (AMASession *)lastGeneralSessionWithError:(NSError **)error
{
    return [self lastSessionWithType:AMASessionTypeGeneral error:error];
}

- (AMASession *)lastSessionWithType:(AMASessionType)type error:(NSError **)error
{
    NSString *filter = [NSString stringWithFormat:@"%@ = ?", kAMACommonTableFieldType];
    AMASession *session = [self lastSessionWithFilter:filter values:@[ @(type) ] error:error];
    if (session != nil) {
        [self configureStateValuesForSession:session];
    }
    return session;
}

- (AMASession *)previousSessionForSession:(AMASession *)session error:(NSError **)error
{
    if (session == nil) {
        return nil;
    }
    NSString *filter = [NSString stringWithFormat:@"%@ < ?", kAMACommonTableFieldOID];
    AMASession *previousSession = [self lastSessionWithFilter:filter values:@[ session.oid ] error:error];
    return previousSession;
}

- (BOOL)saveSessionAsLastSession:(AMASession *)session error:(NSError **)error
{
    if (session == nil) {
        return YES;
    }

    BOOL __block result = YES;
    NSError *__block internalError = nil;
    // This method will create a copy of session with the last oid in DB.
    [self.database inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        BOOL isFinished = session.isFinished;
        result = [self updateSessionFields:@{ kAMASessionTableFieldFinished: @YES }
                                forSession:session
                                inDatabase:db
                                     error:&internalError
                                 onSuccess:^{
                                     session.finished = YES;
                                 }];
        if (result == NO) {
            AMALogError(@"Failed to mark session as finished: %@", internalError);
            rollbackHolder.rollback = YES;
            return;
        }

        NSNumber *oid = session.oid;
        session.oid = nil;
        session.finished = isFinished;
        result = [self insertSession:session inDB:db error:&internalError];
        if (result == NO) {
            AMALogError(@"Failed to save new session as last: %@", internalError);
            rollbackHolder.rollback = YES;
            session.oid = oid;
            return;
        }
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

- (BOOL)updateSession:(AMASession *)session pauseTime:(NSDate *)pauseTime error:(NSError **)error
{
    NSDictionary *updateDictionary = @{
        kAMASessionTableFieldPauseTime: @(pauseTime.timeIntervalSinceReferenceDate),
    };
    return [self updateSessionFields:updateDictionary forSession:session error:error onSuccess:^{
        session.pauseTime = pauseTime;
    }];
}

- (BOOL)updateSession:(AMASession *)session appState:(AMAApplicationState *)appState error:(NSError **)error
{
    NSError *internalError = nil;
    session.appState = appState;
    NSData *data = [self.serializer commonDataForSession:session error:&internalError];
    
    if (data == nil || internalError != nil) {
        AMALogError(@"Failed to serialize session data: %@", internalError);
        if (error != nil) {
            *error = internalError;
        }
        return NO;
    }
    
    NSDictionary *updateDictionary = @{ kAMACommonTableFieldData: data };
    return [self updateSessionFields:updateDictionary forSession:session error:error onSuccess:nil];
}

- (BOOL)finishSession:(AMASession *)session atDate:(NSDate *)date error:(NSError **)error
{
    NSDate *pauseTime = date ?: session.pauseTime;
    NSDictionary *updateDictionary = @{
        kAMASessionTableFieldFinished: @YES,
        kAMASessionTableFieldPauseTime: @(pauseTime.timeIntervalSinceReferenceDate)
    };
    return [self updateSessionFields:updateDictionary forSession:session error:error onSuccess:^{
        session.finished = YES;
        session.pauseTime = pauseTime;
    }];
}

#pragma mark - Migration

- (BOOL)addMigratedSession:(AMASession *)session error:(NSError **)error
{
    BOOL __block result = NO;
    NSError *__block internalError = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        result = [self insertSession:session inDB:db error:&internalError];
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

#pragma mark - Private

- (AMASession *)newSessionWithType:(AMASessionType)type
                         startDate:(NSDate *)startDate
            incrementAttributionID:(BOOL)incrementAttributionID
                             error:(NSError **)error
{
    return [self newSessionWithType:type
                          startDate:startDate
                           finished:NO
                           appState:AMAApplicationStateManager.applicationState
             incrementAttributionID:incrementAttributionID
                              error:error];
}

- (AMASession *)newSessionWithType:(AMASessionType)type
                         startDate:(NSDate *)startDate
                          finished:(BOOL)finished
                          appState:(AMAApplicationState *)appState
            incrementAttributionID:(BOOL)incrementAttributionID
                             error:(NSError **)error
{
    AMADate *sessionStartDate = [[AMADate alloc] init];
    sessionStartDate.deviceDate = startDate;
    sessionStartDate.serverTimeOffset = [AMAMetricaConfiguration sharedInstance].startup.serverTimeOffset;

    AMASession *__block resultSession = nil;
    NSError *__block internalError = nil;
    [self.database inTransaction:^(AMAFMDatabase *db, AMARollbackHolder *rollbackHolder) {
        id<AMAKeyValueStoring> storage = [self.database.storageProvider storageForDB:db];

        AMASession *session = [[AMASession alloc] init];
        session.type = type;
        session.startDate = sessionStartDate;
        session.pauseTime = startDate;
        session.lastEventTime = nil;
        session.eventSeq = 0;
        session.appState = appState;
        session.finished = finished;

        session.sessionID = [self.stateStorage.sessionIDStorage nextInStorage:storage
                                                                     rollback:rollbackHolder
                                                                        error:&internalError];
        if (rollbackHolder.rollback) {
            AMALogError(@"Failed to increment session id");
            return;
        }

        NSNumber *attributionID = [self.stateStorage.attributionIDStorage valueWithStorage:storage];
        if (incrementAttributionID) {
            attributionID = [self.stateStorage.attributionIDStorage nextInStorage:storage
                                                                         rollback:rollbackHolder
                                                                            error:&internalError];
            if (rollbackHolder.rollback) {
                AMALogError(@"Failed to increment attribution id");
                return;
            }
        }
        session.attributionID = [attributionID stringValue];

        if ([self insertSession:session inDB:db error:&internalError] == NO) {
            AMALogError(@"Failed to save session(%@): %@", session, internalError);
            rollbackHolder.rollback = YES;
            return;
        }

        resultSession = session;
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return resultSession;
}

- (AMASession *)lastSessionWithFilter:(NSString *)filter values:(NSArray *)values error:(NSError **)error
{
    AMASession *__block session = nil;
    NSError *__block internalError = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        NSDictionary *sessionDictionary = [AMADatabaseHelper firstRowWithFilter:filter
                                                                          order:[NSString stringWithFormat:@"%@ DESC", kAMACommonTableFieldOID]
                                                                    valuesArray:values
                                                                      tableName:kAMASessionTableName
                                                                             db:db
                                                                          error:&internalError];
        if (sessionDictionary != nil) {
            session = [self.serializer sessionForDictionary:sessionDictionary error:&internalError];
        }
    }];
    return session;
}

- (BOOL)updateSessionFields:(NSDictionary *)fieldsDictionary
                 forSession:(AMASession *)session
                      error:(NSError **)error
                  onSuccess:(dispatch_block_t)onSuccess
{
    NSError *__block internalError = nil;
    BOOL __block result = YES;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        result = [self updateSessionFields:fieldsDictionary
                                forSession:session
                                inDatabase:db
                                     error:&internalError
                                 onSuccess:onSuccess];
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

- (BOOL)updateSessionFields:(NSDictionary *)fieldsDictionary
                 forSession:(AMASession *)session
                 inDatabase:(AMAFMDatabase *)db
                      error:(NSError **)error
                  onSuccess:(dispatch_block_t)onSuccess
{
    BOOL result = [AMADatabaseHelper updateFieldsWithDictionary:fieldsDictionary
                                                       keyField:kAMACommonTableFieldOID
                                                            key:session.oid
                                                      tableName:kAMASessionTableName
                                                             db:db
                                                          error:error];
    if (result && onSuccess != nil) {
        onSuccess();
    }
    return result;
}

- (BOOL)insertSession:(AMASession *)session
                 inDB:(AMAFMDatabase *)db
                error:(NSError **)error
{
    NSDictionary *sessionDictionary = [self.serializer dictionaryForSession:session error:error];
    NSNumber *sessionOID = [AMADatabaseHelper insertRowWithDictionary:sessionDictionary
                                                            tableName:kAMASessionTableName
                                                                   db:db
                                                                error:error];
    if (sessionOID != nil) {
        session.oid = sessionOID;
    }
    return sessionOID != nil;
}

- (void)configureStateValuesForSession:(AMASession *)session
{
    if (session.appState == nil) {
        session.appState = AMAApplicationStateManager.applicationState;
    }
}

@end
