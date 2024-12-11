
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AMAKeychainQueryBuilder : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithQueryParameters:(NSDictionary *)parameters NS_DESIGNATED_INITIALIZER;

- (NSDictionary *)entriesQuery;

- (nullable NSDictionary *)entryQueryForKey:(id)key;
- (nullable NSDictionary *)dataQueryForKey:(id)key;

- (nullable NSDictionary *)addEntryQueryWithData:(NSData *)data forKey:(id)key;

- (nullable NSDictionary *)updateEntryQueryWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
