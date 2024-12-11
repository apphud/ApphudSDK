
#import <Foundation/Foundation.h>

@class AMAErrorModel;
@class AMABacktrace;

@interface AMANonFatal : NSObject

@property (nonatomic, strong, readonly) AMAErrorModel *model;
@property (nonatomic, strong, readonly) AMABacktrace *backtrace;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithModel:(AMAErrorModel *)model backtrace:(AMABacktrace *)backtrace;

@end
