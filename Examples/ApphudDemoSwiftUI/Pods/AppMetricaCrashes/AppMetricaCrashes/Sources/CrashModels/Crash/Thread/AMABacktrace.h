
#import <Foundation/Foundation.h>

@class AMABacktraceFrame;

@interface AMABacktrace : NSObject <NSCopying>

@property (nonatomic, strong, readonly) NSMutableArray<AMABacktraceFrame *> *frames;

- (instancetype)initWithFrames:(NSMutableArray<AMABacktraceFrame *> *)frames;

@end
