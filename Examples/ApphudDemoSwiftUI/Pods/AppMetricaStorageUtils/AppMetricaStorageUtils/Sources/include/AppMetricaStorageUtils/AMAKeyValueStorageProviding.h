
#import <Foundation/Foundation.h>

@protocol AMAKeyValueStoring;
@protocol AMAReadonlyKeyValueStoring;

NS_SWIFT_NAME(KeyValueStorageProviding)
@protocol AMAKeyValueStorageProviding <NSObject>

@property (nonatomic, strong, readonly) id<AMAKeyValueStoring> syncStorage;
@property (nonatomic, strong, readonly) id<AMAKeyValueStoring> cachingStorage;

- (void)inStorage:(void (^)(id<AMAKeyValueStoring> storage))block;

- (id<AMAKeyValueStoring>)emptyNonPersistentStorage;
- (id<AMAKeyValueStoring>)nonPersistentStorageForStorage:(id<AMAKeyValueStoring>)storage error:(NSError **)error;
- (id<AMAKeyValueStoring>)nonPersistentStorageForKeys:(NSArray *)keys error:(NSError **)error;
- (BOOL)saveStorage:(id<AMAKeyValueStoring>)storage error:(NSError **)error;

@end
