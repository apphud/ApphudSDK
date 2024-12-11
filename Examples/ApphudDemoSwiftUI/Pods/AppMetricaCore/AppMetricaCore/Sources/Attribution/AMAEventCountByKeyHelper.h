
#import <Foundation/Foundation.h>

@interface AMAEventCountByKeyHelper : NSObject

- (NSUInteger)getCountForKey:(NSString *)key;
- (void)setCount:(NSUInteger)count forKey:(NSString *)key;

@end
