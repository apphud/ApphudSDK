#import "AMADecodedCrashSerializer.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACrashLogging.h"
#import "AMAApplicationStatistics.h"
#import "AMABacktrace.h"
#import "AMABacktraceFrame.h"
#import "AMABinaryImage.h"
#import "AMACppException.h"
#import "AMACrashReportCrash.h"
#import "AMACrashReportError.h"
#import "AMADecodedCrash.h"
#import "AMADecodedCrashValidator.h"
#import "AMAErrorCustomData.h"
#import "AMAErrorModel.h"
#import "AMAErrorNSErrorData.h"
#import "AMAInfo.h"
#import "AMAMach.h"
#import "AMAMemory.h"
#import "AMANSException.h"
#import "AMANonFatal.h"
#import "AMARegister.h"
#import "AMARegistersContainer.h"
#import "AMASignal.h"
#import "AMAStack.h"
#import "AMASystem.h"
#import "AMAThread.h"
#import "AMAVirtualMachineCrash.h"
#import "AMAVirtualMachineError.h"
#import "AMAVirtualMachineInfo.h"
#import "Crash.pb-c.h"

@implementation AMADecodedCrashSerializer

#pragma mark - Public

- (NSData *)dataForCrash:(AMADecodedCrash *)decodedCrash error:(NSError **)error
{
    NSData *__block data = nil;
    NSError *__block capturedError = nil;
    AMADecodedCrashValidator *validator = [[AMADecodedCrashValidator alloc] init];

    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {

        Ama__IOSCrashReport__Info *info = NULL;
        Ama__IOSCrashReport__BinaryImage **binaryImages = NULL;
        Ama__IOSCrashReport__System *system = NULL;
        Ama__IOSCrashReport__Crash *crash = NULL;
        size_t imagesCount = 0;

        if ([validator validateDecodedCrash:decodedCrash] == NO) {
            info = [self createInfoWithObject:decodedCrash.info allocationTracker:tracker validator:validator];
            system = [self createSystemWithObject:decodedCrash.system allocationTracker:tracker validator:validator];
            crash = [self createCrashWithObject:decodedCrash.crash allocationTracker:tracker validator:validator];
            binaryImages = [self createBinaryImageArrayWithObject:decodedCrash.binaryImages
                                                allocationTracker:tracker
                                                      imagesCount:&imagesCount
                                                        validator:validator];
        }
        
        capturedError = [validator result];
        
        if (capturedError.code != AMACrashValidatorErrorCodeCritical) {
            Ama__IOSCrashReport report = AMA__IOSCRASH_REPORT__INIT;
            report.info = info;
            report.binary_images = binaryImages;
            report.n_binary_images = imagesCount;
            report.system = system;
            report.crash = crash;

            size_t size = ama__ioscrash_report__get_packed_size(&report);
            void *buffer = malloc(size);
            ama__ioscrash_report__pack(&report, buffer);
            data = [NSData dataWithBytesNoCopy:buffer length:size];
            
            if (capturedError.code == AMACrashValidatorErrorCodeSuspicious) {
                AMALogError(@"There were suspicious errors while AMADecodedCrash: %@ serialization.\n"
                                    "Error details: %@",
                                    decodedCrash, capturedError);
            }
        }
        else {
            AMALogError(@"An error occurred while AMADecodedCrash: %@ serialization.\n"
                                "Error details: %@.\n"
                                "Trying to report the error to AppMetrica",
                                decodedCrash, capturedError);
        }
    }];
    
    [AMAErrorUtilities fillError:error withError:capturedError];

    return data;
}

#pragma mark - Private

- (Ama__IOSCrashReport__Info *)createInfoWithObject:(AMAInfo *)info
                                  allocationTracker:(id<AMAAllocationsTracking>)tracker
                                          validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__Info *message = NULL;

    if ([validator validateInfo:info] == NO) {
        message = [tracker allocateSize:sizeof(Ama__IOSCrashReport__Info)];
        ama__ioscrash_report__info__init(message);

        message->has_version = [AMAProtobufUtilities fillBinaryData:&message->version
                                                         withString:info.version
                                                            tracker:tracker];
        [AMAProtobufUtilities fillBinaryData:&message->id withString:info.identifier tracker:tracker];
        message->timestamp = (int64_t)info.timestamp.timeIntervalSince1970;
        message->virtual_machine_info = [self createVirtualMachineInfoWithObject:info.virtualMachineInfo tracker:tracker];
    }

    return message;
}

