
#import "AMACore.h"
#import "AMADatabaseIntegrityProcessor.h"
#import "AMADatabaseIntegrityQueries.h"
#import "AMADatabaseQueueProvider.h"
#import "AMADatabaseIntegrityReport.h"
#import "AMASQLiteIntegrityIssueParser.h"
#import "AMASQLiteIntegrityIssue.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

NSString *const kAMADatabaseIntegrityStepInitial = @"initial";
NSString *const kAMADatabaseIntegrityStepReindex = @"reindex";
NSString *const kAMADatabaseIntegrityStepBackupRestore = @"backup-restore";
NSString *const kAMADatabaseIntegrityStepNewDatabase = @"new-database";

@interface AMADatabaseIntegrityProcessor ()

@property (nonatomic, strong, readonly) AMASQLiteIntegrityIssueParser *parser;

@end

@implementation AMADatabaseIntegrityProcessor

- (instancetype)init
{
    return [self initWithParser:[[AMASQLiteIntegrityIssueParser alloc] init]];
}

- (instancetype)initWithParser:(AMASQLiteIntegrityIssueParser *)parser
{
    self = [super init];
    if (self != nil) {
        _parser = parser;
    }
    return self;
}

- (BOOL)checkIntegrityIssuesForDatabase:(AMAFMDatabaseQueue *)databaseQueue
                                 report:(AMADatabaseIntegrityReport *)report
{
    if (databaseQueue == nil) {
        return NO;
    }

    NSError *error = nil;
    NSArray *issueStrings = [AMADatabaseIntegrityQueries integrityIssuesForDBQueue:databaseQueue error:&error];
    NSArray *issues = nil;

    if (issueStrings != nil) {
        AMALogError(@"DB integrity check found issues: %@", issueStrings);
        issues = [AMACollectionUtilities mapArray:issueStrings withBlock:^id(NSString *issueString) {
            return [self.parser issueForIntegityIssueString:issueString];
        }];
    }
    else {
        AMALogError(@"DB integrity check failed: %@", error);
        issues = @[ [self.parser issueForError:error] ];
    }

    BOOL result = [self areIssuesCritical:issues] == NO;

    NSString *step = report.lastAppliedFixStep ?: kAMADatabaseIntegrityStepInitial;
    report.stepIssues[step] = issues;
    if (result && report.firstPassedFixStep == nil) {
        report.firstPassedFixStep = step;
    }
    return result;
}

- (BOOL)areIssuesCritical:(NSArray<AMASQLiteIntegrityIssue *> *)issues
{
    for (AMASQLiteIntegrityIssue *issue in issues) {
        switch (issue.issueType) {
            case AMASQLiteIntegrityIssueTypeFull:
                // Non critical
                break;
            default:
                return YES;
        }
    }

    return NO;
}

- (BOOL)fixIndexForDatabase:(AMAFMDatabaseQueue *)databaseQueue
                     report:(AMADatabaseIntegrityReport *)report
{
    if (databaseQueue == nil) {
        return NO;
    }

    NSError *error = nil;
    BOOL result = [AMADatabaseIntegrityQueries fixIntegrityForDBQueue:databaseQueue error:&error];
    report.reindexError = error;
    report.lastAppliedFixStep = kAMADatabaseIntegrityStepReindex;
    return result;
}

- (BOOL)fixWithBackupAndRestore:(AMAFMDatabaseQueue **)databaseQueue
                         report:(AMADatabaseIntegrityReport *)report
{
    if (databaseQueue == NULL || *databaseQueue == nil) {
        return NO;
    }

    report.lastAppliedFixStep = kAMADatabaseIntegrityStepBackupRestore;

    AMAFMDatabaseQueue *sourceQueue = *databaseQueue;
    NSString *databasePath = sourceQueue.path;
    NSString *backupDatabasePath = [databasePath stringByAppendingPathExtension:@"bak"];

    NSError *error = nil;
    AMAFMDatabaseQueue *backupQueue = [[AMADatabaseQueueProvider sharedInstance] queueForPath:backupDatabasePath];
    BOOL backupResult = [AMADatabaseIntegrityQueries backupDBQueue:sourceQueue backupDB:backupQueue error:&error];
    
    if (backupResult == NO) {
        [backupQueue close];
        [AMAFileUtility removeFileProtectionForPath:backupDatabasePath];
        [AMAFileUtility deleteFileAtPath:backupDatabasePath];
        report.backupRestoreError = error;
        return NO;
    }

    [sourceQueue close];
    [backupQueue close];

    [AMAFileUtility removeFileProtectionForPath:databasePath];
    [AMAFileUtility removeFileProtectionForPath:backupDatabasePath];

    [AMAFileUtility deleteFileAtPath:databasePath];
    [AMAFileUtility moveFileAtPath:backupDatabasePath toPath:databasePath];

    *databaseQueue = [[AMADatabaseQueueProvider sharedInstance] queueForPath:databasePath];
    return YES;
}

- (BOOL)fixWithCreatingNewDatabase:(AMAFMDatabaseQueue **)databaseQueue
                            report:(AMADatabaseIntegrityReport *)report
{
    if (databaseQueue == NULL || *databaseQueue == nil) {
        return NO;
    }

    report.lastAppliedFixStep = kAMADatabaseIntegrityStepNewDatabase;

    AMAFMDatabaseQueue *sourceQueue = *databaseQueue;
    NSString *databasePath = sourceQueue.path;

    [sourceQueue close];

    [AMAFileUtility removeFileProtectionForPath:databasePath];
    [AMAFileUtility deleteFileAtPath:databasePath];
    AMAFMDatabaseQueue *newQueue = [[AMADatabaseQueueProvider sharedInstance] queueForPath:databasePath];

    *databaseQueue = newQueue;
    return YES;
}

@end
