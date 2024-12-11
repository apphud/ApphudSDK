
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(JSONSerialization)
@interface AMAJSONSerialization : NSObject

+ (NSString *)stringWithJSONObject:(id)object error:(NSError **)error;
+ (NSData *)dataWithJSONObject:(id)object error:(NSError **)error;

+ (NSDictionary *)dictionaryWithJSONString:(NSString *)JSONString error:(NSError **)error;
+ (NSArray *)arrayWithJSONString:(NSString *)JSONString error:(NSError **)error;
+ (NSDictionary *)dictionaryWithJSONData:(NSData *)JSONString error:(NSError **)error;
+ (NSArray *)arrayWithJSONData:(NSData *)JSONString error:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
