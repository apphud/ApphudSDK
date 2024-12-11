
#import "AMASQLiteIntegrityIssue.h"

NSString *const kAMAFMDBErrorDomain = @"AMAFMDatabase";

@implementation AMASQLiteIntegrityIssue

- (instancetype)initWithType:(AMASQLiteIntegrityIssueType)issueType
                   errorCode:(NSInteger)errorCode
             fullDescription:(NSString *)fullDescription
{
    self = [super init];
    if (self != nil) {
        _issueType = issueType;
        _errorCode = errorCode;
        _fullDescription = [fullDescription copy];
    }
    return self;
}

@end
