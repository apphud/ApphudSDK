
#import <Foundation/Foundation.h>

@protocol AMAKeyValueStoring;
@protocol AMAReadonlyKeyValueStoring;
@class AMARollbackHolder;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(IncrementableValueStorage)
@interface AMAIncrementableValueStorage : NSObject

@property (nonatomic, copy, readonly) NSString *key;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithKey:(NSString *)key defaultValue:(long long)defaultValue;

- (void)restoreFromStorage:(id<AMAReadonlyKeyValueStoring>)storage;

- (NSNumber *)valueWithStorage:(id<AMAKeyValueStoring>)storage;
- (NSNumber *)nextInStorage:(id<AMAKeyValueStoring>)storage
                   rollback:(nullable AMARollbackHolder *)rollbackHolder
                      error:(NSError **)error;

- (BOOL)updateValue:(NSNumber *)value storage:(id<AMAKeyValueStoring>)storage error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
