
#import "AMAFileLogMiddleware.h"

#ifdef AMA_ENABLE_FILE_LOG

@interface AMAFileLogMiddleware ()

@property (nonatomic, strong) NSFileHandle *fileHandle;

@end

@implementation AMAFileLogMiddleware

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle
{
    self = [super init];
    if (self) {
        _fileHandle = fileHandle;
    }
    return self;
}

- (BOOL)isAsyncLoggingAcceptable
{
    return YES;
}

- (void)logMessage:(NSString *)message level:(AMALogLevel)level
{
    if (message == nil) {
        return;
    }

    NSString *formattedMessage = [NSString stringWithFormat:@"%@%@", message, @"\n"];
    NSData *messageData = [formattedMessage dataUsingEncoding:NSUTF8StringEncoding];
    @try {
        // this may throw NSFileHandleOperationException if no space left
        // https://nda.ya.ru/t/syha-Zzn75nbP2
        [self.fileHandle writeData:messageData];
    }
    @catch (NSException *exception) {
        // do nothing
        // TODO: handle "no space left"
    }
}

@end

#endif // AMA_ENABLE_FILE_LOG