- (Ama__IOSCrashReport__BinaryImage **)createBinaryImageArrayWithObject:(NSArray<AMABinaryImage *> *)binaryImages
                                                      allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                            imagesCount:(size_t *)count
                                                              validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__BinaryImage **images =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__BinaryImage *) * binaryImages.count];
    size_t serializedCount = 0;

    for (AMABinaryImage *image in binaryImages) {
        if ([validator validateBinaryImage:image] == NO) {
            images[serializedCount] = [tracker allocateSize:sizeof(Ama__IOSCrashReport__BinaryImage)];
            Ama__IOSCrashReport__BinaryImage *currentImage = images[serializedCount];
            ama__ioscrash_report__binary_image__init(currentImage);

            currentImage->address = image.address;
            currentImage->size = image.size;
            currentImage->cpu_type = (int32_t)image.cpuType;
            currentImage->cpu_subtype = (int32_t)image.cpuSubtype;
            currentImage->major_version = image.majorVersion;
            currentImage->minor_version = image.minorVersion;
            currentImage->revision_version = image.revisionVersion;
            [AMAProtobufUtilities fillBinaryData:&currentImage->path withString:image.name tracker:tracker];
            [AMAProtobufUtilities fillBinaryData:&currentImage->uuid withString:image.UUID tracker:tracker];
            currentImage->has_crash_info_message =
                [AMAProtobufUtilities fillBinaryData:&currentImage->crash_info_message
                                          withString:image.crashInfoMessage
                                             tracker:tracker];
            currentImage->has_crash_info_message2 =
                [AMAProtobufUtilities fillBinaryData:&currentImage->crash_info_message2
                                          withString:image.crashInfoMessage2
                                             tracker:tracker];
            serializedCount++;
        }
    }

    if (count != NULL) {
        *count = serializedCount;
    }

    return images;
}

- (Ama__IOSCrashReport__System *)createSystemWithObject:(AMASystem *)system
                                      allocationTracker:(id<AMAAllocationsTracking>)tracker
                                              validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__System *sys = NULL;

    if ([validator validateSystem:system] == NO) {
        sys = [tracker allocateSize:sizeof(Ama__IOSCrashReport__System)];
        ama__ioscrash_report__system__init(sys);
        Ama__IOSCrashReport__System__Memory
            *memory = [self createMemoryWithObject:system.memory allocationTracker:tracker validator:validator];
        Ama__IOSCrashReport__System__ApplicationStats *stats = [self createStatsWithObject:system.applicationStats
                                                                         allocationTracker:tracker
                                                                                 validator:validator];

        sys->has_kernel_version = system.kernelVersion != nil;
        if (sys->has_kernel_version) {
            [AMAProtobufUtilities fillBinaryData:&sys->kernel_version withString:system.kernelVersion tracker:tracker];
        }
        sys->has_os_build_number = system.osBuildNumber != nil;
        if (sys->has_os_build_number) {
            [AMAProtobufUtilities fillBinaryData:&sys->os_build_number withString:system.osBuildNumber tracker:tracker];
        }
        sys->has_executable_path = system.executablePath != nil;
        if (sys->has_executable_path) {
            [AMAProtobufUtilities fillBinaryData:&sys->executable_path withString:system.executablePath tracker:tracker];
        }
        sys->has_cpu_arch = system.cpuArch != nil;
        if (sys->has_cpu_arch) {
            [AMAProtobufUtilities fillBinaryData:&sys->cpu_arch withString:system.cpuArch tracker:tracker];
        }
        sys->has_process_name = system.processName != nil;
        if (sys->has_process_name) {
            [AMAProtobufUtilities fillBinaryData:&sys->process_name withString:system.processName tracker:tracker];
        }
        sys->has_build_type = true;
        sys->build_type = [self buildTypeToProtobuf:system.buildType];
        sys->has_boot_timestamp = true;
        sys->boot_timestamp = (int64_t)system.bootTimestamp.timeIntervalSince1970;
        sys->has_app_start_timestamp = true;
        sys->app_start_timestamp = (int64_t)system.appStartTimestamp.timeIntervalSince1970;
        sys->has_cpu_type = true;
        sys->cpu_type = system.cpuType;
        sys->has_cpu_subtype = true;
        sys->cpu_subtype = system.cpuSubtype;
        sys->has_binary_cpu_type = true;
        sys->binary_cpu_type = system.binaryCpuType;
        sys->has_binary_cpu_subtype = true;
        sys->binary_cpu_subtype = system.binaryCpuSubtype;
        sys->has_process_id = true;
        sys->process_id = system.processId;
        sys->has_parent_process_id = true;
        sys->parent_process_id = system.parentProcessId;
        sys->has_storage = true;
        sys->storage = system.storage;
        sys->memory = memory;
        sys->application_stats = stats;
    }

    return sys;
}

