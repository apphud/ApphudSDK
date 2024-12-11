
#import <AppMetricaNetwork/AppMetricaNetwork.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>

static NSString *const kAMADeviceTypeKey = @"device_type";
static NSString *const kAMAAppPlatformKey = @"app_platform";
static NSString *const kAMAManufacturerKey = @"manufacturer";
static NSString *const kAMAModelKey = @"model";
static NSString *const kAMAScreenWidthKey = @"screen_width";
static NSString *const kAMAScreenHeightKey = @"screen_height";
static NSString *const kAMAScaleFactorKey = @"scalefactor";
static NSString *const kAMAScreenDPIKey = @"screen_dpi";
static NSString *const kAMAAppIDKey = @"app_id";
static NSString *const kAMAAPIKeyKey = @"api_key_128";
static NSString *const kAMAAttributionIDKey = @"attribution_id";
static NSString *const kAMARequestIDKey = @"request_id";
static NSString *const kAMAAppFrameworkKey = @"app_framework";
static NSString *const kAMAEncryptedRequestKey = @"encrypted_request";
static NSString *const kAMAStorageTypeKey = @"storage_type";

static NSString *const kAMAStorageTypeInmemoryValue = @"inmemory";

@interface AMARequestParameters ()

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *attributionID;
@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, copy) NSString *deviceType;
@property (nonatomic, copy) NSString *appPlatform;
@property (nonatomic, copy) NSString *manufacturer;
@property (nonatomic, copy) NSString *model;
@property (nonatomic, copy) NSString *screenWidth;
@property (nonatomic, copy) NSString *screenHeight;
@property (nonatomic, copy) NSString *scalefactor;
@property (nonatomic, copy) NSString *screenDPI;
@property (nonatomic, copy) NSString *appID;
@property (nonatomic, copy) AMAApplicationState *appState;
@property (nonatomic, copy) NSString *appFramework;
@property (nonatomic, assign) BOOL encryptedRequest;
@property (nonatomic, assign) BOOL inMemoryDatabase;

@end

@implementation AMARequestParameters

- (instancetype)init
{
    return [self initWithApiKey:nil 
                  attributionID:nil
                      requestID:nil
               applicationState:nil
               inMemoryDatabase:NO
                        options:AMARequestParametersDefault];
}

- (instancetype)initWithApiKey:(NSString *)apiKey
                 attributionID:(NSString *)attributionID
                     requestID:(NSString *)requestID
              applicationState:(AMAApplicationState *)appState
              inMemoryDatabase:(BOOL)inMemoryDatabase
                       options:(AMARequestParametersOptions)options
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _attributionID = [attributionID copy];
        _requestID = [requestID copy];
        _deviceType = [[AMAPlatformDescription deviceType] copy];
        _appPlatform = [[AMAPlatformDescription OSName] copy];
        _manufacturer = [[AMAPlatformDescription manufacturer] copy];
        _model = [[AMAPlatformDescription model] copy];
        _screenWidth = [[AMAPlatformDescription screenWidth] copy];
        _screenHeight = [[AMAPlatformDescription screenHeight] copy];
        _scalefactor = [[AMAPlatformDescription scalefactor] copy];
        _screenDPI = [[AMAPlatformDescription screenDPI] copy];
        _appID = [[AMAPlatformDescription appID] copy];
        _appState = [appState copy];
        _appFramework = [[AMAPlatformDescription appFramework] copy];
        _encryptedRequest = YES;
        _inMemoryDatabase = inMemoryDatabase;
        _options = options;
    }
    return self;
}

#pragma mark - AMADictionaryRepresentation

+ (instancetype)objectWithDictionaryRepresentation:(NSDictionary *)dictionary
{
    AMARequestParameters *parameters = [[AMARequestParameters alloc] init];
    parameters.appState = [AMAApplicationState objectWithDictionaryRepresentation:dictionary];
    parameters.deviceType = [dictionary[kAMADeviceTypeKey] copy];
    parameters.apiKey = [dictionary[kAMAAPIKeyKey] copy];
    parameters.attributionID = [dictionary[kAMAAttributionIDKey] copy];
    parameters.requestID = [dictionary[kAMARequestIDKey] copy];
    parameters.appPlatform = [dictionary[kAMAAppPlatformKey] copy];
    parameters.manufacturer = [dictionary[kAMAManufacturerKey] copy];
    parameters.model = [dictionary[kAMAModelKey] copy];
    parameters.screenWidth = [dictionary[kAMAScreenWidthKey] copy];
    parameters.screenHeight = [dictionary[kAMAScreenHeightKey] copy];
    parameters.scalefactor = [dictionary[kAMAScaleFactorKey] copy];
    parameters.screenDPI = [dictionary[kAMAScreenDPIKey] copy];
    parameters.appID = [dictionary[kAMAAppIDKey] copy];
    parameters.appFramework = [dictionary[kAMAAppFrameworkKey] copy];
    parameters.encryptedRequest = [dictionary[kAMAEncryptedRequestKey] isEqual:@"1"];
    parameters.inMemoryDatabase = [dictionary[kAMAStorageTypeKey] isEqual:kAMAStorageTypeInmemoryValue];
    return parameters;
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[kAMADeviceTypeKey] = self.deviceType;
    parameters[kAMAAppPlatformKey] = self.appPlatform;
    parameters[kAMAManufacturerKey] = self.manufacturer;
    parameters[kAMAModelKey] = self.model;
    parameters[kAMAScreenWidthKey] = self.screenWidth;
    parameters[kAMAScreenHeightKey] = self.screenHeight;
    parameters[kAMAScaleFactorKey] = self.scalefactor;
    parameters[kAMAScreenDPIKey] = self.screenDPI;
    parameters[kAMAAppIDKey] = self.appID;
    parameters[kAMAAPIKeyKey] = self.apiKey;
    parameters[kAMAAttributionIDKey] = self.attributionID;
    parameters[kAMARequestIDKey] = self.requestID;
    parameters[kAMAAppFrameworkKey] = self.appFramework;
    parameters[kAMAEncryptedRequestKey] = self.encryptedRequest ? @"1" : @"0";
    parameters[kAMAStorageTypeKey] = self.inMemoryDatabase ? kAMAStorageTypeInmemoryValue : nil;
    
    NSDictionary *appStateDictionary = [self.appState dictionaryRepresentation];
    if (appStateDictionary != nil) {
        if (self.options & AMARequestParametersAllowIDFA) {
            [parameters addEntriesFromDictionary:appStateDictionary];
        }
        else {
            NSMutableDictionary *mutableDictionary = appStateDictionary.mutableCopy;
            [mutableDictionary removeObjectsForKeys:@[kAMAIFAKey, kAMALATKey]];
            [parameters addEntriesFromDictionary:mutableDictionary];
        }
    }
    return parameters;
}

@end
