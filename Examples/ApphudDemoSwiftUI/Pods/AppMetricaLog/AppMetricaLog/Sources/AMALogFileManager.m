
#import <AppMetricaLog/AppMetricaLog.h>
#import "AMALogFileManager.h"
#import "AMALogFile.h"
#import "AMALogFileFactory.h"

#ifdef AMA_ENABLE_FILE_LOG
@interface AMALogFileManager ()

@property (nonatomic, copy) NSString *logsDirectoryPath;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) AMALogFileFactory *logFileFactory;

@end

@implementation AMALogFileManager

- (instancetype)initWithLogsDirectory:(NSString *)logsDirectoryPath
                       logFileFactory:(AMALogFileFactory *)logFileFactory
{
    return [self initWithLogsDirectory:logsDirectoryPath
                        logFileFactory:logFileFactory
                           fileManager:[NSFileManager new]];
}

- (instancetype)initWithLogsDirectory:(NSString *)logsDirectoryPath
                       logFileFactory:(AMALogFileFactory *)logFileFactory
                          fileManager:(NSFileManager *)fileManager
{
    NSParameterAssert(logsDirectoryPath);
    NSParameterAssert(fileManager);

    self = [super init];
    if (self) {
        _logsDirectoryPath = [logsDirectoryPath copy];
        _logFileFactory = logFileFactory;
        _fileManager = fileManager;
    }

    return self;
}

- (NSArray *)retrieveLogFiles
{
    NSURL *dirURL = [NSURL fileURLWithPath:self.logsDirectoryPath];
    NSError *error = nil;
    NSArray *entries = [self.fileManager contentsOfDirectoryAtURL:dirURL
                                       includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                            error:&error];
    if (error != nil) {
        return nil;
    }

    NSMutableArray *logFiles = [NSMutableArray new];
    for (NSURL *entry in entries) {
        NSNumber *isDirectory = nil;
        [entry getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];

        if ([isDirectory boolValue]) {
            continue;
        }

        AMALogFile *logFile = [self.logFileFactory logFileFromFilePath:entry.path];
        if (logFile != nil) {
            [logFiles addObject:logFile];
        }
    }

    return logFiles;
}

- (void)removeLogFiles:(NSArray *)logFiles
{
    for (AMALogFile *logFile in logFiles) {
        NSString *filePath = [self filePathForLogFile:logFile];

        BOOL isDirectory = NO;
        BOOL fileExists = [self.fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];
        if (isDirectory || fileExists == NO) {
            continue;
        }

        NSError *error = nil;
        [self.fileManager removeItemAtPath:filePath error:&error];
        NSAssert(error == nil, @"Failed to remove log file with error %@", error.localizedDescription);
    }
}

- (NSFileHandle *)fileHandleForLogFile:(AMALogFile *)logFile
{
    if (logFile == nil) {
        return nil;
    }

    if ([self.fileManager fileExistsAtPath:self.logsDirectoryPath] == NO) {
        NSError *error = nil;
        BOOL directoryCreated = [self.fileManager createDirectoryAtPath:self.logsDirectoryPath
                                            withIntermediateDirectories:YES
                                                             attributes:nil
                                                                  error:&error];
        if (directoryCreated == NO || error) {
            NSAssert(NO, @"Failed to create logs directory with error %@",
                     error.localizedDescription);
            return nil;
        }
    }

    NSString *filePath = [self filePathForLogFile:logFile];
    if ([self.fileManager fileExistsAtPath:filePath] == NO) {
        BOOL fileCreated = [self.fileManager createFileAtPath:filePath contents:nil attributes:nil];
        if (fileCreated == NO) {
            NSAssert(NO, @"Failed to create log file at path %@", filePath);
            return nil;
        }
    }

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    return fileHandle;
}

- (NSString *)filePathForLogFile:(AMALogFile *)logFile
{
    if (logFile == nil) {
        return nil;
    }
    return [self.logsDirectoryPath stringByAppendingPathComponent:logFile.fileName];
}

@end

#endif //AMA_ENABLE_FILE_LOG
