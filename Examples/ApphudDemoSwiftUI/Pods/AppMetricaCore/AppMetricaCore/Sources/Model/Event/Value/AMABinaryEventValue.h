
#import <Foundation/Foundation.h>
#import "AMAEventValueProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMABinaryEventValue : NSObject <AMAEventValueProtocol>

@property (nonatomic, copy, readonly) NSData *data;
@property (nonatomic, assign, readonly) BOOL gZipped;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithData:(NSData *)data
                     gZipped:(BOOL)gZipped;

@end

NS_ASSUME_NONNULL_END
