
#import <Foundation/Foundation.h>

@class AMAEventComposer;
@class AMAReporterStateStorage;

@interface AMAEventComposerProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStateStorage:(AMAReporterStateStorage *)storage;
- (AMAEventComposer *)composerForType:(NSUInteger)type;

@end
