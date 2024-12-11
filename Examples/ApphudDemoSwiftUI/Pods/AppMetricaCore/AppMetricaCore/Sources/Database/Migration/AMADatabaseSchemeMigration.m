
#import "AMADatabaseSchemeMigration.h"
#import "AMAMigrationUtils.h"

@implementation AMADatabaseSchemeMigration

- (NSUInteger)schemeVersion
{
    return 0;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    return NO;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", super.description];
    [description appendFormat:@"self.schemeVersion=%lu",  (unsigned long)self.schemeVersion];
    [description appendString:@">"];
    return description;
}
#endif

@end
