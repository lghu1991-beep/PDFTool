#import "QYPTAuthHelper.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const kQYPTPasswordSHA256 =
    @"a3dbd9941a7e6f31eecbdcf93ee8e822a1c3228f75fe3596ec2cd0de690d27d1";

@implementation QYPTAuthHelper

+ (BOOL)verifyPassword:(NSString *)password {
    return [[self sha256HexOfString:password] isEqualToString:kQYPTPasswordSHA256];
}

+ (NSString *)sha256HexOfString:(NSString *)text {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

@end
