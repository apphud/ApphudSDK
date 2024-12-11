
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AMAGrowDirection) {
    AMAGrowDirectionPlus,
    AMAGrowDirectionMinus,
};

@interface AMAStack : NSObject

@property (nonatomic, assign, readonly) AMAGrowDirection growDirection;
@property (nonatomic, assign, readonly) uint64_t dumpStart;
@property (nonatomic, assign, readonly) uint64_t dumpEnd;
@property (nonatomic, assign, readonly) uint64_t stackPointer;
@property (nonatomic, assign, readonly) BOOL overflow;
@property (nonatomic, copy, readonly) NSData *contents;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithGrowDirection:(AMAGrowDirection)growDirection
                            dumpStart:(uint64_t)dumpStart
                              dumpEnd:(uint64_t)dumpEnd
                         stackPointer:(uint64_t)stackPointer
                             overflow:(BOOL)overflow
                             contents:(NSData *)contents;

@end
