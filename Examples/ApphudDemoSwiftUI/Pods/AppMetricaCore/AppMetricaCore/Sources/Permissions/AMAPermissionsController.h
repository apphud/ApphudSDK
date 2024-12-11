
#import <Foundation/Foundation.h>

@class AMAPermissionsConfiguration;
@class AMAPermissionsExtractor;
@protocol AMADateProviding;

@interface AMAPermissionsController : NSObject

- (instancetype)initWithConfiguration:(AMAPermissionsConfiguration *)configuration
                            extractor:(AMAPermissionsExtractor *)extractor
                         dateProvider:(id<AMADateProviding>)dateProvider;

- (NSString *)updateIfNeeded;

@end
