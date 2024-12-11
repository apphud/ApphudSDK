
#ifndef AMATypeSafeDictionaryHelper_h
#define AMATypeSafeDictionaryHelper_h

// This define expects `NSError **error` is in context and AMAErrorsFactory.h is imported.

#define AMA_GUARD_ENSURE_TYPE_OR_RETURN(CLASS, VAR, VALUE) \
    CLASS *VAR = (VALUE); \
    if ((VAR) == (id)[NSNull null]) { VAR = nil; } \
    else if ((VAR) != nil && [(VAR) isKindOfClass:[CLASS class]] == NO) { \
        NSString *errorName = \
            [NSString stringWithFormat:@"Invalid type for %s: expected %s but was %@", #VAR, #CLASS, [VAR class]]; \
        [AMAErrorUtilities fillError:error withInternalErrorName:errorName]; \
        return nil; \
    }

#endif /* AMATypeSafeDictionaryHelper_h */
