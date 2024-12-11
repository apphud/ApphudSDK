
#import "AMAModelSerialization.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@implementation AMAModelSerialization

+ (NSDictionary<NSString *, NSData *> *)extrasFromProtobuf:(nullable Ama__Extras*)extras
{
    if (extras == NULL) {
        return [NSDictionary dictionary];
    }

    NSMutableDictionary<NSString *, NSData *> *extrasDict = [NSMutableDictionary dictionary];

    for (size_t i = 0; i < extras->n_extras; i++) {
        Ama__Extras__ExtraEntry *extraEntry = extras->extras[i];
        NSString *key = [AMAProtobufUtilities stringForBinaryData:&extraEntry->key];
        NSData *value = [AMAProtobufUtilities dataForBinaryData:&extraEntry->value];

        extrasDict[key] = value;
    }

    return [extrasDict copy];
}

+ (BOOL)fillExtras:(Ama__Extras **)data
    withDictionary:(NSDictionary<NSString *, NSData *> *)dictionary
           tracker:(id <AMAAllocationsTracking>)tracker
{
    if (dictionary.count == 0) {
        *data = NULL;
        return NO;
    }

    Ama__Extras *extrasContainer = [tracker allocateSize:sizeof(Ama__Extras)];
    ama__extras__init(extrasContainer);

    BOOL fillData = [self fillExtrasData:extrasContainer
                          withDictionary:dictionary
                                 tracker:tracker];

    if (fillData == NO) {
        *data = NULL;
        return NO;
    }

    *data = extrasContainer;

    return YES;
}

+ (BOOL)fillExtrasData:(Ama__Extras *)data
        withDictionary:(NSDictionary<NSString *, NSData *> *)dictionary
               tracker:(id <AMAAllocationsTracking>)tracker
{
    if (dictionary.count == 0) {
        data->extras = NULL;
        data->n_extras = 0;
        return NO;
    }

    Ama__Extras__ExtraEntry **extrasArray = [tracker allocateSize:sizeof(Ama__Extras__ExtraEntry *) * dictionary.count];
    size_t pos = 0;

    for (NSString *key in dictionary.keyEnumerator) {
        Ama__Extras__ExtraEntry *extraEntry = [tracker allocateSize:sizeof(Ama__Extras__ExtraEntry)];
        ama__extras__extra_entry__init(extraEntry);

        BOOL result = [AMAProtobufUtilities fillBinaryData:&extraEntry->key
                                                withString:key
                                                   tracker:tracker];
        if (result == NO) {
            return NO;
        }

        result = [AMAProtobufUtilities fillBinaryData:&extraEntry->value
                                             withData:dictionary[key]
                                              tracker:tracker];
        if (result == NO) {
            return NO;
        }

        extrasArray[pos] = extraEntry;

        pos++;
    }

    data->n_extras = dictionary.count;
    data->extras = extrasArray;
    
    return YES;
}

@end