#pragma mark - Crash

- (Ama__IOSCrashReport__Crash *)createCrashWithObject:(AMACrashReportCrash *)crash
                                    allocationTracker:(id<AMAAllocationsTracking>)tracker
                                            validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__Crash *crashReport = NULL;

    if ([validator validateCrash:crash] == NO) {
        crashReport = [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash)];
        ama__ioscrash_report__crash__init(crashReport);

        crashReport->error = [self createErrorWithObject:crash.error allocationTracker:tracker validator:validator];

        size_t threadCount = 0;
        crashReport->threads = [self createThreadsArrayWithObject:crash.threads
                                                allocationTracker:tracker
                                                      threadCount:&threadCount
                                                        validator:validator];
        crashReport->n_threads = threadCount;
    }

    return crashReport;
}

#pragma mark - System

- (Ama__IOSCrashReport__System__Memory *)createMemoryWithObject:(AMAMemory *)memory
                                              allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                      validator:(AMADecodedCrashValidator *)validator
{
    if (memory == nil) {
        return NULL;
    }
    [validator validateMemory:memory];
    Ama__IOSCrashReport__System__Memory *mem = [tracker allocateSize:sizeof(Ama__IOSCrashReport__System__Memory)];
    ama__ioscrash_report__system__memory__init(mem);

    mem->size = memory.size;
    mem->usable = memory.usable;
    mem->free = memory.free;
    return mem;
}

- (Ama__IOSCrashReport__System__ApplicationStats *)createStatsWithObject:(AMAApplicationStatistics *)stats
                                                       allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                               validator:(AMADecodedCrashValidator *)validator
{
    if (stats == nil) {
        return NULL;
    }
    [validator validateAppStats:stats];

    Ama__IOSCrashReport__System__ApplicationStats *appStats =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__System__ApplicationStats)];
    ama__ioscrash_report__system__application_stats__init(appStats);

    appStats->application_active = stats.applicationActive;
    appStats->application_in_foreground = stats.applicationInForeground;
    appStats->launches_since_last_crash = stats.launchesSinceLastCrash;
    appStats->sessions_since_last_crash = stats.sessionsSinceLastCrash;
    appStats->active_time_since_last_crash = stats.activeTimeSinceLastCrash;
    appStats->background_time_since_last_crash = stats.backgroundTimeSinceLastCrash;
    appStats->sessions_since_launch = stats.sessionsSinceLaunch;
    appStats->active_time_since_launch = stats.activeTimeSinceLaunch;
    appStats->background_time_since_launch = stats.backgroundTimeSinceLaunch;
    return appStats;
}

#pragma mark Error

- (Ama__IOSCrashReport__Crash__Error *)createErrorWithObject:(AMACrashReportError *)crashError
                                           allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                   validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__Crash__Error *err = NULL;

    if ([validator validateError:crashError] == NO) {
        Ama__IOSCrashReport__Crash__Error__Mach *mach =
            [self createMachWithObject:crashError.mach allocationTracker:tracker];
        Ama__IOSCrashReport__Crash__Error__Signal *signal =
            [self createSignalWithObject:crashError.signal allocationTracker:tracker];
        Ama__IOSCrashReport__Crash__Error__NsException *nsException =
            [self createNsExceptionWithObject:crashError.nsException allocationTracker:tracker];
        Ama__IOSCrashReport__Crash__Error__CppException *cppException =
            [self createCppExceptionWithObject:crashError.cppException allocationTracker:tracker];
        Ama__IOSCrashReport__Crash__Error__VirtualMachineCrash *virtualMachineCrash =
            [self createVirtualMachineCrashWithObject:crashError.virtualMachineCrash allocationTracker:tracker];
        size_t nonFatalsCount = 0;
        Ama__IOSCrashReport__Crash__Error__NonFatal **nonFatalsChain =
            [self createNonFatalsChainWithArray:crashError.nonFatalsChain
                              allocationTracker:tracker
                                      validator:validator
                                          count:&nonFatalsCount];

        err = [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error)];
        ama__ioscrash_report__crash__error__init(err);

        err->has_reason =
            [AMAProtobufUtilities fillBinaryData:&err->reason withString:crashError.reason tracker:tracker];
        err->has_address = crashError.address != 0x0;
        if (crashError.address != 0x0) {
            err->address = crashError.address;
        }
        err->type = [self crashTypeToProtobuf:crashError.type];
        err->mach = mach;
        err->signal = signal;
        err->nsexception = nsException;
        err->cpp_exception = cppException;
        err->virtual_machine_crash = virtualMachineCrash;
        err->n_non_fatals_chain = nonFatalsCount;
        err->non_fatals_chain = nonFatalsChain;
    }

    return err;
}

