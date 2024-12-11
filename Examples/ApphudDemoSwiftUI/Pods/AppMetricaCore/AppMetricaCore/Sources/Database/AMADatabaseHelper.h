
#import <Foundation/Foundation.h>

@class AMAFMDatabase;
@class AMAFMResultSet;

NS_ASSUME_NONNULL_BEGIN

@interface AMADatabaseHelper : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSArray *)eachResultsDescription:(AMAFMResultSet *)resultSet;
+ (NSString *)intervalsWhereQueryForIdentifiers:(NSArray<NSNumber *> *)identifiers
                                            key:(NSString *)key
                                         values:(NSMutableArray *)values;
+ (NSNumber *)insertRowWithDictionary:(NSDictionary *)dictionary
                            tableName:(NSString *)tableName
                                   db:(AMAFMDatabase *)db
                                error:(NSError **)error;
+ (BOOL)updateFieldsWithDictionary:(NSDictionary *)dictionary
                          keyField:(NSString *)keyField
                               key:(id)key
                         tableName:(NSString *)tableName
                                db:(AMAFMDatabase *)db
                             error:(NSError **)error;
+ (BOOL)deleteRowsWhereKey:(NSString *)keyField
                   inArray:(NSArray<NSNumber *> *)valuesArray
                 tableName:(NSString *)tableName
                        db:(AMAFMDatabase *)db
                     error:(NSError **)error;
+ (BOOL)deleteRowsMissingRelationsForKey:(NSString *)relationKey
                                 inTable:(NSString *)originalTableName
                        relationTableKey:(NSString *)relationTableKey
                       relationTableName:(NSString *)relationTableName
                    descendingOrderField:(NSString *)descendingOrderField
                                   limit:(NSInteger)limit
                                  offset:(NSInteger)offset
                                      db:(AMAFMDatabase *)db
                                   error:(NSError **)error;
+ (BOOL)deleteFirstRowsWithCount:(NSUInteger)count
                          filter:(nullable NSString *)filter
                           order:(nullable NSString *)order
                     valuesArray:(nullable NSArray *)valuesArray
                       tableName:(NSString *)tableName
                              db:(AMAFMDatabase *)db
                           error:(NSError **)error;
+ (NSUInteger)countWhereField:(nullable NSString *)fieldName
                      inArray:(nullable NSArray *)includedValuesArray
                    tableName:(NSString *)tableName
                           db:(AMAFMDatabase *)db
                        error:(NSError **)error;
+ (NSUInteger)countWhereField:(nullable NSString *)fieldName
                      inArray:(nullable NSArray *)includedValuesArray
                andNotInArray:(nullable NSArray *)excludedValuesArray
                    tableName:(NSString *)tableName
                           db:(AMAFMDatabase *)db
                        error:(NSError **)error;
+ (NSDictionary *)firstRowWithFilter:(nullable NSString *)filter
                               order:(nullable NSString *)order
                         valuesArray:(nullable NSArray *)valuesArray
                           tableName:(NSString *)tableName
                                  db:(AMAFMDatabase *)db
                               error:(NSError **)error;
+ (BOOL)enumerateRowsWithFilter:(nullable NSString *)filter
                          order:(nullable NSString *)order
                    valuesArray:(nullable NSArray *)valuesArray
                      tableName:(NSString *)tableName
                          limit:(NSUInteger)limit
                             db:(AMAFMDatabase *)db
                          error:(NSError **)error
                          block:(void(^)(NSDictionary *dictionary))block;
+ (NSInteger)changesForDB:(AMAFMDatabase *)db;

@end

NS_ASSUME_NONNULL_END
