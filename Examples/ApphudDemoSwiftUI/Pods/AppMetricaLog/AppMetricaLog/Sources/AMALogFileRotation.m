
#import "AMALogFileRotation.h"
#import "AMALogFile.h"

#ifdef AMA_ENABLE_FILE_LOG

@interface AMALogFileRotation ()

@property (nonatomic, copy, readwrite) NSArray *filesToRemove;
@property (nonatomic, strong, readwrite) NSNumber *nextSerialNumber;

@end

@implementation AMALogFileRotation

+ (instancetype)rotationForLogFiles:(NSArray *)logFiles withMaxFilesAllowed:(NSUInteger)maxFilesCount
{
    AMALogFileRotation *rotation = [AMALogFileRotation new];

    NSArray *sortedFiles = [rotation sortedFilesBySequenceNumber:logFiles];

    NSUInteger filesCount = maxFilesCount > 0 ? maxFilesCount - 1 : 0;
    NSArray *filesToRemove = [rotation filesToRemoveFromLogFiles:sortedFiles
                                             withMaxFilesAllowed:filesCount];
    rotation.filesToRemove = filesToRemove;

    if (maxFilesCount != 0) {
        NSNumber *nextSerialNumber = [rotation nextSerialNumberForFiles:sortedFiles];
        rotation.nextSerialNumber = nextSerialNumber;
    }

    return rotation;
}

- (instancetype)initWithFilesToRemove:(NSArray *)removeFiles nextSerialNumber:(NSNumber *)serialNumber
{
    self = [super init];
    if (self) {
        _filesToRemove = [removeFiles copy];
        _nextSerialNumber = serialNumber;
    }
    return self;
}

- (NSArray *)filesToRemoveFromLogFiles:(NSArray *)logFiles withMaxFilesAllowed:(NSUInteger)maxCountAllowed
{
    if (logFiles.count <= maxCountAllowed) {
        return nil;
    }

    NSUInteger removeCount = logFiles.count - maxCountAllowed;
    NSRange removeRange = NSMakeRange(0, removeCount);
    NSArray *removeFiles = [logFiles subarrayWithRange:removeRange];
    return removeFiles;
}

- (NSArray *)sortedFilesBySequenceNumber:(NSArray *)logFiles
{
    NSArray *sortedLogFiles =
            [logFiles sortedArrayUsingComparator:^NSComparisonResult(AMALogFile *lhs, AMALogFile *rhs) {
                return [lhs.serialNumber compare:rhs.serialNumber];
            }];
    return sortedLogFiles;
}

- (NSNumber *)nextSerialNumberForFiles:(NSArray *)logFiles
{
    if (logFiles.count == 0) {
        return @(1);
    }

    NSNumber *lastSerialNumber = [logFiles.lastObject serialNumber];
    NSNumber *nextSerialNumber = @(lastSerialNumber.unsignedIntegerValue + 1);
    return nextSerialNumber;
}

@end

#endif //AMA_ENABLE_FILE_LOG
