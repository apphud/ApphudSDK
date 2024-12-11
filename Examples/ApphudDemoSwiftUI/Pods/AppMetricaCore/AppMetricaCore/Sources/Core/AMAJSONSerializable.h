
#import <Foundation/Foundation.h>

@protocol AMAJSONSerializable <NSObject>

- (instancetype)initWithJSON:(NSDictionary *)json;
- (NSDictionary *)JSON;

@end
