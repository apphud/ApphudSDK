
#import <Foundation/Foundation.h>

extern NSString *const kAMAReportSerializerErrorDomain;
extern NSString *const kAMAReportSerializerErrorKeyActualSize;

typedef NS_ENUM(NSInteger, AMAReportSerializerErrorCode) {
    AMAReportSerializerErrorTooLarge,
    AMAReportSerializerErrorAllocationError,
    AMAReportSerializerErrorEmpty,
};

@class AMAReportRequestModel;
@class AMAReportSerializer;
@class AMAEvent;

@protocol AMAReportSerializerDelegate <NSObject>

- (void)reportSerializer:(AMAReportSerializer *)serializer didFailedToReadFileOfEvent:(AMAEvent *)event;

@end

@interface AMAReportSerializer : NSObject

@property (nonatomic, weak) id<AMAReportSerializerDelegate> delegate;

- (NSData *)dataForRequestModel:(AMAReportRequestModel *)requestModel
                      sizeLimit:(NSUInteger)sizeLimit
                          error:(NSError **)error;

@end
