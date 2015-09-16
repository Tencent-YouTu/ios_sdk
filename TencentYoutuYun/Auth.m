//
//  Auth.m
//  YoutuYunDemo
//
//  Created by Patrick Yang on 15/9/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import "Auth.h"
#import "Conf.h"
#import "NSData+Base64.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

#define USER_ID_MAX_LEN        64
#define URL_MAX_LEN            1024
#define PLAIN_TEXT_MAX_LEN     4096
#define CIPER_TEXT_MAX_LEN     1024

@implementation Auth

+ (NSString *)appSign:(unsigned int)expired userId:(NSString *)userId
{
    if ([Conf instance].secretId.length <= 0 || [Conf instance].secretKey.length <= 0) {
        NSLog(@"ERROR: secretId & secretKey empty!");
        return nil;
    }
    if ([Conf instance].userId.length > USER_ID_MAX_LEN) {
        NSLog(@"ERROR: userId exceed the length limitation!");
        return nil;
    }
    unsigned int now = (int)[[NSDate date] timeIntervalSince1970];
    unsigned int rdm = (int)random() % 1000000000;
    NSString *origin = [NSString stringWithFormat:@"a=%@&k=%@&e=%u&t=%u&r=%d&u=%zd&f=%@", [Conf instance].appId, [Conf instance].secretId, expired + now, now, rdm, [[Conf instance].userId integerValue], @""];
    NSData *data = [self hmacsha1:origin secret:[Conf instance].secretKey];
    NSLog(@"s: %@", [data base64String]);
    NSMutableData *all = [NSMutableData dataWithData:data];
    [all appendBytes:origin.UTF8String length:origin.length];
    NSString *base64 = [all base64String];
    return base64;
}

+ (NSData *)hmacsha1:(NSString *)data secret:(NSString *)key
{
    const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];
    
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
    return HMAC;
}

@end
