
#import "AMAEventsCleaner.h"
#import "AMADatabaseProtocol.h"
#import "AMAEventsCleanupInfo.h"
#import "AMADatabaseConstants.h"
#import "AMADatabaseHelper.h"
#import "AMAReporterProviding.h"
#import "AMAReporter.h"

@interface AMAEventsCleaner ()

@property (nonatomic, strong, readonly) id<AMAReporterProviding> reporterProvider;

@end

@implementation AMAEventsCleaner

- (instancetype)initWithReporterProvider:(id<AMAReporterProviding>)reporterProvider
{
    self = [super init];
    if (self != nil) {
        _reporterProvider = reporterProvider;
    }
    return self;
}

- (BOOL)purgeAndReportEventsForInfo:(AMAEventsCleanupInfo *)cleanupInfo
                           database:(id<AMADatabaseProtocol>)database
                              error:(NSError *__autoreleasing *)error
{
    NSError *__block internalError = nil;
    BOOL __block result = YES;
    [database inDatabase:^(AMAFMDatabase *db) {
        result = [AMADatabaseHelper deleteRowsWhereKey:kAMACommonTableFieldOID
                                               inArray:cleanupInfo.eventOids
                                             tableName:kAMAEventTableName
                                                    db:db
                                                 error:&internalError];
        if (result) {
            cleanupInfo.actualDeletedNumber = [AMADatabaseHelper changesForDB:db];
        }
    }];

    if (result && cleanupInfo.shouldReport) {
        AMAReporter *reporter = (AMAReporter *)self.reporterProvider.reporter;
        [reporter reportCleanupEvent:cleanupInfo.cleanupReport onFailure:^(NSError *reportError) {
            AMALogError(@"Failed to report cleanup event: %@", reportError);
        }];
    }

    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

@end
