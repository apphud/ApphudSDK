
#import <Foundation/Foundation.h>

@protocol AMAKeyValueStoring;

NS_SWIFT_NAME(ReadonlyKeyValueStoring)
@protocol AMAReadonlyKeyValueStoring <NSObject>

- (NSString *)stringForKey:(NSString *)key error:(NSError **)error;
- (NSData *)dataForKey:(NSString *)key error:(NSError **)error;
- (NSDate *)dateForKey:(NSString *)key error:(NSError **)error;
- (NSNumber *)boolNumberForKey:(NSString *)key error:(NSError **)error;
- (NSNumber *)longLongNumberForKey:(NSString *)key error:(NSError **)error;
- (NSNumber *)unsignedLongLongNumberForKey:(NSString *)key error:(NSError **)error;
- (NSNumber *)doubleNumberForKey:(NSString *)key error:(NSError **)error;
- (NSDictionary *)jsonDictionaryForKey:(NSString *)key error:(NSError **)error;
- (NSArray *)jsonArrayForKey:(NSString *)key error:(NSError **)error;

@end;

NS_SWIFT_NAME(KeyValueStoring)
@protocol AMAKeyValueStoring <AMAReadonlyKeyValueStoring>

- (BOOL)saveString:(NSString *)string forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveData:(NSData *)data forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveDate:(NSDate *)date forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveBoolNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveLongLongNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveUnsignedLongLongNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveDoubleNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveJSONDictionary:(NSDictionary *)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveJSONArray:(NSArray *)value forKey:(NSString *)key error:(NSError **)error;

@end;
