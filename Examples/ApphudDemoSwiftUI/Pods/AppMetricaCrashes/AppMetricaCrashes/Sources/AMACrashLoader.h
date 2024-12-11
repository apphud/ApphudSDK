
#import <Foundation/Foundation.h>
#import "AMAUnhandledCrashDetector.h"
#import "AMACrashReportDecoder.h"

@protocol AMACrashLoaderDelegate;
@class AMACrashSafeTransactor;
@class AMADecodedCrash;
@class AMAUnhandledCrashDetector;

extern NSString *const kAMAApplicationNotRespondingCrashType;

@interface AMACrashLoader : NSObject <AMACrashReportDecoderDelegate>

@property (nonatomic, weak) id<AMACrashLoaderDelegate> delegate;
@property (nonatomic, assign) BOOL isUnhandledCrashDetectingEnabled;
@property (nonatomic, assign, readonly) NSNumber *crashedLastLaunch;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUnhandledCrashDetector:(AMAUnhandledCrashDetector *)unhandledCrashDetector
                                    transactor:(AMACrashSafeTransactor *)transactor;

- (void)enableCrashLoader;
- (void)enableRequiredMonitoring;
- (void)loadCrashReports;
- (NSArray<AMADecodedCrash *> *)syncLoadCrashReports;

+ (void)purgeRawCrashReport:(NSNumber *)reportID;
+ (void)purgeAllRawCrashReports;
+ (void)purgeCrashesDirectory;

// TODO(vasileuski): make as instance methods
+ (void)addCrashContext:(NSDictionary *)crashContext;
+ (NSDictionary *)crashContext;

- (void)reportANR;

@end

@protocol AMACrashLoaderDelegate <NSObject>

- (void)crashLoader:(AMACrashLoader *)crashLoader
       didLoadCrash:(AMADecodedCrash *)decodedCrash
          withError:(NSError *)error;

- (void)crashLoader:(AMACrashLoader *)crashLoader didLoadANR:(AMADecodedCrash *)decodedCrash withError:(NSError *)error;

- (void)crashLoader:(AMACrashLoader *)crashLoader didDetectProbableUnhandledCrash:(AMAUnhandledCrashType)crashType;

@end
