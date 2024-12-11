
#import <Foundation/Foundation.h>
#import "AMACore.h"

@protocol AMADatabaseProtocol;

@interface AMACachingStorageProvider : NSObject<AMACachingStorageProviding>

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database;

@end
