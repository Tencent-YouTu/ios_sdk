//
//  YTServerAPI.h
//  MeetingCheck
//
//  Created by Patrick Yang on 15/7/14.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import "ServerAPI.h"
#import <UIKit/UIKit.h>

@interface YTServerAPI : ServerAPI

+ (YTServerAPI *)instance;
- (void)idcardOCR:(UIImage *)image withCardType:(NSInteger)type callback:(void (^)(NSInteger error, NSDictionary* dic))callback;
- (void)getLivefour:(void (^)(NSInteger error, NSString* number))callback;
- (void)idcardLivedetectFour:(NSData *)video withCardId:(NSString*)cardId withCardName:(NSString*)name withValidateId:(NSString*)validate callback:(void (^)(NSInteger error, NSInteger liveStatus, NSInteger compareStatus, NSInteger sim))callback;


@end
