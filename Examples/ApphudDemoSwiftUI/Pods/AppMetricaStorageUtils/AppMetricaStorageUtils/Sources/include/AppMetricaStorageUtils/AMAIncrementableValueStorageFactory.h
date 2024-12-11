
#import <Foundation/Foundation.h>

@class AMAIncrementableValueStorage;

typedef NSString *const AMAStorageKey NS_TYPED_ENUM NS_SWIFT_NAME(StorageKey);

extern AMAStorageKey kAMAAttributionIDStorageKey;
extern AMAStorageKey kAMALastSessionIDStorageKey;
extern AMAStorageKey kAMAGlobalEventNumberStorageKey;
extern AMAStorageKey kAMARequestIdentifierStorageKey;
extern AMAStorageKey kAMAOpenIDStorageKey;

NS_SWIFT_NAME(IncrementableValueStorageFactory)
@interface AMAIncrementableValueStorageFactory : NSObject

+ (AMAIncrementableValueStorage *)attributionIDStorage;
+ (AMAIncrementableValueStorage *)lastSessionIDStorage;
+ (AMAIncrementableValueStorage *)globalEventNumberStorage;
+ (AMAIncrementableValueStorage *)eventNumberOfTypeStorageForEventType:(NSUInteger)eventType;
+ (AMAIncrementableValueStorage *)requestIdentifierStorage;
+ (AMAIncrementableValueStorage *)openIDStorage;

@end
