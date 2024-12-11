
#import <Foundation/Foundation.h>

@class AMASQLiteIntegrityIssue;

@interface AMASQLiteIntegrityIssueParser : NSObject

- (AMASQLiteIntegrityIssue *)issueForError:(NSError *)error;
- (AMASQLiteIntegrityIssue *)issueForIntegityIssueString:(NSString *)issueString;

@end
