
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMASQLiteIntegrityIssueType) {
    AMASQLiteIntegrityIssueTypeOther,
    AMASQLiteIntegrityIssueTypeFull, // SQLITE_FULL
    AMASQLiteIntegrityIssueTypeCorrupt, // SQLITE_CORRUPT
    AMASQLiteIntegrityIssueTypeNotADatabase, // SQLITE_NOTADB
    AMASQLiteIntegrityIssueTypeOtherFMDBError,
    AMASQLiteIntegrityIssueTypeBrokenIndex,
    AMASQLiteIntegrityIssueTypeBrokenPages,
};

extern NSString *const kAMAFMDBErrorDomain;

@interface AMASQLiteIntegrityIssue : NSObject

@property (nonatomic, assign, readonly) AMASQLiteIntegrityIssueType issueType;
@property (nonatomic, assign, readonly) NSInteger errorCode;
@property (nonatomic, copy, readonly) NSString *fullDescription;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithType:(AMASQLiteIntegrityIssueType)issueType
                   errorCode:(NSInteger)errorCode
             fullDescription:(NSString *)fullDescription;

@end
