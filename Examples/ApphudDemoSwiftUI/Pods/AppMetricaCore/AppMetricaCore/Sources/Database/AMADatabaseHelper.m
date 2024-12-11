
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMADatabaseHelper.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@implementation AMADatabaseHelper

+ (NSArray *)eachResultsDescription:(AMAFMResultSet *)resultSet
{
    NSMutableArray *result = [NSMutableArray array];
    if (resultSet != nil) {
        while ([resultSet next]) {
            NSDictionary *resultDictionary = resultSet.resultDictionary;
            if (resultDictionary != nil) {
                [result addObject:resultDictionary.description];
            }
        }
        [resultSet close];
    }
    return [result copy];
}

+ (NSString *)intervalsWhereQueryForIdentifiers:(NSArray<NSNumber *> *)identifiers
                                            key:(NSString *)key
                                         values:(NSMutableArray *)values
{
    if (identifiers.count == 0) {
        return @"";
    }
    
    NSMutableArray *whereQueryComponents = [NSMutableArray array];
    NSArray *sortedIdentifiers = [identifiers sortedArrayUsingSelector:@selector(compare:)];
    unsigned long long __block seriesFirstIdentifier = [sortedIdentifiers[0] unsignedLongLongValue];
    unsigned long long __block previousIdentifier = seriesFirstIdentifier;
    NSArray *anchoredIdentifiers =
        [sortedIdentifiers arrayByAddingObject:[NSNumber numberWithUnsignedLongLong:UINT64_MAX]];
    [anchoredIdentifiers enumerateObjectsUsingBlock:^(NSNumber *number, NSUInteger idx, BOOL *stop) {
        if (idx == 0) {
            return;
        }
        unsigned long long identifier = [number unsignedLongLongValue];
        if (identifier - previousIdentifier != 1) {
            if (seriesFirstIdentifier == previousIdentifier) {
                [whereQueryComponents addObject:[NSString stringWithFormat:@"(%@ = ?)", key]];
                [values addObject:[NSNumber numberWithUnsignedLongLong:previousIdentifier]];
            }
            else {
                [whereQueryComponents addObject:[NSString stringWithFormat:@"(%@ >= ? AND %@ <= ?)", key, key]];
                [values addObject:[NSNumber numberWithUnsignedLongLong:seriesFirstIdentifier]];
                [values addObject:[NSNumber numberWithUnsignedLongLong:previousIdentifier]];
            }
            seriesFirstIdentifier = identifier;
        }
        previousIdentifier = identifier;
    }];
    NSString *whereQuery = [whereQueryComponents componentsJoinedByString:@" OR "];
    return whereQuery;
}

+ (NSNumber *)insertRowWithDictionary:(NSDictionary *)dictionary
                            tableName:(NSString *)tableName
                                   db:(AMAFMDatabase *)db
                                error:(NSError **)error
{
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:dictionary.count];
    NSMutableString *query = [NSMutableString stringWithFormat:@"INSERT INTO %@ (", tableName];
    NSMutableString *valueQuestions = [NSMutableString stringWithCapacity:dictionary.count * 2];
    BOOL __block isFirst = YES;
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (isFirst == NO) {
            [query appendString:@","];
            [valueQuestions appendString:@","];
        }
        [query appendString:key];
        [valueQuestions appendString:@"?"];
        [values addObject:obj];
        isFirst = NO;
    }];
    [query appendFormat:@") VALUES (%@)", valueQuestions];
    BOOL success = [db executeUpdate:query values:values error:error];
    return success ? [NSNumber numberWithLongLong:[db lastInsertRowId]] : nil;
}

+ (BOOL)updateFieldsWithDictionary:(NSDictionary *)dictionary
                          keyField:(NSString *)keyField
                               key:(id)key
                         tableName:(NSString *)tableName
                                db:(AMAFMDatabase *)db
                             error:(NSError **)error
{
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:dictionary.count + 1];
    NSMutableString *settersString = [NSMutableString string];
    BOOL __block isFirst = YES;
    [dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (isFirst == NO) {
            [settersString appendString:@","];
        }
        [settersString appendFormat:@"%@ = ?", key];
        [values addObject:obj];
        isFirst = NO;
    }];
    [values addObject:key];
    NSString *updateQuery =
        [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = ?", tableName, settersString, keyField];
    return [db executeUpdate:updateQuery values:values error:error];
}

+ (BOOL)deleteRowsWhereKey:(NSString *)keyField
                   inArray:(NSArray<NSNumber *> *)valuesArray
                 tableName:(NSString *)tableName
                        db:(AMAFMDatabase *)db
                     error:(NSError **)error
{
    NSMutableArray *values = [NSMutableArray array];
    NSString *whereQuery = [self intervalsWhereQueryForIdentifiers:valuesArray key:keyField values:values];
    NSString *query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", tableName, whereQuery];
    return [db executeUpdate:query values:values error:error];
}

+ (BOOL)deleteRowsMissingRelationsForKey:(NSString *)relationKey
                                 inTable:(NSString *)originalTableName
                        relationTableKey:(NSString *)relationTableKey
                       relationTableName:(NSString *)relationTableName
                    descendingOrderField:(NSString *)descendingOrderField
                                   limit:(NSInteger)limit
                                  offset:(NSInteger)offset
                                      db:(AMAFMDatabase *)db
                                   error:(NSError **)error
{
    NSString *queryTemplate =
        @"DELETE FROM %@ WHERE _rowid_ IN"
        "(SELECT _rowid_ FROM %@ "
        "WHERE %@ NOT IN (SELECT DISTINCT %@ FROM %@) "
        "ORDER BY %@ DESC LIMIT ? OFFSET ?)";
    NSString *sql = [NSString stringWithFormat:queryTemplate,
                     originalTableName,
                     originalTableName,
                     relationKey,
                     relationTableKey,
                     relationTableName,
                     descendingOrderField];
    return [db executeUpdate:sql values:@[ @(limit), @(offset) ] error:error];

}

