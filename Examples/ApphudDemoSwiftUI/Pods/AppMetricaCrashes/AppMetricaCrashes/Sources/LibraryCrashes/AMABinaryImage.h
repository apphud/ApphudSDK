
#import <Foundation/Foundation.h>

@interface AMABinaryImage : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *UUID;
@property (nonatomic, copy, readonly) NSString *name;

@property (nonatomic, assign, readonly) NSUInteger cpuType;
@property (nonatomic, assign, readonly) NSUInteger cpuSubtype;

@property (nonatomic, assign, readonly) int32_t majorVersion;
@property (nonatomic, assign, readonly) int32_t minorVersion;
@property (nonatomic, assign, readonly) int32_t revisionVersion;

@property (nonatomic, assign, readonly) NSUInteger address;
@property (nonatomic, assign, readonly) NSUInteger size;
@property (nonatomic, assign, readonly) NSUInteger vmAddress;

@property (nonatomic, copy, readonly) NSString *crashInfoMessage;
@property (nonatomic, copy, readonly) NSString *crashInfoMessage2;

- (instancetype)initWithName:(NSString *)name
                        UUID:(NSString *)UUID
                     address:(NSUInteger)address
                        size:(NSUInteger)size
                   vmAddress:(NSUInteger)vmAddress
                     cpuType:(NSUInteger)cpuType
                  cpuSubtype:(NSUInteger)cpuSubtype
                majorVersion:(int32_t)majorVersion
                minorVersion:(int32_t)minorVersion
             revisionVersion:(int32_t)revisionVersion
            crashInfoMessage:(NSString *)crashInfoMessage
           crashInfoMessage2:(NSString *)crashInfoMessage2;

@end
