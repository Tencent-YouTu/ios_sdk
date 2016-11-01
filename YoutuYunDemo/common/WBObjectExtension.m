//
//  WBObjectExtension.m
//  WeBank
//
//  Created by doufeifei on 14/11/4.
//
//

#import "WBObjectExtension.h"

#import "zlib.h"

#define kMemoryChunkSize 1024

@implementation NSString (KFExtension)

- (NSString*)trim {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString*)decodeUnicode {
    NSString* result = [[NSPropertyListSerialization propertyListFromData:[[[@"\"" stringByAppendingString:[[self stringByReplacingOccurrencesOfString:@"\\u" withString:@"\\U"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]] stringByAppendingString:@"\""] dataUsingEncoding:NSUTF8StringEncoding] mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL] stringByReplacingOccurrencesOfString:@"\\r\\n" withString:@"\n"]; // need autorelease ?
    return result;
}

- (NSData*)compressGZip {
    const char *str = [self UTF8String];
    NSData *data = [NSData dataWithBytes:str length:strlen(str)];
    
    NSUInteger length = [data length];
    int windowBits = 15 + 16, //Default + gzip header instead of zlib header
    memLevel = 8, //Default
    retCode;
    NSMutableData*  result;
    z_stream        stream;
    unsigned char   output[kMemoryChunkSize];
    uInt            gotBack;
    
    if ((length == 0) || (length > UINT_MAX)) {//FIXME: Support 64 bit inputs
        return nil;
    }
    
    bzero(&stream, sizeof(z_stream));
    stream.avail_in = (uInt)length;
    stream.next_in = (unsigned char*)[data bytes];
    
    retCode = deflateInit2(&stream, Z_BEST_COMPRESSION, Z_DEFLATED, windowBits, memLevel, Z_DEFAULT_STRATEGY);
    if(retCode != Z_OK) {
        //	KFLog(@"KF Error: %s: deflateInit2() failed with error %i", __FUNCTION__, retCode);
        return nil;
    }
    
    result = [NSMutableData dataWithCapacity:(length / 4)];
    do {
        stream.avail_out = kMemoryChunkSize;
        stream.next_out = output;
        retCode = deflate(&stream, Z_FINISH);
        if((retCode != Z_OK) && (retCode != Z_STREAM_END)) {
            //		KFLog(@"KF Error: %s: deflate() failed with error %i", __FUNCTION__, retCode);
            deflateEnd(&stream);
            return nil;
        }
        gotBack = kMemoryChunkSize - stream.avail_out;
        if(gotBack > 0)
            [result appendBytes:output length:gotBack];
    }
    while (retCode == Z_OK);
    deflateEnd(&stream);
    
    return (retCode == Z_STREAM_END ? result : nil);
}

@end

@implementation NSData (KFExtension)

- (NSString*)decompressGZip {
    if ([self length] == 0) {
        return nil;
    }
    
    unsigned full_length = [self length];
    unsigned half_length = [self length]/2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength:full_length+half_length];
    BOOL done = NO;
    int status;
    z_stream strm;
    strm.next_in   = (Bytef *)[self bytes];
    strm.avail_in  = [self length];
    strm.total_out = 0;
    strm.zalloc    = Z_NULL;
    strm.zfree     = Z_NULL;
    if (inflateInit2(&strm, (15+32)) != Z_OK) {
        return nil;
    }
    
    while (!done) {
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
        }
        strm.next_out  = (Bytef*)[decompressed mutableBytes] + strm.total_out;
        strm.avail_out = [decompressed length] - strm.total_out;
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
            done = YES;
        }
        else if (status != Z_OK) {
            break;
        }
    }
    
    if (inflateEnd (&strm) != Z_OK || !done) {
        return nil;
    }
    
    [decompressed setLength: strm.total_out];
    
    return [[[NSString alloc] initWithBytes:decompressed.bytes length:decompressed.length encoding:NSUTF8StringEncoding] autorelease];
}

@end

@implementation NSDictionary (KFExtension)

- (NSDictionary*)dictionaryValueForKey:(NSString*)key defaultValue:(NSDictionary*)defaultValue {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null] && [ret isKindOfClass:[NSDictionary class]]) {
            return ret;
        }
    }
    return defaultValue;
}

- (NSArray*)arrayValueForKey:(NSString*)key defaultValue:(NSArray*)defaultValue {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null] && [ret isKindOfClass:[NSArray class]]) {
            return ret;
        }
    }
    return defaultValue;
}

- (NSString*)stringValueForKey:(NSString*)key defaultValue:(NSString*)defaultValue operation:(NSStringOperationType)type {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null]) {
            if ([ret isKindOfClass:[NSString class]]) {
                switch (type) {
                    case NSStringOperationTypeDecodeUnicode: {
                        return [[ret trim] decodeUnicode];
                    }
                    case NSStringOperationTypeNone: {
                        return ret;
                    }
                    case NSStringOperationTypeTrim:
                    default: {
                        return [ret trim];
                    }
                }
            }
            else if ([ret isKindOfClass:[NSDecimalNumber class]]) {
                return [NSString stringWithFormat:@"%@", ret];
            }
            else if ([ret isKindOfClass:[NSNumber class]]) {
                return [NSString stringWithFormat:@"%@", ret];
            }
        }
    }
    return defaultValue;
}

- (int)intValueForKey:(NSString*)key defaultValue:(int)defaultValue {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null] && ([ret isKindOfClass:[NSDecimalNumber class]] || [ret isKindOfClass:[NSNumber class]] || [ret isKindOfClass:[NSString class]])) {
            return [ret intValue];
        }
    }
    return defaultValue;
}

- (uint64_t)longLongValueForKey:(NSString*)key defaultValue:(uint64_t)defaultValue {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null] && ([ret isKindOfClass:[NSDecimalNumber class]] || [ret isKindOfClass:[NSNumber class]] || [ret isKindOfClass:[NSString class]])) {
            return [ret longLongValue];
        }
    }
    return defaultValue;
}

- (double)doubleValueForKey:(NSString*)key defaultValue:(double)defaultValue {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null] && ([ret isKindOfClass:[NSDecimalNumber class]] || [ret isKindOfClass:[NSNumber class]] || [ret isKindOfClass:[NSString class]])) {
            return [ret doubleValue];
        }
    }
    return defaultValue;
}

- (float)floatValueForKey:(NSString*)key defaultValue:(float)defaultValue {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null] && ([ret isKindOfClass:[NSDecimalNumber class]] || [ret isKindOfClass:[NSNumber class]] || [ret isKindOfClass:[NSString class]])) {
            return [ret floatValue];
        }
    }
    return defaultValue;
}

- (BOOL)boolValueForKey:(NSString*)key defaultValue:(BOOL)defaultValue {
    if (key != nil && [key length] > 0) {
        id ret = [self objectForKey:key];
        if (ret != nil && ret != [NSNull null]) {
            return [ret boolValue];
        }
    }
    return defaultValue;
}

@end
