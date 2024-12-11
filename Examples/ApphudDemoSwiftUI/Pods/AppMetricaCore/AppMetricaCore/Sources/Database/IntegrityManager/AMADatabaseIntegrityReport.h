
#import <Foundation/Foundation.h>

@class AMASQLiteIntegrityIssue;

@interface AMADatabaseIntegrityReport : NSObject

@property (nonatomic, copy, readonly) NSMutableDictionary<NSString *, NSArray<AMASQLiteIntegrityIssue *> *> *stepIssues;

@property (nonatomic, copy) NSString *firstPassedFixStep;
@property (nonatomic, copy) NSString *lastAppliedFixStep;
@property (nonatomic, strong) NSError *reindexError;
@property (nonatomic, strong) NSError *backupRestoreError;

@end
