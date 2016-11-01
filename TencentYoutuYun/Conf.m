//
//  Conf.m
//  YoutuYunDemo
//
//  Created by Patrick Yang on 15/9/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import "Conf.h"

@implementation Conf

+ (Conf *)instance
{
    static Conf *singleton = nil;
    if (singleton) {
        return singleton;
    }
    singleton = [[Conf alloc] init];
    return singleton;
}

-(instancetype)init{
    self = [super init];
    _appId = @"123456";                                   // 替换APP_ID
    _secretId = @"aaaaa";    // 替换SECRET_ID
    _secretKey = @"bbbbb";       // 替换SECRET_KEY
    return self;
}

@end
