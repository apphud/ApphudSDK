
#import "AMACore.h"
#import "AMADatabaseIntegrityQueries.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import <sqlite3.h>
#import "AMASQLiteIntegrityIssue.h"

@implementation AMADatabaseIntegrityQueries

+ (NSArray<NSString *> *)integrityIssuesForDBQueue:(AMAFMDatabaseQueue *)dbQueue error:(NSError **)error
{
    NSError *__block internalError = nil;
    NSMutableArray *integrityCheckIssues = [NSMutableArray array];
    [dbQueue inDatabase:^(AMAFMDatabase *db) {
        AMAFMResultSet *rs = [db executeQuery:@"PRAGMA integrity_check(5)" values:@[] error:&internalError];
        while ([rs nextWithError:&internalError]) {
            NSString *value = [rs stringForColumnIndex:0];
            if (value != nil) {
                [integrityCheckIssues addObject:value];
            }
        }
        [rs close];
    }];

    if (integrityCheckIssues.count == 1 && [integrityCheckIssues.firstObject isEqual:@"ok"]) {
        [integrityCheckIssues removeAllObjects];
    }
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
        integrityCheckIssues = nil;
    }
    return [integrityCheckIssues copy];
}

+ (BOOL)fixIntegrityForDBQueue:(AMAFMDatabaseQueue *)dbQueue error:(NSError **)error
{
    BOOL __block result = NO;
    NSError *__block internalError = nil;
    [dbQueue inDatabase:^(AMAFMDatabase *db) {
        result = [db executeUpdate:@"REINDEX" values:@[] error:&internalError];
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

+ (BOOL)backupDBQueue:(AMAFMDatabaseQueue *)dbQueue backupDB:(AMAFMDatabaseQueue *)backupDBqueue error:(NSError **)error
{
    BOOL __block result = YES;
    NSError *__block internalError = nil;
    [dbQueue inDatabase:^(AMAFMDatabase *sourceDB) {
        [backupDBqueue inDatabase:^(AMAFMDatabase *targetDB) {
            sqlite3_backup *backupHandle = sqlite3_backup_init(targetDB.sqliteHandle, "main",
                                                               sourceDB.sqliteHandle, "main");
            if (backupHandle == NULL) {
                internalError = targetDB.lastError;
                return;
            }

            int returnCode = 0;
            do {
                returnCode = sqlite3_backup_step(backupHandle, -1);
            } while (returnCode == SQLITE_OK);
            result = (returnCode == SQLITE_DONE);
            if (result == NO) {
                NSString *errorMessage = [[NSString alloc] initWithUTF8String:sqlite3_errstr(returnCode)];
                internalError = [NSError errorWithDomain:kAMAFMDBErrorDomain
                                                    code:returnCode
                                                userInfo:@{ NSLocalizedDescriptionKey: errorMessage ?: @"" }];
            }

            sqlite3_backup_finish(backupHandle);
        }];
    }];
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

@end
