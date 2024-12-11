
#import "AMASQLiteIntegrityIssueParser.h"
#import "AMASQLiteIntegrityIssue.h"
#import <sqlite3.h>

static NSString *const pageIssuePattern =
    @"("
     "^Page \\d+ is never used"
    "|^On (tree )?page "
    ")";
static NSString *const indexIssuePattern =
    @"("
     "^row \\d+ missing from index "
    "|^wrong # of entries in index "
    ")";

@interface AMASQLiteIntegrityIssueParser ()

@property (nonatomic, strong, readonly) NSRegularExpression *pageIssueRegex;
@property (nonatomic, strong, readonly) NSRegularExpression *indexIssueRegex;

@end

@implementation AMASQLiteIntegrityIssueParser

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _pageIssueRegex =
            [NSRegularExpression regularExpressionWithPattern:pageIssuePattern
                                                      options:NSRegularExpressionAnchorsMatchLines
                                                        error:nil];
        _indexIssueRegex =
            [NSRegularExpression regularExpressionWithPattern:indexIssuePattern
                                                      options:NSRegularExpressionAnchorsMatchLines
                                                        error:nil];
    }
    return self;
}

#pragma mark - Public -

- (AMASQLiteIntegrityIssue *)issueForError:(NSError *)error
{
    AMASQLiteIntegrityIssueType issueType = AMASQLiteIntegrityIssueTypeOther;

    if ([error.domain isEqual:kAMAFMDBErrorDomain]) {
        issueType = AMASQLiteIntegrityIssueTypeOtherFMDBError;
        switch (error.code) {
            case SQLITE_FULL:
                issueType = AMASQLiteIntegrityIssueTypeFull;
                break;
            case SQLITE_CORRUPT:
                issueType = AMASQLiteIntegrityIssueTypeCorrupt;
                break;
            case SQLITE_NOTADB:
                issueType = AMASQLiteIntegrityIssueTypeNotADatabase;
                break;
        }
    }

    return [[AMASQLiteIntegrityIssue alloc] initWithType:issueType
                                               errorCode:error.code
                                         fullDescription:error.localizedDescription];
}

- (AMASQLiteIntegrityIssue *)issueForIntegityIssueString:(NSString *)issueString
{
    AMASQLiteIntegrityIssueType issueType = AMASQLiteIntegrityIssueTypeOther;
    if ([self matchString:issueString withRegex:self.pageIssueRegex]) {
        issueType = AMASQLiteIntegrityIssueTypeBrokenPages;
    }
    else if ([self matchString:issueString withRegex:self.indexIssueRegex]) {
        issueType = AMASQLiteIntegrityIssueTypeBrokenIndex;
    }

    return [[AMASQLiteIntegrityIssue alloc] initWithType:issueType errorCode:0 fullDescription:issueString];
}

#pragma mark - Private -

- (BOOL)matchString:(NSString *)string withRegex:(NSRegularExpression *)regex
{
    if (string.length == 0 || regex == nil) {
        return NO;
    }
    NSRange range = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
    return range.location != NSNotFound;
}

@end