+ (BOOL)deleteFirstRowsWithCount:(NSUInteger)count
                          filter:(NSString *)filter
                           order:(NSString *)order
                     valuesArray:(NSArray *)valuesArray
                       tableName:(NSString *)tableName
                              db:(AMAFMDatabase *)db
                           error:(NSError **)error
{
    NSString *queryTemplate =
        @"DELETE FROM %@ WHERE _rowid_ IN ("
            "SELECT _rowid_ FROM %@%@ LIMIT ?"
        ")";
    NSString *query =
        [NSString stringWithFormat:queryTemplate, tableName, tableName, [self queryPartForFilter:filter order:order]];
    NSArray *values = [(valuesArray ?: @[]) arrayByAddingObject:@(count)];
    return [db executeUpdate:query values:values error:error];
}

+ (NSUInteger)countWhereField:(NSString *)fieldName
                      inArray:(NSArray *)includedValuesArray
                    tableName:(NSString *)tableName
                           db:(AMAFMDatabase *)db
                        error:(NSError **)error
{
    return [self countWhereField:fieldName
                         inArray:includedValuesArray
                   andNotInArray:nil
                       tableName:tableName
                              db:db
                           error:error];
}

+ (NSUInteger)countWhereField:(NSString *)fieldName
                      inArray:(NSArray *)includedValuesArray
                andNotInArray:(NSArray *)excludedValuesArray
                    tableName:(NSString *)tableName
                           db:(AMAFMDatabase *)db
                        error:(NSError **)error
{
    NSUInteger result = 0;
    NSString *whereQuery = @"";
    NSMutableArray *valuesArray = [NSMutableArray array];
    if (fieldName.length != 0 && (includedValuesArray.count != 0 || excludedValuesArray.count != 0)) {
        NSMutableArray *whereQueries = [NSMutableArray array];
        if (includedValuesArray.count != 0) {
            NSArray *placeholders = [AMACollectionUtilities mapArray:includedValuesArray
                                                           withBlock:^id(id item) { return @"?"; }];
            [whereQueries addObject:[NSString stringWithFormat:@"%@ IN (%@)",
                                     fieldName, [placeholders componentsJoinedByString:@","]]];
            [valuesArray addObjectsFromArray:includedValuesArray];
        }
        if (excludedValuesArray.count != 0) {
            NSArray *placeholders = [AMACollectionUtilities mapArray:excludedValuesArray
                                                           withBlock:^id(id item) { return @"?"; }];
            [whereQueries addObject:[NSString stringWithFormat:@"%@ NOT IN (%@)",
                                     fieldName, [placeholders componentsJoinedByString:@","]]];
            [valuesArray addObjectsFromArray:excludedValuesArray];
        }
        whereQuery = [NSString stringWithFormat:@" WHERE %@", [whereQueries componentsJoinedByString:@" AND "]];
    }
    NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM %@%@", tableName, whereQuery];
    AMAFMResultSet *rs = [db executeQuery:query values:valuesArray error:error];
    if ([rs nextWithError:error]) {
        result = (NSUInteger)[rs longForColumnIndex:0];
    }
    [rs close];
    return result;
}

+ (NSDictionary *)firstRowWithFilter:(NSString *)filter
                               order:(NSString *)order
                         valuesArray:(NSArray *)valuesArray
                           tableName:(NSString *)tableName
                                  db:(AMAFMDatabase *)db
                               error:(NSError **)error
{
    NSDictionary *result = nil;
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@%@ LIMIT 1",
                       tableName, [self queryPartForFilter:filter order:order]];
    AMAFMResultSet *rs = [db executeQuery:query values:valuesArray error:error];
    if ([rs nextWithError:error]) {
        result = [rs resultDictionary];
    }
    [rs close];
    return result;
}

+ (BOOL)enumerateRowsWithFilter:(NSString *)filter
                          order:(NSString *)order
                    valuesArray:(NSArray *)valuesArray
                      tableName:(NSString *)tableName
                          limit:(NSUInteger)limit
                             db:(AMAFMDatabase *)db
                          error:(NSError **)error
                          block:(void(^)(NSDictionary *dictionary))block
{
    BOOL result = NO;
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@%@ LIMIT ?",
                       tableName, [self queryPartForFilter:filter order:order]];
    NSArray *fullValues = [(valuesArray ?: @[]) arrayByAddingObject:@(limit)];
    AMAFMResultSet *rs = [db executeQuery:query values:fullValues error:error];
    while ([rs nextWithError:error]) {
        if (block != nil) {
            block([rs resultDictionary]);
        }
    }
    [rs close];
    return result;
}

+ (NSInteger)changesForDB:(AMAFMDatabase *)db
{
    return (NSInteger)db.changes;
}

+ (NSString *)queryPartForFilter:(NSString *)filter order:(NSString *)order
{
    if (filter == nil && order == nil) {
        return @"";
    }

    NSMutableString *query = [NSMutableString string];
    if (filter != nil) {
        [query appendFormat:@" WHERE %@", filter];
    }
    if (order != nil) {
        [query appendFormat:@" ORDER BY %@", order];
    }
    return query;
}

@end
