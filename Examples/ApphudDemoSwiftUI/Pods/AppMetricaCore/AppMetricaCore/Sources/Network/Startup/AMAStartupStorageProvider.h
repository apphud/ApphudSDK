
#import <Foundation/Foundation.h>
#import "AMACore.h"

@protocol AMADatabaseProtocol;

@interface AMAStartupStorageProvider : NSObject<AMAStartupStorageProviding>

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database;

@end
