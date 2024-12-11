
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(CollectionUtilities)
@interface AMACollectionUtilities : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSDictionary *)filteredDictionary:(NSDictionary *)sourceDictionary withKeys:(NSSet *)keys;
+ (NSDictionary *)dictionaryByRemovingEmptyStringValuesForDictionary:(NSDictionary *)sourceDictionary;
+ (BOOL)areAllItemsOfDictionary:(NSDictionary *)dictionary matchBlock:(BOOL(^)(id key, id value))block;
+ (NSDictionary *)compactMapValuesOfDictionary:(NSDictionary *)dictionary withBlock:(id(^)(id key, id value))block;

+ (NSArray *)filteredArray:(NSArray *)array withPredicate:(BOOL(^)(id item))block;
+ (NSArray *)mapArray:(NSArray *)array withBlock:(id(^)(id item))block;
+ (NSArray *)flatMapArray:(NSArray *)array withBlock:(NSArray *(^)(id item))block;
+ (BOOL)areAllItemsOfArray:(NSArray *)array matchBlock:(BOOL(^)(id item))block;
+ (void)removeItemsFromArray:(NSMutableArray *)array withBlock:(void(^)(id item, BOOL *remove))block;

@end

NS_ASSUME_NONNULL_END
