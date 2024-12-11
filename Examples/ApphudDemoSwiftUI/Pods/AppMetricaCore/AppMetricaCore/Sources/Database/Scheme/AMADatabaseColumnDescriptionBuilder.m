
#import "AMADatabaseColumnDescriptionBuilder.h"

@interface AMADatabaseColumnDescriptionBuilder ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) id defaultValue;
@property (nonatomic, assign) BOOL isNotNull;
@property (nonatomic, assign) BOOL isAutoincrement;
@property (nonatomic, assign) BOOL isPrimaryKey;

@end

@implementation AMADatabaseColumnDescriptionBuilder

- (instancetype)addName:(NSString *)name
{
    self.name = name;
    return self;
}

- (instancetype)addType:(NSString *)type
{
    self.type = type;
    return self;
}

- (instancetype)addDefaultValue:(id)defaultValue
{
    self.defaultValue = defaultValue;
    return self;
}

- (instancetype)addIsNotNull:(BOOL)isNotNull
{
    self.isNotNull = isNotNull;
    return self;
}

- (instancetype)addIsAutoincrement:(BOOL)isAutoincrement
{
    self.isAutoincrement = isAutoincrement;
    return self;
}

- (instancetype)addIsPrimaryKey:(BOOL)isPrimaryKey
{
    self.isPrimaryKey = isPrimaryKey;
    return self;
}

- (NSString *)buildSQL
{
    NSMutableString *SQL = nil;
    if (self.name.length > 0 && self.type.length > 0) {
        SQL = [NSMutableString stringWithFormat:@"%@ %@", self.name, self.type];

        if (self.isNotNull) {
            [SQL appendString:@" NOT NULL"];
        }

        if (self.defaultValue != nil) {
            [SQL appendFormat:@" DEFAULT %@", self.defaultValue];
        }

        if (self.isPrimaryKey) {
            [SQL appendString:@" PRIMARY KEY"];
            if (self.isAutoincrement) {
                [SQL appendString:@" AUTOINCREMENT"];
            }
        }
    }
    else {
        NSException *exception = [[NSException alloc] initWithName:@"InternalInconsistencyException"
                                                            reason:@"Not all data provided to build column SQL"
                                                          userInfo:nil];
        [exception raise];
    }
    return SQL;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithString:[super description]];
    [description appendString:@" "];

    NSString *sqlDescription = [self buildSQL];
    [description appendString:sqlDescription.length > 0 ? sqlDescription : @"Empty builder"];

    return description;
}
#endif

@end
