
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(KeyValueStorageDataProviding)
@protocol AMAKeyValueStorageDataProviding <NSObject>

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error;
- (id)objectForKey:(NSString *)key error:(NSError **)error;
- (BOOL)removeKey:(NSString *)key error:(NSError **)error;
- (BOOL)saveObject:(id)object forKey:(NSString *)key error:(NSError **)error;

- (NSDictionary<NSString *, id> *)objectsForKeys:(NSArray *)keys error:(NSError **)error;
- (BOOL)saveObjectsDictionary:(NSDictionary<NSString *, id> *)objectsDictionary error:(NSError **)error;

@end
