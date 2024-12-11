
#import "AMATableDescriptionProvider.h"
#import "AMADatabaseConstants.h"

NSString *const kAMASQLName = @"name";
NSString *const kAMASQLType = @"type";
NSString *const kAMASQLIsNotNull = @"isNotNull";
NSString *const kAMASQLIsPrimaryKey = @"isPrimaryKey";
NSString *const kAMASQLIsAutoincrement = @"isAutoincrement";
NSString *const kAMASQLDefaultValue = @"defaultValue";

static NSString *const kAMASQLTypeINTEGER = @"INTEGER";
static NSString *const kAMASQLTypeTEXT = @"TEXT";
static NSString *const kAMASQLTypeDOUBLE = @"DOUBLE";
static NSString *const kAMASQLTypeBOOL = @"BOOL";
static NSString *const kAMASQLTypeBLOB = @"BLOB";

@implementation AMATableDescriptionProvider

+ (NSArray *)eventsTableMetaInfo
{
    NSArray *metaInfo = @[
        @{
            kAMASQLName : kAMACommonTableFieldOID,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES,
            kAMASQLIsPrimaryKey : @YES,
            kAMASQLIsAutoincrement : @YES
        },
        @{
            kAMASQLName : kAMAEventTableFieldSessionOID,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMAEventTableFieldCreatedAt,
            kAMASQLType : kAMASQLTypeDOUBLE,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMAEventTableFieldSequenceNumber,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMACommonTableFieldType,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMACommonTableFieldDataEncryptionType,
            kAMASQLType : kAMASQLTypeINTEGER
        },
        @{
            kAMASQLName : kAMACommonTableFieldData,
            kAMASQLType : kAMASQLTypeBLOB,
            kAMASQLIsNotNull : @YES
        },
    ];
    return metaInfo;
}

+ (NSArray *)sessionsTableMetaInfo
{
    NSArray *metaInfo = @[
        @{
            kAMASQLName : kAMACommonTableFieldOID,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES,
            kAMASQLIsPrimaryKey : @YES,
            kAMASQLIsAutoincrement : @(YES)
        },
        @{
            kAMASQLName : kAMASessionTableFieldStartTime,
            kAMASQLType : kAMASQLTypeDOUBLE,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMACommonTableFieldType,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMASessionTableFieldFinished,
            kAMASQLType : kAMASQLTypeBOOL,
            kAMASQLIsNotNull : @YES,
            kAMASQLDefaultValue : @NO
        },
        @{
            kAMASQLName : kAMASessionTableFieldLastEventTime,
            kAMASQLType : kAMASQLTypeDOUBLE
        },
        @{
            kAMASQLName : kAMASessionTableFieldPauseTime,
            kAMASQLType : kAMASQLTypeDOUBLE,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMASessionTableFieldEventSeq,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES,
            kAMASQLDefaultValue : @"0"
        },
        @{
            kAMASQLName : kAMACommonTableFieldDataEncryptionType,
            kAMASQLType : kAMASQLTypeINTEGER
        },
        @{
            kAMASQLName : kAMACommonTableFieldData,
            kAMASQLType : kAMASQLTypeBLOB,
            kAMASQLIsNotNull : @YES
        },
    ];
    return metaInfo;
}

+ (NSArray *)locationsTableMetaInfo
{
    NSArray *metaInfo = @[
        @{
            kAMASQLName : kAMACommonTableFieldOID,
            kAMASQLType : kAMASQLTypeINTEGER,
            kAMASQLIsNotNull : @YES,
            kAMASQLIsPrimaryKey : @YES
        },
        @{
            kAMASQLName : kAMALocationsTableFieldTimestamp,
            kAMASQLType : kAMASQLTypeDOUBLE,
            kAMASQLIsNotNull : @YES
        },
        @{
            kAMASQLName : kAMACommonTableFieldData,
            kAMASQLType : kAMASQLTypeBLOB,
            kAMASQLIsNotNull : @YES
        },
    ];
    return metaInfo;
}

+ (NSArray *)visitsTableMetaInfo
{
    return [[self class] locationsTableMetaInfo];
}

+ (NSArray *)stringKVTableMetaInfo
{
    NSArray *metaInfo = @[
        @{
            kAMASQLName : kAMAKeyValueTableFieldKey,
            kAMASQLType : kAMASQLTypeTEXT,
            kAMASQLIsNotNull : @YES,
            kAMASQLIsPrimaryKey : @YES
        },
        @{
            kAMASQLName : kAMAKeyValueTableFieldValue,
            kAMASQLType : kAMASQLTypeTEXT,
            kAMASQLIsNotNull : @YES,
            kAMASQLDefaultValue : @"''"
        }
    ];
    return metaInfo;
}

+ (NSArray *)binaryKVTableMetaInfo
{
    NSArray *metaInfo = @[
        @{
            kAMASQLName : kAMAKeyValueTableFieldKey,
            kAMASQLType : kAMASQLTypeTEXT,
            kAMASQLIsNotNull : @YES,
            kAMASQLIsPrimaryKey : @YES
        },
        @{
            kAMASQLName : kAMAKeyValueTableFieldValue,
            kAMASQLType : kAMASQLTypeBLOB
        },
    ];
    return metaInfo;
}

@end
