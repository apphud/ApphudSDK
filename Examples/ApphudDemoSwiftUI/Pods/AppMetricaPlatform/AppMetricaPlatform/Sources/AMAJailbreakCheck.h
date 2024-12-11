//
//  SSJailbreakCheck.m
//  SystemServicesDemo
//
//  Created by Shmoopi LLC on 9/17/12.
//  Copyright (c) 2012 Shmoopi LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

/* Jailbreak Check Definitions */

#define NOTJAIL 4783242

// Failed jailbroken checks
enum {
    // Failed the Jailbreak Check
    AMA_KFJailbroken = 3429542,
    // Failed the OpenURL Check
    AMA_KFOpenURL = 321,
    // Failed the Cydia Check
    AMA_KFCydia = 432,
    // Failed the Inaccessible Files Check
    AMA_KFIFC = 47293,
    // Failed the plist check
    AMA_KFPlist = 9412,
    // Failed the Processes Check with Cydia
    AMA_KFProcessesCydia = 10012,
    // Failed the Processes Check with other Cydia
    AMA_KFProcessesOtherCydia = 42932,
    // Failed the Processes Check with other other Cydia
    AMA_KFProcessesOtherOCydia = 10013,
    // Failed the FSTab Check
    AMA_KFFSTab = 9620,
    // Failed the System() Check
    AMA_KFSystem = 47475,
    // Failed the Symbolic Link Check
    AMA_KFSymbolic = 34859,
    // Failed the File Exists Check
    AMA_KFFileExists = 6625,
};

@interface AMAJailbreakCheck : NSObject
// Jailbreak Check

// Jailbroken?
+ (int)jailbroken;

@end
