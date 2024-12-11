
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kAMARSAKeyTagReporter;
extern NSString *const kAMARSAKeyTagUIS;

typedef NS_ENUM(NSUInteger, AMARSAKeyType) {
    AMARSAKeyTypePublic,
    AMARSAKeyTypePrivate,
} NS_SWIFT_NAME(RSAKeyType);

NS_SWIFT_NAME(RSAKey)
@interface AMARSAKey : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSData *data;
@property (nonatomic, assign, readonly) AMARSAKeyType keyType;
@property (nonatomic, copy, readonly) NSString *uniqueTag;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithData:(NSData *)data keyType:(AMARSAKeyType)keyType uniqueTag:(NSString *)uniqueTag;

@end

NS_ASSUME_NONNULL_END
