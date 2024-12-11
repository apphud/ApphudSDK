
#import <Foundation/Foundation.h>

@protocol AMADatabaseProtocol;

@protocol AMAStorageTrimming <NSObject>

- (void)trimDatabase:(id<AMADatabaseProtocol>)database;

@end
