
#import <Foundation/Foundation.h>

@class AMAPair;

@interface AMAAttributionSerializer : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSArray *)toJsonArray:(NSArray<AMAPair *> *)model;
+ (NSArray<AMAPair *> *)fromJsonArray:(NSArray *)json;

@end