- (Ama__IOSCrashReport__Crash__Error__Mach *)createMachWithObject:(AMAMach *)errorMach
                                                allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (errorMach == nil) {
        return NULL;
    }
    Ama__IOSCrashReport__Crash__Error__Mach *mach =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__Mach)];
    ama__ioscrash_report__crash__error__mach__init(mach);
    mach->exception_type = errorMach.exceptionType;
    mach->code = errorMach.code;
    mach->subcode = errorMach.subcode;
    return mach;
}

- (Ama__IOSCrashReport__Crash__Error__Signal *)createSignalWithObject:(AMASignal *)crashSignal
                                                    allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (crashSignal == nil) {
        return NULL;
    }
    Ama__IOSCrashReport__Crash__Error__Signal *signal =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__Signal)];
    ama__ioscrash_report__crash__error__signal__init(signal);
    signal->signal = crashSignal.signal;
    signal->code = crashSignal.code;
    return signal;
}

- (Ama__IOSCrashReport__Crash__Error__NsException *)createNsExceptionWithObject:(AMANSException *)crashException
                                                              allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (crashException == nil) {
        return NULL;
    }
    Ama__IOSCrashReport__Crash__Error__NsException *nsException =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__NsException)];
    ama__ioscrash_report__crash__error__ns_exception__init(nsException);
    nsException->has_name = [AMAProtobufUtilities fillBinaryData:&nsException->name
                                                      withString:crashException.name
                                                         tracker:tracker];
    nsException->has_user_info = [AMAProtobufUtilities fillBinaryData:&nsException->user_info
                                                           withString:crashException.userInfo
                                                              tracker:tracker];
    return nsException;
}

- (Ama__IOSCrashReport__Crash__Error__CppException *)createCppExceptionWithObject:(AMACppException *)crashException
                                                                allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (crashException == nil) {
        return NULL;
    }
    Ama__IOSCrashReport__Crash__Error__CppException *cppException =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__CppException)];
    ama__ioscrash_report__crash__error__cpp_exception__init(cppException);
    cppException->has_name = [AMAProtobufUtilities fillBinaryData:&cppException->name
                                                       withString:crashException.name
                                                          tracker:tracker];
    return cppException;
}

- (Ama__IOSCrashReport__Crash__Error__VirtualMachineCrash *)createVirtualMachineCrashWithObject:(AMAVirtualMachineCrash *)crash
                                                                              allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (crash == nil) {
        return NULL;
    }
    Ama__IOSCrashReport__Crash__Error__VirtualMachineCrash *protoCrash =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__VirtualMachineCrash)];
    ama__ioscrash_report__crash__error__virtual_machine_crash__init(protoCrash);
    protoCrash->has_class_name = [AMAProtobufUtilities fillBinaryData:&protoCrash->class_name
                                                           withString:crash.className
                                                              tracker:tracker];
    protoCrash->has_message = [AMAProtobufUtilities fillBinaryData:&protoCrash->message
                                                        withString:crash.message
                                                           tracker:tracker];
    protoCrash->cause = NULL;
    return protoCrash;
}

