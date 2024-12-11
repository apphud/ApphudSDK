
#import <Foundation/Foundation.h>
#import "AMACore.h"

@protocol AMAKeyValueStorageDataProviding;
@protocol AMAKeyValueStorageConverting;

NS_ASSUME_NONNULL_BEGIN

@interface AMAKeyValueStorage : NSObject <AMAKeyValueStoring>

@property (nonatomic, strong, readonly) id<AMAKeyValueStorageDataProviding> dataProvider;
@property (nonatomic, strong, readonly) id<AMAKeyValueStorageConverting> converter;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDataProvider:(id<AMAKeyValueStorageDataProviding>)dataProvider
                           converter:(id<AMAKeyValueStorageConverting>)converter NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
