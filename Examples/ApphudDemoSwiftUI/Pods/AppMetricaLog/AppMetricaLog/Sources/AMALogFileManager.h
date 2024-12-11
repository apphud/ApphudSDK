
#import <Foundation/Foundation.h>

#ifdef AMA_ENABLE_FILE_LOG
@class AMALogFile;
@class AMALogFileFactory;

@interface AMALogFileManager : NSObject

- (instancetype)initWithLogsDirectory:(NSString *)logsDirectoryPath
                       logFileFactory:(AMALogFileFactory *)logFileFactor;

- (instancetype)initWithLogsDirectory:(NSString *)logsDirectoryPath
                       logFileFactory:(AMALogFileFactory *)logFileFactor
                          fileManager:(NSFileManager *)fileManager;

- (NSArray *)retrieveLogFiles;
- (void)removeLogFiles:(NSArray *)logFiles;

- (NSFileHandle *)fileHandleForLogFile:(AMALogFile *)logFile;

@end

#endif //AMA_ENABLE_FILE_LOG
