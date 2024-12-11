#if __has_include(<KSCrash/KSCrash-umbrella.h>)
// CocoaPods with modular headers
    @import KSCrash;
#elif __has_include(<KSCrash/KSCrash.h>)
// CocoaPods without modular headers
    #import <KSCrash/KSCrash.h>
    #import <KSCrash/KSCrashReportFields.h>
    #import <KSCrash/KSCrashConfiguration.h>
    #import <KSCrash/KSCrashReport.h>
    #import <KSCrash/KSDynamicLinker.h>
    #import <KSCrash/KSSymbolicator.h>
#else
// SPM imports
    @import KSCrashRecording;
    @import KSCrashRecordingCore;
#endif
