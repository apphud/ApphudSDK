
#import <Foundation/Foundation.h>
#import "AMAEventEncryptionType.h"

@protocol AMAEventValueProtocol;
@protocol AMAStringTruncating;
@protocol AMADataTruncating;

typedef NS_ENUM(NSUInteger, AMAEventValueFactoryTruncationType) {
    AMAEventValueFactoryTruncationTypePartial,
    AMAEventValueFactoryTruncationTypeFull,
};

NS_ASSUME_NONNULL_BEGIN

@interface AMAEventValueFactory : NSObject


- (instancetype)init;
- (instancetype)initWithStringTruncator:(id<AMAStringTruncating>)stringTruncator
                   partialDataTruncator:(id<AMADataTruncating>)partialDataTruncator
                      fullDataTruncator:(id<AMADataTruncating>)fullDataTruncator;

- (id<AMAEventValueProtocol>)stringEventValue:(NSString *)value bytesTruncated:(NSUInteger *)bytesTruncated;
- (id<AMAEventValueProtocol>)binaryEventValue:(NSData *)value
                                      gZipped:(BOOL)gZipped
                               bytesTruncated:(NSUInteger *)bytesTruncated;
- (id<AMAEventValueProtocol>)fileEventValue:(NSData *)value
                                   fileName:(NSString *)fileName
                                    gZipped:(BOOL)gZipped
                             encryptionType:(AMAEventEncryptionType)encryptionType
                             truncationType:(AMAEventValueFactoryTruncationType)truncationType
                             bytesTruncated:(NSUInteger *)bytesTruncated
                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