- (Ama__IOSCrashReport__Crash__Error__NonFatal **)createNonFatalsChainWithArray:(NSArray<AMANonFatal *> *)nonFatals
                                                              allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                                      validator:(AMADecodedCrashValidator *)validator
                                                                          count:(size_t *)count
{
    size_t nonFatalsCount = (size_t)nonFatals.count;
    if (nonFatalsCount == 0) {
        *count = 0;
        return NULL;
    }

    Ama__IOSCrashReport__Crash__Error__NonFatal **nonFatalsChain =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__NonFatal *) * nonFatalsCount];
    [nonFatals enumerateObjectsUsingBlock:^(AMANonFatal *nonFatal, NSUInteger idx, BOOL *stop) {
        nonFatalsChain[idx] = [self createNonFatalWithObject:nonFatal
                                           allocationTracker:tracker
                                                   validator:validator];
    }];

    *count = nonFatalsCount;
    return nonFatalsChain;
}

- (Ama__IOSCrashReport__Crash__Error__NonFatal *)createNonFatalWithObject:(AMANonFatal *)crashException
                                                        allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                                validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__Crash__Error__NonFatal *nonFatal =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__NonFatal)];
    ama__ioscrash_report__crash__error__non_fatal__init(nonFatal);

    nonFatal->type = [self nonFatalTypeForType:crashException.model.type];
    nonFatal->has_parameters = [AMAProtobufUtilities fillBinaryData:&nonFatal->parameters
                                                         withString:crashException.model.parametersString
                                                            tracker:tracker];
    nonFatal->backtrace = [self createBacktraceWithObject:crashException.backtrace
                                        allocationTracker:tracker
                                                validator:validator];

    nonFatal->custom = [self createNonFatalCustomWithData:crashException.model.customData allocationTracker:tracker];
    nonFatal->nserror = [self createNonFatalNsErrorWithData:crashException.model.nsErrorData allocationTracker:tracker];
    nonFatal->virtual_machine_error =
        [self createNonFatalVirtualMachineErrorWithData:crashException.model.virtualMachineError
                                      allocationTracker:tracker];

    return nonFatal;
}

- (Ama__IOSCrashReport__Crash__Error__NonFatal__NonFatalType)nonFatalTypeForType:(AMAErrorModelType)type
{
    switch (type) {
        case AMAErrorModelTypeCustom:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__NON_FATAL__NON_FATAL_TYPE__CUSTOM;
        case AMAErrorModelTypeNSError:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__NON_FATAL__NON_FATAL_TYPE__NSERROR;
        case AMAErrorModelTypeVirtualMachine:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__NON_FATAL__NON_FATAL_TYPE__VIRTUAL_MACHINE;
        case AMAErrorModelTypeVirtualMachineCustom:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__NON_FATAL__NON_FATAL_TYPE__VIRTUAL_MACHINE_CUSTOM;
        default:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__NON_FATAL__NON_FATAL_TYPE__CUSTOM;
    }
}

- (Ama__IOSCrashReport__Crash__Error__NonFatal__Custom *)createNonFatalCustomWithData:(AMAErrorCustomData *)data
                                                                    allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (data == nil) {
        return NULL;
    }

    Ama__IOSCrashReport__Crash__Error__NonFatal__Custom *result =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__NonFatal__Custom)];
    ama__ioscrash_report__crash__error__non_fatal__custom__init(result);

    [AMAProtobufUtilities fillBinaryData:&result->identifier
                              withString:data.identifier
                                 tracker:tracker];
    result->has_message = [AMAProtobufUtilities fillBinaryData:&result->message
                                                      withString:data.message
                                                         tracker:tracker];
    result->has_class_name = [AMAProtobufUtilities fillBinaryData:&result->class_name
                                                       withString:data.className
                                                          tracker:tracker];

    return result;
}

- (Ama__IOSCrashReport__Crash__Error__NonFatal__NsError *)createNonFatalNsErrorWithData:(AMAErrorNSErrorData *)data
                                                                      allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (data == nil) {
        return NULL;
    }

    Ama__IOSCrashReport__Crash__Error__NonFatal__NsError *result =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__NonFatal__NsError)];
    ama__ioscrash_report__crash__error__non_fatal__ns_error__init(result);

    [AMAProtobufUtilities fillBinaryData:&result->domain
                              withString:data.domain
                                 tracker:tracker];
    result->code = (int64_t)data.code;

    return result;
}

