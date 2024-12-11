
#import "AMAPlainStorageTrimmer.h"
#import "AMAStorageEventsTrimTransaction.h"

@interface AMAPlainStorageTrimmer ()

@property (nonatomic, strong) AMAStorageEventsTrimTransaction *trimTransaction;

@end

@implementation AMAPlainStorageTrimmer

- (instancetype)initWithTrimTransaction:(AMAStorageEventsTrimTransaction *)trimTransaction
{
    self = [super init];
    if (self) {
        _trimTransaction = trimTransaction;
    }

    return self;
}

- (void)trimDatabase:(id<AMADatabaseProtocol>)database
{
    if (database == nil) {
        return;
    }
    [self.trimTransaction performTransactionInDatabase:database];
}

@end
