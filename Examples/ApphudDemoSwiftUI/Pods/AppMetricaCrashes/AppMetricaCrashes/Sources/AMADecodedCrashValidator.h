
#import <Foundation/Foundation.h>

@class AMADecodedCrash;
@class AMAInfo;
@class AMABinaryImage;
@class AMASystem;
@class AMACrashReportCrash;
@class AMACrashReportError;
@class AMANSException;
@class AMACppException;
@class AMARegister;
@class AMAMemory;
@class AMAApplicationStatistics;
@class AMABacktraceFrame;

extern NSString *const kAMADecodedCrashValidatorErrorDomain;

extern NSString *const kAMAValidatorUserInfoCriticalErrorsKey;
extern NSString *const kAMAValidatorUserInfoSuspiciousErrorsKey;
extern NSString *const kAMAValidatorUserInfoNonCriticalErrorsKey;

typedef NS_ENUM(NSInteger, AMACrashValidatorErrorCode) {
    AMACrashValidatorErrorCodeNone = 0,
    AMACrashValidatorErrorCodeNonCritical,
    AMACrashValidatorErrorCodeSuspicious,
    AMACrashValidatorErrorCodeCritical,
};

@interface AMADecodedCrashValidator : NSObject

- (NSError *)result;

- (void)reset;

- (BOOL)validateDecodedCrash:(AMADecodedCrash *)crash;

- (BOOL)validateInfo:(AMAInfo *)info;

- (BOOL)validateBinaryImage:(AMABinaryImage *)image;

- (BOOL)validateSystem:(AMASystem *)system;

- (BOOL)validateCrash:(AMACrashReportCrash *)crash;

- (BOOL)validateError:(AMACrashReportError *)reportError;

- (BOOL)validateRegister:(AMARegister *)amaRegister;

- (BOOL)validateMemory:(AMAMemory *)memory;

- (BOOL)validateAppStats:(AMAApplicationStatistics *)statistics;

- (BOOL)validateBacktraceFrame:(AMABacktraceFrame *)frame;

@end
