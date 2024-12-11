
typedef NS_ENUM(NSUInteger, AMAEventType) {
    AMAEventTypeInit = 1,
    AMAEventTypeStart = 2,
    AMAEventTypeClient = 4,
    AMAEventTypeReferrer __attribute__((deprecated("This event type is no longer supported"))) = 5,
    AMAEventTypeAlive = 7,
    AMAEventTypeFirst = 13,
    AMAEventTypeOpen = 16,
    AMAEventTypeUpdate = 17,
    AMAEventTypePermissions = 18,
    AMAEventTypeProfile = 20,
    AMAEventTypeRevenue = 21,
    AMAEventTypeProtobufANR = 25, // TODO: remove Crashes reference here
    AMAEventTypeProtobufCrash = 26, // TODO: remove Crashes reference here
    AMAEventTypeProtobufError = 27, // TODO: remove Crashes reference here
    AMAEventTypeCleanup = 29, // Excluded from AMAEventCountDispatchStrategy
    AMAEventTypeECommerce = 35,
    AMAEventTypeASAToken = 37,
    AMAEventTypeWebViewSync = 38,
    AMAEventTypeAttribution = 39,
    AMAEventTypeAdRevenue = 40,
    AMAEventTypeApplePrivacy = 41,
    AMAEventTypeExternalAttribution = 42,
};
