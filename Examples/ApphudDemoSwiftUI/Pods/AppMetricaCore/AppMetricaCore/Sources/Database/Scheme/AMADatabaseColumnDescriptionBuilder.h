
#import <Foundation/Foundation.h>

@interface AMADatabaseColumnDescriptionBuilder : NSObject

- (instancetype)addName:(NSString *)name;
- (instancetype)addType:(NSString *)type;
- (instancetype)addDefaultValue:(id)defaultValue;
- (instancetype)addIsNotNull:(BOOL)isNotNull;
- (instancetype)addIsAutoincrement:(BOOL)isAutoincrement;
- (instancetype)addIsPrimaryKey:(BOOL)isPrimaryKey;
- (NSString *)buildSQL;

@end
