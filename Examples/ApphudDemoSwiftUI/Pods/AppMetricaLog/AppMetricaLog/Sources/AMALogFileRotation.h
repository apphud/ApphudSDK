
#import <Foundation/Foundation.h>

#ifdef AMA_ENABLE_FILE_LOG

@interface AMALogFileRotation : NSObject

@property (nonatomic, copy, readonly) NSArray *filesToRemove;
@property (nonatomic, strong, readonly) NSNumber *nextSerialNumber;

+ (instancetype)rotationForLogFiles:(NSArray *)logFiles
                withMaxFilesAllowed:(NSUInteger)maxFilesCount;

- (instancetype)initWithFilesToRemove:(NSArray *)removeFiles
                     nextSerialNumber:(NSNumber *)serialNumber;

@end

#endif //AMA_ENABLE_FILE_LOG
