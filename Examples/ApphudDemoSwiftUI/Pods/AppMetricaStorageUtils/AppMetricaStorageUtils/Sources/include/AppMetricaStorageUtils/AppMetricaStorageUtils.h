
#if __has_include("AppMetricaStorageUtils.h")
    #import "AMADiskFileStorage.h"
    #import "AMAFileStorage.h"
    #import "AMAIncrementableValueStorage.h"
    #import "AMAIncrementableValueStorageFactory.h"
    #import "AMAKeyValueStorageDataProviding.h"
    #import "AMAKeyValueStorageProviding.h"
    #import "AMAKeyValueStoring.h"
    #import "AMARollbackHolder.h"
    #import "AMAUserDefaultsKVSDataProvider.h"
    #import "AMAUserDefaultsStorage.h"
#else
    #import <AppMetricaStorageUtils/AMADiskFileStorage.h>
    #import <AppMetricaStorageUtils/AMAFileStorage.h>
    #import <AppMetricaStorageUtils/AMAIncrementableValueStorage.h>
    #import <AppMetricaStorageUtils/AMAIncrementableValueStorageFactory.h>
    #import <AppMetricaStorageUtils/AMAKeyValueStorageDataProviding.h>
    #import <AppMetricaStorageUtils/AMAKeyValueStorageProviding.h>
    #import <AppMetricaStorageUtils/AMAKeyValueStoring.h>
    #import <AppMetricaStorageUtils/AMARollbackHolder.h>
    #import <AppMetricaStorageUtils/AMAUserDefaultsKVSDataProvider.h>
    #import <AppMetricaStorageUtils/AMAUserDefaultsStorage.h>
#endif
