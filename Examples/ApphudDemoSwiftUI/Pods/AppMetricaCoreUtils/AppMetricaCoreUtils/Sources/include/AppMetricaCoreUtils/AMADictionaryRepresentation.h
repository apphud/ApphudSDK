
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(DictionaryRepresentation)
@protocol AMADictionaryRepresentation <NSObject>

@required
+ (instancetype)objectWithDictionaryRepresentation:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

@end