- (Ama__IOSCrashReport__Crash__Error__NonFatal__VirtualMachineError *)
createNonFatalVirtualMachineErrorWithData:(AMAVirtualMachineError *)data
                        allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    if (data == nil) {
        return NULL;
    }

    Ama__IOSCrashReport__Crash__Error__NonFatal__VirtualMachineError *result =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Error__NonFatal__VirtualMachineError)];
    ama__ioscrash_report__crash__error__non_fatal__virtual_machine_error__init(result);

    result->has_message = [AMAProtobufUtilities fillBinaryData:&result->message
                                                    withString:data.message
                                                       tracker:tracker];
    result->has_class_name = [AMAProtobufUtilities fillBinaryData:&result->class_name
                                                       withString:data.className
                                                          tracker:tracker];

    return result;
}

#pragma mark Threads

- (Ama__IOSCrashReport__Crash__Thread **)createThreadsArrayWithObject:(NSArray<AMAThread *> *)threadsArray
                                                    allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                          threadCount:(size_t *)count
                                                            validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__Crash__Thread **threads =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__BinaryImage *) * threadsArray.count];
    size_t serializedCount = 0;

    for (AMAThread *crashThread in threadsArray) {
        Ama__IOSCrashReport__Crash__Backtrace *backtrace = NULL;
        if (crashThread.backtrace != nil) {
            backtrace =
                [self createBacktraceWithObject:crashThread.backtrace allocationTracker:tracker validator:validator];
        }

        Ama__IOSCrashReport__Crash__Thread__Registers *registers = NULL;
        if (crashThread.registers != nil) {
            registers =
                [self createRegistersWithObject:crashThread.registers allocationTracker:tracker validator:validator];
        }

        Ama__IOSCrashReport__Crash__Thread__Stack *stack = NULL;
        if (crashThread.stack != nil) {
            stack = [self createStackWithObject:crashThread.stack allocationTracker:tracker];
        }

        Ama__IOSCrashReport__Crash__Thread *thread = [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Thread)];
        ama__ioscrash_report__crash__thread__init(thread);
        threads[serializedCount] = thread;

        thread->backtrace = backtrace;
        thread->registers = registers;
        thread->stack = stack;
        thread->index = crashThread.index;
        thread->crashed = crashThread.crashed;
        thread->has_name = [AMAProtobufUtilities fillBinaryData:&thread->name
                                                     withString:crashThread.threadName
                                                        tracker:tracker];
        thread->has_dispatch_queue_name = [AMAProtobufUtilities fillBinaryData:&thread->dispatch_queue_name
                                                                    withString:crashThread.queueName
                                                                       tracker:tracker];

        serializedCount++;
    }

    if (count != NULL) {
        *count = serializedCount;
    }

    return threads;
}

- (Ama__IOSCrashReport__Crash__Backtrace *)createBacktraceWithObject:(AMABacktrace *)threadBacktrace
                                                   allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                           validator:(AMADecodedCrashValidator *)validator
{
    if (threadBacktrace == nil) {
        return NULL;
    }
    Ama__IOSCrashReport__Crash__Backtrace__Frame **frames =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Backtrace__Frame *) * threadBacktrace.frames.count];
    size_t serializedCount = 0;

    for (AMABacktraceFrame *backtraceFrame in threadBacktrace.frames) {
        if ([validator validateBacktraceFrame:backtraceFrame] == NO) {
            Ama__IOSCrashReport__Crash__Backtrace__Frame *frame =
                [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Backtrace__Frame)];
            ama__ioscrash_report__crash__backtrace__frame__init(frame);

            frame->has_instruction_addr = backtraceFrame.instructionAddress != nil;
            if (backtraceFrame.instructionAddress != nil) {
                frame->instruction_addr = backtraceFrame.instructionAddress.unsignedLongLongValue;
            }
            frame->has_object_name = [AMAProtobufUtilities fillBinaryData:&frame->object_name
                                                               withString:backtraceFrame.objectName
                                                                  tracker:tracker];
            frame->has_symbol_name = [AMAProtobufUtilities fillBinaryData:&frame->symbol_name
                                                               withString:backtraceFrame.symbolName
                                                                  tracker:tracker];
            frame->has_class_name = [AMAProtobufUtilities fillBinaryData:&frame->class_name
                                                              withString:backtraceFrame.className
                                                                 tracker:tracker];
            frame->has_method_name = [AMAProtobufUtilities fillBinaryData:&frame->method_name
                                                               withString:backtraceFrame.methodName
                                                                  tracker:tracker];
            frame->has_source_file_name = [AMAProtobufUtilities fillBinaryData:&frame->source_file_name
                                                                    withString:backtraceFrame.sourceFileName
                                                                       tracker:tracker];

            frame->object_addr = backtraceFrame.objectAddress.unsignedLongLongValue;
            frame->has_object_addr = backtraceFrame.objectAddress != nil;

            frame->symbol_addr = backtraceFrame.symbolAddress.unsignedLongLongValue;
            frame->has_symbol_addr = backtraceFrame.symbolAddress != nil;

            frame->line_of_code = backtraceFrame.lineOfCode.unsignedLongLongValue;
            frame->has_line_of_code = backtraceFrame.lineOfCode != nil;

            frame->column_of_code = backtraceFrame.columnOfCode.unsignedIntValue;
            frame->has_column_of_code = backtraceFrame.columnOfCode != nil;

            frames[serializedCount] = frame;
            serializedCount++;
        }
    }

    Ama__IOSCrashReport__Crash__Backtrace *backtrace =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Backtrace)];
    ama__ioscrash_report__crash__backtrace__init(backtrace);
    backtrace->frames = frames;
    backtrace->n_frames = serializedCount;

    return backtrace;
}

