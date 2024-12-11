
#import <Foundation/Foundation.h>

@interface AMALogFile : NSObject

@property (nonatomic, copy, readonly) NSString *fileName;
@property (nonatomic, strong, readonly) NSNumber *serialNumber;

- (instancetype)initWithFileName:(NSString *)fileName serialNumber:(NSNumber *)serialNumber;

@end
