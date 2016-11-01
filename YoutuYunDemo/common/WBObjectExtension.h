//
//  MSDKObjectExtension.h
//  WGFrameworkDemo
//
//  Created by fred on 13-8-26.
//  Copyright (c) 2013年 tencent.com. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    NSStringOperationTypeTrim,          // 去空
    NSStringOperationTypeDecodeUnicode, // 解汉字
    NSStringOperationTypeNone,          // 无需额外操作
} NSStringOperationType;

// Extension of NSString
@interface NSString (KFExtension)

// 去除尾部space, /n, /t
- (NSString*)trim;

// 解出汉字
- (NSString*)decodeUnicode;

// 压缩生成 NSData
- (NSData*)compressGZip;

@end

@interface NSData (KFExtension)

// 解压缩
- (NSString*)decompressGZip;

@end

// Extension of NSDictionary
@interface NSDictionary (KFExtension)

// 从 NSDictionary 中获取 key 对应的 字典型value; 若无，则返回 defaultValue
- (NSDictionary*)dictionaryValueForKey:(NSString*)key defaultValue:(NSDictionary*)defaultValue;

// 从 NSDictionary 中获取 key 对应的 数组型value; 若无，则返回 defaultValue
- (NSArray*)arrayValueForKey:(NSString*)key defaultValue:(NSArray*)defaultValue;

// 从 NSDictionary 中获取 key 对应的 NSString型value, 并进行特殊处理; 若无，则返回 defaultValue
- (NSString*)stringValueForKey:(NSString*)key defaultValue:(NSString*)defaultValue operation:(NSStringOperationType)type;

// 从 NSDictionary 中获取 key 对应的 int 型value; 若无，则返回 defaultValue
- (int)intValueForKey:(NSString*)key defaultValue:(int)defaultValue;

// 从 NSDictionary 中获取 key 对应的 uint64_t 型value; 若无，则返回 defaultValue
- (uint64_t)longLongValueForKey:(NSString*)key defaultValue:(uint64_t)defaultValue;

// 从 NSDictionary 中获取 key 对应的 double 型value; 若无，则返回 defaultValue
- (double)doubleValueForKey:(NSString*)key defaultValue:(double)defaultValue;

// 从 NSDictionary 中获取 key 对应的 float 型value; 若无，则返回 defaultValue
- (float)floatValueForKey:(NSString*)key defaultValue:(float)defaultValue;

// 从 NSDictionary 中获取 key 对应的 bool 型value; 若无，则返回 defaultValue
- (BOOL)boolValueForKey:(NSString*)key defaultValue:(BOOL)defaultValue;

@end
