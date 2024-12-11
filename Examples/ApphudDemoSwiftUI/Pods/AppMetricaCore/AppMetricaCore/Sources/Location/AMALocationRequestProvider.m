
#import "AMACore.h"
#import "AMALocationRequestProvider.h"
#import "AMALocationSerializer.h"
#import "AMALocationRequest.h"
#import "AMALocationCollectingConfiguration.h"
#import "AMALocationStorage.h"
#import "AMALocation.h"
#import "AMAReportPayloadEncoderFactory.h"

@interface AMALocationRequestProvider ()

@property (nonatomic, strong, readonly) AMALocationStorage *storage;
@property (nonatomic, strong, readonly) AMALocationSerializer *serializer;
@property (nonatomic, strong, readonly) id<AMADataEncoding> encoder;
@property (nonatomic, strong, readonly) AMALocationCollectingConfiguration *configuration;

@end

@implementation AMALocationRequestProvider

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration
{
    return [self initWithStorage:storage
                   configuration:configuration
                      serializer:[[AMALocationSerializer alloc] init]
                         encoder:[AMAReportPayloadEncoderFactory encoder]];
}

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration
                     serializer:(AMALocationSerializer *)serializer
                        encoder:(id<AMADataEncoding>)encoder
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _serializer = serializer;
        _configuration = configuration;
        _encoder = encoder;
    }
    return self;
}

#pragma mark - Public -

- (AMALocationRequest *)nextLocationsRequest
{
    NSArray *locations = [self.storage locationsWithLimit:self.configuration.maxRecordsCountInBatch];
    NSArray *visits = nil;
    
    if (locations.count < self.configuration.maxRecordsCountInBatch) {
        visits = [self.storage visitsWithLimit:self.configuration.maxRecordsCountInBatch - locations.count];
    }

    AMALocationRequest *result = nil;
    if ((locations.count + visits.count) != 0) {
        result = [self requestWithLocations:locations visits:visits];
    }
    if (locations.count == 0) {
        AMALogError(@"Failed to load locations");
    }

    return result;
}

- (AMALocationRequest *)nextVisitsRequest
{
    NSArray *visits = [self.storage visitsWithLimit:self.configuration.maxRecordsCountInBatch];

    AMALocationRequest *result = nil;
    if (visits.count != 0) {
        result = [self requestWithLocations:nil visits:visits];
    }
    else {
        AMALogError(@"Failed to load visits");
    }

    return result;
}

#pragma mark - Private -

- (AMALocationRequest *)requestWithLocations:(NSArray *)locations visits:(NSArray *)visits
{
    AMALocationRequest *result;
    NSArray *locationIdentifiers = [self extractIdentifiers:locations];
    NSArray *visitIdentifiers = [self extractIdentifiers:visits];

    NSData *data = [self.serializer dataForLocations:locations visits:visits];
    NSError *error = nil;
    NSData *encryptedData = [self.encoder encodeData:data error:&error];
    if (error == nil) {
        NSNumber *requestIdentifier = @(self.storage.locationStorageState.requestIdentifier);
        result = [[AMALocationRequest alloc] initWithRequestIdentifier:requestIdentifier
                                                   locationIdentifiers:locationIdentifiers
                                                      visitIdentifiers:visitIdentifiers
                                                                  data:encryptedData];
    }
    else {
        AMALogError(@"Failed to encrypt locations message data: %@", error);
    }
    return result;
}

- (NSArray<NSNumber *> *)extractIdentifiers:(NSArray<id<AMAIdentifiable>> *)objects
{
    NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:objects.count];
    for (id<AMAIdentifiable> object in objects) {
        if (object.identifier != nil) {
            [identifiers addObject:object.identifier];
        }
        else {
            AMALogError(@"Undefined %@ identifier", [object class]);
        }
    }
    return [identifiers copy];
}

@end
