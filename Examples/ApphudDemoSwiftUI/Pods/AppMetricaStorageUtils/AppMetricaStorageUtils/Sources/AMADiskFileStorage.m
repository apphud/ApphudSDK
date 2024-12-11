
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMADiskFileStorage ()

@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, assign, readonly) AMADiskFileStorageOptions options;

@property (atomic, assign) BOOL fileDirectoryExistenceEnsured;
@property (atomic, assign) BOOL noBackupAttibuteEnsured;

@end

@implementation AMADiskFileStorage

- (instancetype)initWithPath:(NSString *)path options:(AMADiskFileStorageOptions)options
{
    self = [super init];
    if (self != nil) {
        _path = [path copy];
        _options = options;
    }
    return self;
}

- (BOOL)fileExists
{
    return [AMAFileUtility fileExistsAtPath:self.path];
}

- (NSData *)readDataWithError:(NSError **)error
{
    NSData *data = [AMAFileUtility rawContentAtFilePath:self.path error:error];
    [self checkNoBackupFlag];
    return data;
}

- (BOOL)writeData:(NSData *)data error:(NSError **)error
{
    if ((self.options & AMADiskFileStorageOptionCreateDirectory) != 0 && self.fileDirectoryExistenceEnsured == NO) {
        [AMAFileUtility createPathIfNeeded:[self.path stringByDeletingLastPathComponent]];
        self.fileDirectoryExistenceEnsured = YES;
    }

    BOOL result = [AMAFileUtility writeData:data filePath:self.path error:error];
    [self checkNoBackupFlag];

    return result;
}

- (BOOL)deleteFileWithError:(NSError *__autoreleasing *)error
{
    return [AMAFileUtility deleteFileAtPath:self.path error:error];
}

- (void)checkNoBackupFlag
{
    if ((self.options & AMADiskFileStorageOptionNoBackup) != 0 && self.noBackupAttibuteEnsured == NO) {
        [AMAFileUtility setSkipBackupAttributesOnPath:self.path];
        self.noBackupAttibuteEnsured = YES;
    }
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ filePath: %@", [super description], self.path];
}
#endif

@end
