//
//  Conf.h
//  YoutuYunDemo
//
//  Created by Patrick Yang on 15/9/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Conf : NSObject

@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *secretId;
@property (nonatomic, copy) NSString *secretKey;
@property (nonatomic, copy) NSString *userId;

+ (Conf *)instance;

@end
