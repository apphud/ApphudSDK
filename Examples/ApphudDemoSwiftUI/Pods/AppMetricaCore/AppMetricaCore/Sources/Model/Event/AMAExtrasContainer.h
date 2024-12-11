
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMAExtrasContainer;

typedef void (^AMAExtrasContainerDidChangeBlock)(id _Nonnull observer,  AMAExtrasContainer * _Nonnull environment);

@interface AMAExtrasContainer : NSObject

- (instancetype)initWithDictionaryExtras:(nullable NSDictionary<NSString *, NSData *> *)dictionaryExtras;

- (void)addValue:(nullable NSData *)value forKey:(NSString *)key;
- (void)removeValueForKey:(NSString *)key;
- (void)clearExtras;

@property (readonly, strong) NSDictionary<NSString *, NSData *> *dictionaryExtras;

- (void)addObserver:(id)observer withBlock:(AMAExtrasContainerDidChangeBlock)block;
- (void)removeObserver:(id)observer;

+ (instancetype)container;
+ (instancetype)containerWithDictionary:(nullable NSDictionary<NSString *, NSData *> *)dictionaryExtras;

@end

NS_ASSUME_NONNULL_END
