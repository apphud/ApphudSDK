#import <Foundation/Foundation.h>
#import "Extras.pb-c.h"

@protocol AMAAllocationsTracking;

NS_ASSUME_NONNULL_BEGIN

@interface AMAModelSerialization : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (NSDictionary<NSString *, NSData *> *)extrasFromProtobuf:(nullable Ama__Extras*)extras;

+ (BOOL)fillExtras:(Ama__Extras *_Nullable *_Nonnull)data
    withDictionary:(NSDictionary<NSString *, NSData *> *)dictionary
           tracker:(id <AMAAllocationsTracking>)tracker;

+ (BOOL)fillExtrasData:(Ama__Extras *)data
        withDictionary:(NSDictionary<NSString *, NSData *> *)dictionary
               tracker:(id <AMAAllocationsTracking>)tracker;
@end

NS_ASSUME_NONNULL_END
