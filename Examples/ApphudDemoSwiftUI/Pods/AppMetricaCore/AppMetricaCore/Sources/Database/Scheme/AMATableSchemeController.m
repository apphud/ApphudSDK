
#import "AMACore.h"
#import "AMATableSchemeController.h"
#import "AMATableDescriptionProvider.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMADatabaseColumnDescriptionBuilder.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@interface AMATableSchemeController ()

@property (nonatomic, copy, readonly) NSDictionary *schemes;

@end

@implementation AMATableSchemeController

- (instancetype)initWithTableSchemes:(NSDictionary *)schemes
{
    self = [super init];
    if (self != nil) {
        _schemes = [schemes copy];
        _tableNames = schemes.allKeys;
    }
    return self;
}

#pragma mark - Public -

- (void)createSchemaInDB:(AMAFMDatabase *)db
{
    NSError *__block error = nil;
    [self.schemes enumerateKeysAndObjectsUsingBlock:^(NSString *tableName, NSArray *metaInfo, BOOL *stop) {
        NSString *query = [self SQLToCreateTable:tableName metaInfo:metaInfo];
        BOOL success = [db executeUpdate:query values:@[] error:&error];
        *stop = success == NO;
    }];

    if (error != nil) {
        AMALogError(@"Failed to create schema: %@", error);
    }
}

- (void)enforceDatabaseConsistencyInDB:(AMAFMDatabase *)db onInconsistency:(void (^)(dispatch_block_t fix))onInconsistency
{
    BOOL __block consistent = YES;
    [self.schemes enumerateKeysAndObjectsUsingBlock:^(NSString *tableName, NSArray *metaInfo, BOOL *stop) {
        consistent = [self doesTableWithName:tableName matchSchemaInfo:metaInfo db:db];
        *stop = consistent == NO;
    }];

    if (consistent == NO) {
        AMALogError(@"Database is inconsistent. Drop and start from the very beginning");
        dispatch_block_t fix = ^{
            for (NSString *tableName in self.schemes.allKeys) {
                NSError *error = nil;
                [db executeUpdate:[self SQLToDropTableNamed:tableName] values:@[] error:&error];
                if (error != nil) {
                    AMALogError(@"Failed to drop table '%@': %@", tableName, error);
                }
            }
            [self createSchemaInDB:db];
        };
        if (onInconsistency != nil) {
            onInconsistency(fix);
        }
        else {
            fix();
        }
    }
}

#pragma mark - Private -

- (NSArray *)buildersForColumns:(NSArray *)columnsMetaInfo
{
    return [AMACollectionUtilities mapArray:columnsMetaInfo withBlock:^(NSDictionary *columnDescription) {
        AMADatabaseColumnDescriptionBuilder *builder = [[AMADatabaseColumnDescriptionBuilder alloc] init];
        [builder addName:columnDescription[kAMASQLName]];
        [builder addType:columnDescription[kAMASQLType]];
        [builder addIsNotNull:[columnDescription[kAMASQLIsNotNull] boolValue]];
        [builder addIsPrimaryKey:[columnDescription[kAMASQLIsPrimaryKey] boolValue]];
        [builder addIsAutoincrement:[columnDescription[kAMASQLIsAutoincrement] boolValue]];
        [builder addDefaultValue:columnDescription[kAMASQLDefaultValue]];
        return builder;
    }];
}

- (NSString *)SQLToCreateTable:(NSString *)tableName metaInfo:(NSArray *)tableColumnsMetaInfo
{
    NSArray *builders = [self buildersForColumns:tableColumnsMetaInfo];
    NSArray *columnSQLs = [AMACollectionUtilities mapArray:builders
                                                 withBlock:^(AMADatabaseColumnDescriptionBuilder *builder) {
                                                     return [builder buildSQL];
                                                 }];
    return [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@)",
            tableName, [columnSQLs componentsJoinedByString:@", "]];
}

- (NSString *)SQLToDropTableNamed:(NSString *)tableName
{
    return [NSString stringWithFormat:@"DROP TABLE %@", tableName];
}

- (BOOL)doesTableWithName:(NSString *)tableName matchSchemaInfo:(NSArray *)metaInfo db:(AMAFMDatabase *)db
{
    NSError *error = nil;
    AMAFMResultSet *resultSet = [db executeQuery:[NSString stringWithFormat:@"PRAGMA table_info('%@')", tableName]
                                       values:@[]
                                        error:&error];
    NSUInteger idx = 0;
    BOOL matches = error == nil;
    while (matches && idx < metaInfo.count && [resultSet nextWithError:&error]) {
        NSString *fieldName = [resultSet stringForColumn:@"name"];
        NSString *fieldType = [resultSet stringForColumn:@"type"];
        NSString *expectedFieldName = metaInfo[idx][kAMASQLName];
        NSString *expectedFieldType = metaInfo[idx][kAMASQLType];

        if ([fieldName isEqualToString:expectedFieldName] == NO) {
            AMALogError(@"Expected field '%@' but found '%@'", expectedFieldName, fieldName);
            matches = NO;
        }
        else if ([fieldType isEqualToString:expectedFieldType] == NO) {
            AMALogError(@"Expected field '%@' to have type '%@' but found '%@'",
                                fieldName, expectedFieldType, fieldType);
            matches = NO;
        }
        ++idx;
    }
    matches = matches && (idx == metaInfo.count && [resultSet nextWithError:&error] == NO);
    [resultSet close];
    if (error != nil) {
        AMALogError(@"Failed to check table consistency: %@", error);
    }
    return matches;
}

@end
