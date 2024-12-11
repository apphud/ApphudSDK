
#import <Foundation/Foundation.h>

@class AMAEventComposerBuilder;
@class AMAEvent;

@interface AMAEventComposer : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithBuilder:(AMAEventComposerBuilder *)builder;
- (void)compose:(AMAEvent *)event;

@end
