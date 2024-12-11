
#import <Foundation/Foundation.h>

@class AMAEnvironmentContainerActionHistory;
@class AMAEnvironmentContainer;

@interface AMAEnvironmentContainerActionRedoManager : NSObject

- (void)redoHistory:(AMAEnvironmentContainerActionHistory *)history inContainer:(AMAEnvironmentContainer *)container;

@end
