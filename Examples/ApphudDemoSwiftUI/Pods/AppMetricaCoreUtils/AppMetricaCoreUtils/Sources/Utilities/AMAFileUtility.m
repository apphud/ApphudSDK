
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"
#import <sys/xattr.h>

static NSStringEncoding const kAMAFileEncoding = NSUTF8StringEncoding;
static NSString *const kAMAFilePath = @"io.appmetrica";

@implementation AMAFileUtility

#pragma mark - Public

+ (NSString *)pathForFileName:(NSString *)fileName withExtension:(NSString *)extension
{
    NSString *fullFileName = [fileName stringByAppendingPathExtension:extension];
    return [self pathForFullFileName:fullFileName];
}

+ (NSString *)pathForFullFileName:(NSString *)fullFileName
{
    NSString *basePath = [self cacheDirectoryPath];
    [self createPathIfNeeded:basePath];
    return [basePath stringByAppendingPathComponent:fullFileName];
}

+ (NSArray *)pathsForFilesWithExtension:(NSString *)extension
{
    NSString *outputPath = [self cacheDirectoryPath];

    NSError *error = nil;
    NSArray *allFiles = [self sortedByDateContentOfDirectory:outputPath error:&error];

    NSArray *paths = nil;
    if (error == nil) {
        NSPredicate *extensionPredicate =
            [NSPredicate predicateWithBlock:^BOOL(NSString *filePath, NSDictionary *bindings) {
                return [filePath.pathExtension isEqualToString:extension];
            }];
        paths = [allFiles filteredArrayUsingPredicate:extensionPredicate];
    }

    return paths;
}

+ (BOOL)deleteFileAtPath:(NSString *)filePath error:(NSError * __autoreleasing *)error
{
    NSError *internalError = nil;
    BOOL result = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&internalError];
    if (result) {
        AMALogInfo(@"File deleted: %@", filePath);
    }
    else {
        [AMAErrorUtilities fillError:error withError:internalError];
        AMALogError(@"Failed to delete file %@ with error: %@", filePath, internalError);
    }
    return result;
}

+ (NSError *)deleteFileAtPath:(NSString *)filePath
{
    NSError * __autoreleasing error = nil;
    [self deleteFileAtPath:filePath error:&error];
    return error;
}