- (Ama__IOSCrashReport__Crash__Thread__Registers *)createRegistersWithObject:(AMARegistersContainer *)threadRegisters
                                                           allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                                   validator:(AMADecodedCrashValidator *)validator
{
    size_t basicCount = 0;
    Ama__IOSCrashReport__Crash__Thread__Registers__Register **basic =
        [self createRegistersArrayWithObject:threadRegisters.basic
                           allocationTracker:tracker
                               registerCount:&basicCount
                                   validator:validator];

    size_t exceptionCount = 0;
    Ama__IOSCrashReport__Crash__Thread__Registers__Register **exception =
        [self createRegistersArrayWithObject:threadRegisters.exception
                           allocationTracker:tracker
                               registerCount:&exceptionCount
                                   validator:validator];

    Ama__IOSCrashReport__Crash__Thread__Registers *registers =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Thread__Registers)];
    ama__ioscrash_report__crash__thread__registers__init(registers);

    registers->basic = basic;
    registers->n_basic = basicCount;
    registers->exception = exception;
    registers->n_exception = exceptionCount;

    return registers;
}

- (Ama__IOSCrashReport__Crash__Thread__Registers__Register **)createRegistersArrayWithObject:(NSArray<AMARegister *> *)array
                                                                           allocationTracker:(id<AMAAllocationsTracking>)tracker
                                                                               registerCount:(size_t *)count
                                                                                   validator:(AMADecodedCrashValidator *)validator
{
    Ama__IOSCrashReport__Crash__Thread__Registers__Register **registers =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Thread__Registers__Register *) * array.count];

    size_t serializedCount = 0;

    for (AMARegister *amaRegister in array) {
        if ([validator validateRegister:amaRegister] == NO) {
            Ama__IOSCrashReport__Crash__Thread__Registers__Register *pbRegister =
                [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Thread__Registers__Register)];
            ama__ioscrash_report__crash__thread__registers__register__init(pbRegister);

            [AMAProtobufUtilities fillBinaryData:&pbRegister->name withString:amaRegister.name tracker:tracker];
            pbRegister->value = amaRegister.value;

            registers[serializedCount] = pbRegister;

            serializedCount++;
        }
    }

    if (count != NULL) {
        *count = serializedCount;
    }

    return registers;
}

- (Ama__IOSCrashReport__Crash__Thread__Stack *)createStackWithObject:(AMAStack *)amaStack
                                                   allocationTracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__IOSCrashReport__Crash__Thread__Stack *stack =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Crash__Thread__Stack)];
    ama__ioscrash_report__crash__thread__stack__init(stack);

    stack->grow_direction = [self growDireсtionToProtobuf:amaStack.growDirection];
    stack->dump_start = amaStack.dumpStart;
    stack->dump_end = amaStack.dumpEnd;
    stack->stack_pointer = amaStack.stackPointer;
    stack->overflow = amaStack.overflow;
    stack->has_contents = amaStack.contents != nil;
    if (stack->has_contents) {
        [AMAProtobufUtilities fillBinaryData:&stack->contents withData:amaStack.contents tracker:tracker];
    }

    return stack;
}

