
#import "AMAEnvironmentContainerActionRedoManager.h"
#import "AMAEnvironmentContainerActionHistory.h"
#import "AMACore.h"
#import "AMAEnvironmentContainerAction.h"

@implementation AMAEnvironmentContainerActionRedoManager

- (void)redoHistory:(AMAEnvironmentContainerActionHistory *)history inContainer:(AMAEnvironmentContainer *)container
{
    [container performBatchUpdates:^{
        for (id<AMAEnvironmentContainerAction> action in history.trackedActions) {
            [action applyToContainer:container];
        }
    }];
}

@end
