
#import <Foundation/Foundation.h>

@class AMADatabaseIntegrityReport;
@class AMAFMDatabaseQueue;
@class AMASQLiteIntegrityIssueParser;

extern NSString *const kAMADatabaseIntegrityStepInitial;
extern NSString *const kAMADatabaseIntegrityStepReindex;
extern NSString *const kAMADatabaseIntegrityStepBackupRestore;
extern NSString *const kAMADatabaseIntegrityStepNewDatabase;

@interface AMADatabaseIntegrityProcessor : NSObject

- (instancetype)initWithParser:(AMASQLiteIntegrityIssueParser *)parser;

- (BOOL)checkIntegrityIssuesForDatabase:(AMAFMDatabaseQueue *)databaseQueue
                                 report:(AMADatabaseIntegrityReport *)report;

- (BOOL)fixIndexForDatabase:(AMAFMDatabaseQueue *)databaseQueue
                     report:(AMADatabaseIntegrityReport *)report;

- (BOOL)fixWithBackupAndRestore:(AMAFMDatabaseQueue **)databaseQueue
                         report:(AMADatabaseIntegrityReport *)report;

- (BOOL)fixWithCreatingNewDatabase:(AMAFMDatabaseQueue **)databaseQueue
                            report:(AMADatabaseIntegrityReport *)report;

@end
