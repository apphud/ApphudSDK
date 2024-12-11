
#import <Foundation/Foundation.h>

@protocol AMAKeyValueStorageConverting <NSObject>

- (id)objectForString:(NSString *)value;
- (id)objectForData:(NSData *)value;
- (id)objectForDate:(NSDate *)value;
- (id)objectForBool:(BOOL)value;
- (id)objectForLongLong:(long long)value;
- (id)objectForUnsignedLongLong:(unsigned long long)value;
- (id)objectForDouble:(double)value;

- (NSString *)stringForObject:(id)object;
- (NSData *)dataForObject:(id)object;
- (NSDate *)dateForObject:(id)object;
- (BOOL)boolForObject:(id)object;
- (long long)longLongForObject:(id)object;
- (unsigned long long)unsignedLongLongForObject:(id)object;
- (double)doubleForObject:(id)object;

@end
