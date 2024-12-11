
#import "AMACore.h"
#import "AMAEventNameHashesStorageFactory.h"
#import "AMAEventNameHashesStorage.h"
#import "AMADatabaseFactory.h"

NSString *const kAMAEventHashesFileName = @"event_hashes.bin";

@implementation AMAEventNameHashesStorageFactory

+ (AMAEventNameHashesStorage *)storageForApiKey:(NSString *)apiKey main:(BOOL)main
{
    NSString *dirPath = main ? kAMAMainReporterDBPath : apiKey;
    NSString *filePath = [[AMAFileUtility persistentPathForApiKey:dirPath] stringByAppendingPathComponent:kAMAEventHashesFileName];
    return [self storageForPath:filePath];
}

+ (AMAEventNameHashesStorage *)migrationStorageForPath:(NSString *)path
{
    NSString *filePath = [path stringByAppendingPathComponent:kAMAEventHashesFileName];
    return [self storageForPath:filePath];
}

#pragma mark - Private -
+ (AMAEventNameHashesStorage *)storageForPath:(NSString *)filePath
{
    AMADiskFileStorageOptions options = AMADiskFileStorageOptionNoBackup | AMADiskFileStorageOptionCreateDirectory;
    AMADiskFileStorage *fileStorage = [[AMADiskFileStorage alloc] initWithPath:filePath options:options];
    AMAEventNameHashesStorage *storage = [[AMAEventNameHashesStorage alloc] initWithFileStorage:fileStorage];
    return storage;
}

@end
