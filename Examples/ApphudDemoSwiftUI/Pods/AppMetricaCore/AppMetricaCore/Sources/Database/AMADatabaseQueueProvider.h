
#import <Foundation/Foundation.h>

@class AMAFMDatabaseQueue;

@interface AMADatabaseQueueProvider : NSObject

@property (nonatomic, assign) BOOL logsEnabled;

- (AMAFMDatabaseQueue *)inMemoryQueue;
- (AMAFMDatabaseQueue *)queueForPath:(NSString *)path;

+ (instancetype)sharedInstance;

@end
