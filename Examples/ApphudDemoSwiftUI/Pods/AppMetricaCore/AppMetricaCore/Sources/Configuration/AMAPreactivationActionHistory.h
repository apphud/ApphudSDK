
#import <Foundation/Foundation.h>

@class AMAEnvironmentContainerActionHistory;

@interface AMAPreactivationActionHistory : NSObject

@property (nonatomic, strong) AMAEnvironmentContainerActionHistory *appEnvironment;

@property (nonatomic, strong) NSString *userProfileID;

@end