+ (BOOL)fileExistsAtPath:(NSString *)filePath
{
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

+ (NSString *)contentAtFilePath:(NSString *)filePath error:(NSError * __autoreleasing *)error
{
    NSData *fileData = [self rawContentAtFilePath:filePath error:error];
    return [[NSString alloc] initWithData:fileData encoding:kAMAFileEncoding];
}

+ (NSData *)rawContentAtFilePath:(NSString *)filePath error:(NSError * __autoreleasing *)error
{
    NSError *internalError = nil;
    AMALogInfo(@"Reading content of file: %@", filePath);
    NSData *result = [NSData dataWithContentsOfFile:filePath options:NSDataReadingUncached error:&internalError];
    if (result != nil) {
        AMALogInfo(@"File reading complete: %@", filePath);
    }
    else {
        [AMAErrorUtilities fillError:error withError:internalError];
        AMALogError(@"Failed to read file %@ with error: %@", filePath, internalError);
    }
    return result;
}

+ (BOOL)writeData:(NSData *)report filePath:(NSString *)outputPath error:(NSError * __autoreleasing *)error
{
    NSError *internalError = nil;
    NSDictionary *backupAttributes = nil;
    NSURL *fileURL = [NSURL fileURLWithPath:outputPath];
    if ([self fileExistsAtPath:outputPath]) {
        backupAttributes = [fileURL resourceValuesForKeys:self.class.supportedResourceKeys error:&internalError];
    }
    
    BOOL isSuccess = internalError == nil;
    isSuccess = isSuccess && [report writeToFile:outputPath options:NSDataWritingAtomic error:&internalError];
    
    if (backupAttributes != nil) {
        isSuccess = isSuccess && [fileURL setResourceValues:backupAttributes error:&internalError];
    }
    
    if (isSuccess) {
        AMALogInfo(@"Saved data to: %@", outputPath);
    }
    else {
        [AMAErrorUtilities fillError:error withError:internalError];
        AMALogError(@"Failed to save file %@ with error: %@", outputPath, internalError);
    }
    return isSuccess;
}

+ (BOOL)writeString:(NSString *)report filePath:(NSString *)outputPath error:(NSError * __autoreleasing *)error
{
    NSData *data = [report dataUsingEncoding:kAMAFileEncoding];
    return [self writeData:data filePath:outputPath error:error];
}

+ (BOOL)setSkipBackupAttributesOnPath:(NSString *)path
{
    NSError *error = nil;
    BOOL result = [[NSURL fileURLWithPath:path] setResourceValue:@YES
                                                          forKey:NSURLIsExcludedFromBackupKey
                                                           error:&error];
    if (result == NO) {
        AMALogError(@"Error excluding '%@' from backup: %@", path, error);
    }
    return result;
}

+ (BOOL)removeFileProtectionForPath:(NSString *)path
{
    BOOL result = YES;
    NSDictionary *fileAttributes = @{ NSFileProtectionKey: NSFileProtectionNone };
    NSError *error = nil;
    if ([[NSFileManager defaultManager] setAttributes:fileAttributes ofItemAtPath:path error:&error] == NO) {
        AMALogWarn(@"Failed to remove file protection from database at path '%@': %@", path, error);
        result = NO;
    }
    return result;
}

+ (BOOL)moveFileAtPath:(NSString *)sourcePath toPath:(NSString *)targetPath
{
    BOOL result = YES;
    NSError *error = nil;
    if ([[NSFileManager defaultManager] moveItemAtPath:sourcePath toPath:targetPath error:&error] == NO) {
        AMALogWarn(@"Failed to move file '%@' -> '%@': %@", sourcePath, targetPath, error);
        result = NO;
    }
    return result;
}

+ (NSString *)persistentPathForApiKey:(NSString *)apiKey
{
#if TARGET_OS_TV
    NSString *path = self.cacheDirectoryPath;
#else
    NSString *path = self.applicationSupportDirectoryPath;
#endif
    return [path stringByAppendingPathComponent:apiKey];
}

+ (NSString *)persistentPath
{
    return [self persistentPathForApiKey:nil];
}

+ (NSString *)cacheDirectoryPath
{
    return [self basePathForSystemType:NSCachesDirectory];
}

+ (BOOL)createPathIfNeeded:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL result = YES;
    if ([fm fileExistsAtPath:path] == NO) {
        NSError * __autoreleasing error = nil;
        result = [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (result) {
            AMALogInfo(@"Path created: %@", path);
        }
        else {
            AMALogError(@"Failed to create path %@ with error: %@", path, error);
        }
    }
    return result;
}

#pragma mark - Private -

+ (NSArray<NSURLResourceKey> *)supportedResourceKeys
{
    return @[ NSURLIsExcludedFromBackupKey ];
}

+ (NSArray *)sortedByDateContentOfDirectory:(NSString *)directoryPath error:(NSError **)error
{
    NSError *internalError = nil;
    NSArray *directoryContent =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL URLWithString:directoryPath]
                                      includingPropertiesForKeys:@[ NSURLContentModificationDateKey ]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:&internalError];

    NSArray *paths = nil;
    if (directoryContent != nil) {
        NSArray *allFiles = [directoryContent sortedArrayUsingComparator:^(NSURL *file1, NSURL *file2) {
            NSDate *file1Date = nil;
            [file1 getResourceValue:&file1Date forKey:NSURLContentModificationDateKey error:nil];

            NSDate *file2Date = nil;
            [file2 getResourceValue:&file2Date forKey:NSURLContentModificationDateKey error:nil];

            NSComparisonResult result = NSOrderedSame;
            if (file1Date != nil && file2Date != nil) {
                result = [file1Date compare:file2Date];
            }
            return result;
        }];

        NSMutableArray *filePaths = [NSMutableArray array];
        for (NSURL *fileURL in allFiles) {
            NSString *filePath = fileURL.path;
            if (filePath != nil) {
                [filePaths addObject:filePath];
            }
        }
        paths = [filePaths copy];
    }

    if (error != NULL) {
        *error = internalError;
    }

    return paths;
}

+ (NSString *)basePathForSystemType:(NSSearchPathDirectory)systemType
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(systemType, NSUserDomainMask, YES);
    NSString *basePath = [paths firstObject];
    NSString *path = [basePath stringByAppendingPathComponent:kAMAFilePath];
    AMALogInfo(@"Base path of type '%lu' is: %@", (unsigned long)systemType, path);
    return path;
}

+ (NSString *)applicationSupportDirectoryPath
{
    return [self basePathForSystemType:NSApplicationSupportDirectory];
}

+ (NSDictionary *)fileSystemAttributes:(NSError * __autoreleasing *)error
{
    return [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:error];
}

@end
