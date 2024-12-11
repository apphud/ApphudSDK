
#import "AMACore.h"
#import "AMAStartupRequest.h"
#import "AMAStartupParameters.h"

@interface AMAStartupRequest ()

@property (nonatomic, strong) NSMutableDictionary *additionalParameters;

@end

@implementation AMAStartupRequest

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _additionalParameters = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addAdditionalStartupParameters:(NSDictionary *)parameters
{
    @synchronized (self) {
        NSDictionary *filteredParams = [AMACollectionUtilities compactMapValuesOfDictionary:parameters
                                                                                  withBlock:^id(id key, id value) {
            BOOL validKey = [key isKindOfClass:NSString.class] && [key length] > 0;
            BOOL validValue = [value isKindOfClass:NSString.class] && [value length] > 0;
            return validKey && validValue ? value : nil;
        }];
        for (NSString *key in filteredParams) {
            id value = parameters[key];
            if ([key isEqual:@"features"]) {
                NSString *currentFeatures = self.additionalParameters[key];
                if (currentFeatures != nil) {
                    self.additionalParameters[key] = [NSString stringWithFormat:@"%@,%@", currentFeatures, value];
                }
                else {
                    self.additionalParameters[key] = value;
                }
            }
            else {
                self.additionalParameters[key] = value;
            }
        }
    }
}

- (NSDictionary *)headerComponents
{
    NSMutableDictionary *startupHeaders = [super headerComponents].mutableCopy;
    [AMANetworkingUtilities addUserAgentHeadersToDictionary:startupHeaders];
    [startupHeaders addEntriesFromDictionary:@{
        @"Accept": @"application/json",
        @"Accept-Encoding": @"encrypted",
    }];
    return startupHeaders.copy;
}

- (NSMutableArray *)pathComponents
{
    NSMutableArray *pathComponents = [super pathComponents].mutableCopy;
    [pathComponents addObjectsFromArray:@[ @"analytics", @"startup" ]];
    return pathComponents;
}

- (NSDictionary *)GETParameters
{
    NSMutableDictionary *parameters = [[super GETParameters] mutableCopy];
    [parameters addEntriesFromDictionary:[AMAStartupParameters parameters]];
    [self appendAdditionalParameters:parameters];
    return parameters;
}

#pragma mark - Private -

- (void)appendAdditionalParameters:(NSMutableDictionary *)parameters
{
    for (NSString *key in self.additionalParameters) {
        if ([key isEqual:@"features"]) {
            NSString *features = parameters[key];
            NSArray *additionalFeatures = [self.additionalParameters[key] componentsSeparatedByString:@","];
            NSArray *allFeatures = [[features componentsSeparatedByString:@","] arrayByAddingObjectsFromArray:additionalFeatures];
            NSArray *uniqueFeatures = [[NSSet setWithArray:allFeatures] allObjects];
            parameters[key] = [NSString stringWithFormat:@"%@", [uniqueFeatures componentsJoinedByString:@","]];
        }
        else {
            parameters[key] = self.additionalParameters[key];
        }
    }
}

@end
