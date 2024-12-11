
#import "AMALogMiddleware.h"

#ifdef AMA_ENABLE_FILE_LOG

@interface AMAFileLogMiddleware : NSObject <AMALogMiddleware>

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle;

@end

#endif // AMA_ENABLE_FILE_LOG
