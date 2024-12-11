
#import "AMALogFileFactory.h"
#import "AMALogFile.h"

#ifdef AMA_ENABLE_FILE_LOG
static NSString *const kAMALogFileSerialNumberSeparator = @"-";
static NSString *const kAMALogFileExtension = @"log";

@interface AMALogFileFactory ()

@property (nonatomic, copy) NSString *filePrefix;

@end

@implementation AMALogFileFactory

- (instancetype)initWithPrefix:(NSString *)prefix
{
    self = [super init];
    if (self) {
        _filePrefix = [prefix copy];
    }
    return self;
}

- (AMALogFile *)logFileWithSerialNumber:(NSNumber *)serialNumber
{
    if (serialNumber == nil) {
        return nil;
    }

    NSString *fileName = [NSString stringWithFormat:@"%@%@%llu.%@",
                                                    self.filePrefix,
                                                    kAMALogFileSerialNumberSeparator,
                                                    serialNumber.unsignedLongLongValue,
                                                    kAMALogFileExtension];
    AMALogFile *logFile = [[AMALogFile alloc] initWithFileName:fileName serialNumber:serialNumber];
    return logFile;
}

- (AMALogFile *)logFileFromFilePath:(NSString *)filePath
{
    if (filePath.length == 0) {
        return nil;
    }

    NSString *fileName = [filePath lastPathComponent];

    NSString *plainFileName = [fileName stringByDeletingPathExtension];
    NSArray *components = [plainFileName componentsSeparatedByString:kAMALogFileSerialNumberSeparator];
    if (components.count < 2) {
        return nil;
    }

    NSString *serialNumberString = components.lastObject;
    if (serialNumberString.length == 0) {
        return nil;
    }

    NSDecimalNumber *decimalNumber = [NSDecimalNumber decimalNumberWithString:serialNumberString
                                                                       locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    if (decimalNumber == nil || [[NSDecimalNumber notANumber] isEqualToNumber:decimalNumber]) {
        return nil;
    }

    NSNumber *serialNumber = @([decimalNumber unsignedIntegerValue]);

    AMALogFile *file = [[AMALogFile alloc] initWithFileName:fileName serialNumber:serialNumber];
    return file;
}


@end

#endif // AMA_ENABLE_FILE_LOG
