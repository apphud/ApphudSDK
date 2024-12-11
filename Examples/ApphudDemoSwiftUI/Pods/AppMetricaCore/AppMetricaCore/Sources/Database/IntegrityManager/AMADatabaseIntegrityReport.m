
#import "AMADatabaseIntegrityReport.h"

@implementation AMADatabaseIntegrityReport

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _stepIssues = [NSMutableDictionary dictionary];
    }
    return self;
}

@end
