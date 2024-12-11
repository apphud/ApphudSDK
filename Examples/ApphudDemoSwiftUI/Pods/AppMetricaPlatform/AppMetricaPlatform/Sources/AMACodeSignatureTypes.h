
#ifndef AMACodeSignatureTypes_h
#define AMACodeSignatureTypes_h

/*
 * Magic numbers used by Code Signing
 */
enum {
    CSMAGIC_REQUIREMENT = 0xfade0c00,               /* single Requirement blob */
    CSMAGIC_REQUIREMENTS = 0xfade0c01,              /* Requirements vector (internal requirements) */
    CSMAGIC_CODEDIRECTORY = 0xfade0c02,             /* CodeDirectory blob */
    CSMAGIC_EMBEDDED_SIGNATURE = 0xfade0cc0, /* embedded form of signature data */
    CSMAGIC_EMBEDDED_SIGNATURE_OLD = 0xfade0b02,    /* XXX */
    CSMAGIC_EMBEDDED_ENTITLEMENTS = 0xfade7171,     /* embedded entitlements */
    CSMAGIC_DETACHED_SIGNATURE = 0xfade0cc1, /* multi-arch collection of embedded signatures */
    CSMAGIC_BLOBWRAPPER = 0xfade0b01,       /* CMS Signature, among other things */

    CS_SUPPORTSSCATTER = 0x20100,
    CS_SUPPORTSTEAMID = 0x20200,
    CS_SUPPORTSCODELIMIT64 = 0x20300,
    CS_SUPPORTSEXECSEG = 0x20400,

    CSSLOT_CODEDIRECTORY = 0,                               /* slot index for CodeDirectory */
    CSSLOT_INFOSLOT = 1,
    CSSLOT_REQUIREMENTS = 2,
    CSSLOT_RESOURCEDIR = 3,
    CSSLOT_APPLICATION = 4,
    CSSLOT_ENTITLEMENTS = 5,

    CSSLOT_ALTERNATE_CODEDIRECTORIES = 0x1000, /* first alternate CodeDirectory, if any */
    CSSLOT_ALTERNATE_CODEDIRECTORY_MAX = 5,         /* max number of alternate CD slots */
    CSSLOT_ALTERNATE_CODEDIRECTORY_LIMIT = CSSLOT_ALTERNATE_CODEDIRECTORIES + CSSLOT_ALTERNATE_CODEDIRECTORY_MAX, /* one past the last */

    CSSLOT_SIGNATURESLOT = 0x10000,                 /* CMS Signature */
    CSSLOT_IDENTIFICATIONSLOT = 0x10001,
    CSSLOT_TICKETSLOT = 0x10002,

    CSTYPE_INDEX_REQUIREMENTS = 0x00000002,         /* compat with amfi */
    CSTYPE_INDEX_ENTITLEMENTS = 0x00000005,         /* compat with amfi */

    CS_HASHTYPE_SHA1 = 1,
    CS_HASHTYPE_SHA256 = 2,
    CS_HASHTYPE_SHA256_TRUNCATED = 3,
    CS_HASHTYPE_SHA384 = 4,

    CS_SHA1_LEN = 20,
    CS_SHA256_LEN = 32,
    CS_SHA256_TRUNCATED_LEN = 20,

    CS_CDHASH_LEN = 20,                                             /* always - larger hashes are truncated */
    CS_HASH_MAX_SIZE = 48, /* max size of the hash we'll support */

/*
 * Currently only to support Legacy VPN plugins,
 * but intended to replace all the various platform code, dev code etc. bits.
 */
    CS_SIGNER_TYPE_UNKNOWN = 0,
    CS_SIGNER_TYPE_LEGACYVPN = 5,
};

/*
 * Structure of an embedded-signature SuperBlob
 */

typedef struct __BlobIndex {
    uint32_t type;                                  /* type of entry */
    uint32_t offset;                                /* offset of entry */
} CS_BlobIndex
__attribute__ ((aligned(1)));

typedef struct __SC_SuperBlob {
    uint32_t magic;                                 /* magic number */
    uint32_t length;                                /* total length of SuperBlob */
    uint32_t count;                                 /* number of index entries following */
    CS_BlobIndex index[];                   /* (count) entries */
    /* followed by Blobs in no particular order as indicated by offsets in index */
} CS_SuperBlob
__attribute__ ((aligned(1)));

typedef struct __SC_GenericBlob {
    uint32_t magic;                                 /* magic number */
    uint32_t length;                                /* total length of blob */
    char data[];
} CS_GenericBlob
__attribute__ ((aligned(1)));

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else /* __LP64__ */
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif /* __LP64__ */

#endif /* AMACodeSignatureTypes_h */
