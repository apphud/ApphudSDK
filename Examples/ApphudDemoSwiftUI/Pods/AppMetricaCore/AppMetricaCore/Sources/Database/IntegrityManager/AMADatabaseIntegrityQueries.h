
#import <Foundation/Foundation.h>

@class AMAFMDatabaseQueue;

@interface AMADatabaseIntegrityQueries : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSArray<NSString *> *)integrityIssuesForDBQueue:(AMAFMDatabaseQueue *)dbQueue error:(NSError **)error;
+ (BOOL)fixIntegrityForDBQueue:(AMAFMDatabaseQueue *)dbQueue error:(NSError **)error;
+ (BOOL)backupDBQueue:(AMAFMDatabaseQueue *)dbQueue backupDB:(AMAFMDatabaseQueue *)backupDBqueue error:(NSError **)error;

@end
