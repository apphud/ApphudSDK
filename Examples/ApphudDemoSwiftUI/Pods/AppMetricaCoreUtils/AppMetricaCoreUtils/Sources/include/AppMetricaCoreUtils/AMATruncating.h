
#import <Foundation/Foundation.h>

typedef void (^AMATruncationBlock)(NSUInteger bytesTruncated)
    NS_SWIFT_UNAVAILABLE("Use Swift closures.");

NS_SWIFT_NAME(StringTruncating)
@protocol AMAStringTruncating <NSObject>

- (NSString *)truncatedString:(NSString *)string onTruncation:(AMATruncationBlock)onTruncation;

@end

NS_SWIFT_NAME(DataTruncating)
@protocol AMADataTruncating <NSObject>

- (NSData *)truncatedData:(NSData *)data onTruncation:(AMATruncationBlock)onTruncation;

@end

NS_SWIFT_NAME(DictionaryTruncating)
@protocol AMADictionaryTruncating <NSObject>

- (NSDictionary *)truncatedDictionary:(NSDictionary *)data onTruncation:(AMATruncationBlock)onTruncation;

@end
