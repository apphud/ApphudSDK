
#import <Foundation/Foundation.h>

@interface AMAEventNameHashesCollection : NSObject

@property (nonatomic, copy) NSString *currentVersion;
@property (nonatomic, assign) NSUInteger hashesCountFromCurrentVersion;
@property (nonatomic, assign) BOOL handleNewEventsAsUnknown;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *eventNameHashes;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithCurrentVersion:(NSString *)currentVersion
         hashesCountFromCurrentVersion:(NSUInteger)hashesCountFromCurrentVersion
              handleNewEventsAsUnknown:(BOOL)handleNewEventsAsUnknown
                       eventNameHashes:(NSMutableSet<NSNumber *> *)eventNameHashes;

@end
