
#import <Foundation/Foundation.h>
#import "AMAEventTypes.h"
#import "AMAEventEncryptionType.h"
#import "AMAOptionalBool.h"
#import "AMAEventSource.h"

@class CLLocation;
@protocol AMAEventValueProtocol;

@interface AMAEvent : NSObject

@property (nonatomic, strong) NSNumber *oid;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSNumber *sessionOid;
@property (nonatomic, assign) NSUInteger sequenceNumber;
@property (nonatomic, assign) NSUInteger globalNumber;
@property (nonatomic, assign) NSUInteger numberOfType;
@property (nonatomic, assign) NSTimeInterval timeSinceSession;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) id<AMAEventValueProtocol> value;

@property (nonatomic, assign) NSUInteger type; // AMAEventType
@property (nonatomic, copy) CLLocation *location;
@property (nonatomic, assign) AMAOptionalBool locationEnabled;
@property (nonatomic, copy) NSDictionary *eventEnvironment;
@property (nonatomic, copy) NSDictionary *appEnvironment;
@property (nonatomic, copy) NSString *profileID;
@property (nonatomic, assign) NSUInteger bytesTruncated;
@property (nonatomic, assign) AMAOptionalBool firstOccurrence;
@property (nonatomic, assign) AMAEventSource source;
@property (nonatomic, assign) BOOL attributionIDChanged;
@property (nonatomic, assign) NSNumber *openID;
@property (nonatomic, copy) NSDictionary<NSString *, NSData *> *extras;

- (void)cleanup;

@end
