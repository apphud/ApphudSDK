
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import "AMAEntitlementsExtractor.h"
#import "AMACodeSignatureTypes.h"

@implementation AMAEntitlementsExtractor

#pragma mark - Public -

+ (NSDictionary *)entitlements
{
    const mach_header_t *header = [self machHeader];
    if (header == NULL) {
        return nil;
    }
    
    const struct linkedit_data_command *codeSignCmd;
    const segment_command_t *linkeditSegCmd;
    NSData *linkeditData = [self commandsForHeader:header codeSignature:&codeSignCmd linkedit:&linkeditSegCmd];
    if (linkeditData == nil || codeSignCmd == NULL || linkeditSegCmd == NULL) {
        return nil;
    }
    
    NSData *entitlementsData = [self entitlementDataForSignature:codeSignCmd
                                                    linkeditData:linkeditData
                                                 linkeditCommand:linkeditSegCmd];
    if (entitlementsData == nil) {
        return nil;
    }
    
    NSError *error = nil;
    NSDictionary *entitlements = [NSPropertyListSerialization propertyListWithData:entitlementsData
                                                                           options:NSPropertyListImmutable
                                                                            format:NULL
                                                                             error:&error];
    if (error == nil) {
        return entitlements;
    }
    return nil;
}

#pragma mark - Private -

+ (const mach_header_t *)machHeader
{
    uint32_t buffSize = 0;
    _NSGetExecutablePath(NULL, &buffSize);
    NSMutableData *name = [NSMutableData dataWithCapacity:buffSize];
    
    if (_NSGetExecutablePath(name.mutableBytes, &buffSize) != 0) {
        return NULL;
    }
    
    uint32_t count = _dyld_image_count();
    const char *currName = NULL;
    const mach_header_t *header = NULL;
    for (uint32_t i = 0; i < count; i++) {
        currName = _dyld_get_image_name(i);
        if (currName != NULL && strcmp(currName, name.bytes) == 0) {
            header = (mach_header_t *)_dyld_get_image_header(i);
            break;
        }
    }
    return header;
}

+ (NSData *)commandsForHeader:(const mach_header_t *)header
                codeSignature:(const struct linkedit_data_command **)codeSignCmd
                     linkedit:(const segment_command_t **)linkeditSegCmd
{
    uint8_t *loadCommandPointer = (uint8_t *)header;
    struct load_command *cmd = NULL;
    size_t offset = sizeof(mach_header_t);
    uint32_t commandsCount = header->ncmds;
    
    const struct linkedit_data_command *localCodeSignCmd = NULL;
    const segment_command_t *localLinkeditSegCmd = NULL;
    
    while (commandsCount-- && (localCodeSignCmd == NULL || localLinkeditSegCmd == NULL)) {
        loadCommandPointer += offset;
        cmd = (struct load_command *)loadCommandPointer;
        offset = cmd->cmdsize;
        
        switch (cmd->cmd) {
            case LC_CODE_SIGNATURE:
                localCodeSignCmd = (struct linkedit_data_command *)cmd;
                break;
            case LC_SEGMENT_ARCH_DEPENDENT:
                if (strcmp(((segment_command_t *)cmd)->segname, SEG_LINKEDIT) == 0) {
                    localLinkeditSegCmd = (segment_command_t *)cmd;
                }
                break;
            default:
                break;
        }
    }
    
    if (codeSignCmd != NULL) {
        *codeSignCmd = localCodeSignCmd;
    }
    if (linkeditSegCmd != NULL) {
        *linkeditSegCmd = localLinkeditSegCmd;
    }
    
    return [self linkeditDataForHeader:header];
}

+ (NSData *)linkeditDataForHeader:(const mach_header_t *)header
{
    unsigned long size = 0;
    uint8_t *rawSegData = getsegmentdata(header, SEG_LINKEDIT, &size);
    if (size > 0 && rawSegData != NULL) {
        return [NSData dataWithBytesNoCopy:rawSegData length:size freeWhenDone:NO];
    }
    return nil;
}

+ (NSData *)entitlementDataForSignature:(const struct linkedit_data_command *)codeSignCmd
                           linkeditData:(NSData *)linkeditData
                        linkeditCommand:(const segment_command_t *)linkeditSegCmd
{
    NSUInteger vmOffset = codeSignCmd->dataoff - linkeditSegCmd->fileoff;
    
    if (vmOffset + codeSignCmd->datasize > linkeditSegCmd->filesize) {
        return nil;
    }
    
    NSData *blobData = [linkeditData subdataWithRange:NSMakeRange(vmOffset, codeSignCmd->datasize)];
    CS_SuperBlob *blob = (CS_SuperBlob *)blobData.bytes;
    CS_GenericBlob *entitlementsBlob = NULL;
    
    if (CFSwapInt32BigToHost(blob->magic) == CSMAGIC_EMBEDDED_SIGNATURE) {
        for (uint32_t i = 0; i < CFSwapInt32BigToHost(blob->count); i++) {
            if (CFSwapInt32BigToHost(blob->index[i].type) == CSSLOT_ENTITLEMENTS) {
                uint32_t blobOffset = CFSwapInt32BigToHost(blob->index[i].offset);
                CS_GenericBlob *tempBlob = (CS_GenericBlob *)((uint8_t *)blobData.bytes + blobOffset);
                if (CFSwapInt32BigToHost(tempBlob->magic) == CSMAGIC_EMBEDDED_ENTITLEMENTS) {
                    entitlementsBlob = tempBlob;
                    break;
                }
            }
        }
    }
    
    if (entitlementsBlob != NULL) {
        return [NSData dataWithBytesNoCopy:entitlementsBlob->data
                                    length:CFSwapInt32BigToHost(entitlementsBlob->length)
                              freeWhenDone:NO];
    }
    return nil;
}

@end
