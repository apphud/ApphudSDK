
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(FileUtility)
@interface AMAFileUtility : NSObject

+ (NSString *)pathForFileName:(NSString *)fileName withExtension:(NSString *)extension;

+ (NSString *)pathForFullFileName:(NSString *)fullFileName;

+ (NSArray *)pathsForFilesWithExtension:(NSString *)extension;

+ (BOOL)deleteFileAtPath:(NSString *)filePath error:(NSError * __autoreleasing *)error;

+ (NSError *)deleteFileAtPath:(NSString *)filePath;

+ (BOOL)fileExistsAtPath:(NSString *)filePath;

+ (NSString *)contentAtFilePath:(NSString *)filePath error:(NSError * __autoreleasing *)error;

+ (NSData *)rawContentAtFilePath:(NSString *)filePath error:(NSError * __autoreleasing *)error;

+ (BOOL)writeData:(NSData *)report filePath:(NSString *)outputPath error:(NSError * __autoreleasing *)error;

+ (BOOL)writeString:(NSString *)report filePath:(NSString *)filePath error:(NSError * __autoreleasing *)error;

+ (BOOL)setSkipBackupAttributesOnPath:(NSString *)path;

+ (BOOL)removeFileProtectionForPath:(NSString *)path;

+ (BOOL)moveFileAtPath:(NSString *)sourcePath toPath:(NSString *)targetPath;

+ (NSString *)persistentPathForApiKey:(nullable NSString *)apiKey;

+ (NSString *)persistentPath;

+ (NSString *)cacheDirectoryPath;

+ (BOOL)createPathIfNeeded:(NSString *)path;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