- (Ama__IOSCrashReport__Info__VirtualMachineInfo *)createVirtualMachineInfoWithObject:(AMAVirtualMachineInfo *)input
                                                                              tracker:(id<AMAAllocationsTracking>)tracker
{
    if (input == nil) {
        return NULL;
    }
    Ama__IOSCrashReport__Info__VirtualMachineInfo *virtualMachineInfo =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__Info__VirtualMachineInfo)];
    ama__ioscrash_report__info__virtual_machine_info__init(virtualMachineInfo);
    virtualMachineInfo->has_virtual_machine = [AMAProtobufUtilities fillBinaryData:&virtualMachineInfo->virtual_machine
                                                                        withString:input.platform
                                                                           tracker:tracker];
    virtualMachineInfo->has_virtual_machine_version =
        [AMAProtobufUtilities fillBinaryData:&virtualMachineInfo->virtual_machine_version
                                  withString:input.virtualMachineVersion
                                     tracker:tracker];
    virtualMachineInfo->n_plugin_environment = input.environment.count;
    Ama__IOSCrashReport__BytesPair **bytesPairs =
        [tracker allocateSize:sizeof(Ama__IOSCrashReport__BytesPair *) * input.environment.count];
    uint __block serializedCount = 0;
    [input.environment enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        Ama__IOSCrashReport__BytesPair *pair = [tracker allocateSize:sizeof(Ama__IOSCrashReport__BytesPair)];
        ama__ioscrash_report__bytes_pair__init(pair);

        pair->has_key = [AMAProtobufUtilities fillBinaryData:&pair->key
                                                  withString:key
                                                     tracker:tracker];
        pair->has_value = [AMAProtobufUtilities fillBinaryData:&pair->value
                                                    withString:obj
                                                       tracker:tracker];
        bytesPairs[serializedCount] = pair;
        serializedCount++;
    }];
    virtualMachineInfo->plugin_environment = bytesPairs;
    return virtualMachineInfo;
}


#pragma mark - Help functions

- (Ama__IOSCrashReport__System__BuildType)buildTypeToProtobuf:(AMABuildType)buildType
{
    switch (buildType) {
        case AMABuildTypeSimulator:
            return AMA__IOSCRASH_REPORT__SYSTEM__BUILD_TYPE__SIMULATOR;
        case AMABuildTypeDebug:
            return AMA__IOSCRASH_REPORT__SYSTEM__BUILD_TYPE__DEBUG;
        case AMABuildTypeTest:
            return AMA__IOSCRASH_REPORT__SYSTEM__BUILD_TYPE__TEST;
        case AMABuildTypeAppStore:
            return AMA__IOSCRASH_REPORT__SYSTEM__BUILD_TYPE__APP_STORE;
        case AMABuildTypeUnknown:
        default:
            return AMA__IOSCRASH_REPORT__SYSTEM__BUILD_TYPE__UNKNOWN;
    }
}

- (Ama__IOSCrashReport__Crash__Error__CrashType)crashTypeToProtobuf:(AMACrashType)crashType
{
    switch (crashType) {
        case AMACrashTypeMachException:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__MACH_EXCEPTION;
        case AMACrashTypeSignal:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__SIGNAL;
        case AMACrashTypeCppException:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__CPP_EXCEPTION;
        case AMACrashTypeNsException:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__NSEXCEPTION;
        case AMACrashTypeMainThreadDeadlock:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__MAIN_THREAD_DEADLOCK;
        case AMACrashTypeUserReported:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__USER_REPORTED;
        case AMACrashTypeVirtualMachineCrash:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__VIRTUAL_MACHINE_CRASH;
        case AMACrashTypeVirtualMachineError:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__VIRTUAL_MACHINE_ERROR;
        case AMACrashTypeVirtualMachineCustomError:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__VIRTUAL_MACHINE_CUSTOM_ERROR;
        case AMACrashTypeNonFatal:
        default:
            return AMA__IOSCRASH_REPORT__CRASH__ERROR__CRASH_TYPE__NON_FATAL;
    }
}

- (Ama__IOSCrashReport__Crash__Thread__Stack__GrowDirection)growDireсtionToProtobuf:(AMAGrowDirection)growDirection
{
    switch (growDirection) {
        case AMAGrowDirectionMinus:
            return AMA__IOSCRASH_REPORT__CRASH__THREAD__STACK__GROW_DIRECTION__MINUS;
        case AMAGrowDirectionPlus:
        default:
            return AMA__IOSCRASH_REPORT__CRASH__THREAD__STACK__GROW_DIRECTION__PLUS;
    }
}

@end
