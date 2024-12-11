
#import <Foundation/Foundation.h>

#ifdef AMA_ENABLE_FILE_LOG

@class AMALogFile;

@interface AMALogFileFactory : NSObject

- (instancetype)initWithPrefix:(NSString *)prefix;

- (AMALogFile *)logFileWithSerialNumber:(NSNumber *)serialNumber;
- (AMALogFile *)logFileFromFilePath:(NSString *)filePath;

@end

#endif // AMA_ENABLE_FILE_LOG
