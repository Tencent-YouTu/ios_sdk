         //
//  YTServerAPI.m
//  MeetingCheck
//
//  Created by Patrick Yang on 15/7/14.
//  Copyright (c) 2015年 Tencent. All rights reserved.


//人脸核身相关接口调用
//

#import "YTServerAPI.h"
#import "NSData+Base64.h"
#import "Auth.h"
#import "GTMNSString+HTML.h"
#import "Conf.h"

//#define AppID       @"10008768"
//#define SecretID    @"AKIDN8lBPUYSHuNdkCAjhVhnhQwISHyumQvd"
//#define SecretKey   @"jV6rTt782nU4hgaN3bkkXBbzGNI1a0oS"

//#define HOST_KEY @"Host"
//#define HOST_VALUE @"api.youtu.qq.com"
//#define AUTORIZATION_KEY @"Authorization"

NSString *AppID;

@implementation YTServerAPI

+ (YTServerAPI *)instance
{
    static YTServerAPI *api = nil;
    if (api == nil) {
        api = [[YTServerAPI alloc] init];
        api.HOST = @"https://vip-api.youtu.qq.com";
        AppID = [Conf instance].appId;
    }
    return api;
}

- (void)setAPIKeyHeader:(NSMutableURLRequest *)request
{
//    YTSignature *signature = [[YTSignature alloc] init];
//    signature.appId = (int)[AppID integerValue];
//    signature.secretId = SecretID;
//    signature.secretKey = SecretKey;
//    signature.expired = 1000000.0;
//    signature.userId = nil;
    NSString *auth = [Auth appSign:1000000 userId:nil];;
    [request setValue:auth forHTTPHeaderField:@"Authorization"];
}

////////////////////////////////////////////////////////////////////////////////////////
- (void)idcardOCR:(UIImage *)image withCardType:(NSInteger)type callback:(void (^)(NSInteger error, NSDictionary* dic))callback
{
    NSData *data = UIImageJPEGRepresentation(image, 0.45);
    NSDictionary *dict = @{@"app_id":AppID, @"image":[data base64String], @"card_type":@(type)};
    NSMutableURLRequest *request = [self createPostHttpRequest:@"/youtu/ocrapi/idcardocr"];
    request.timeoutInterval = 10.0f;
    [self sendRequest:request withData:dict callback:^(HttpResult *result) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:10];
        if (result.error == 0) {
            NSString* name = [result.json valueForKey:@"name"];
            NSString* idCardNo = [result.json valueForKey:@"id"];
            
            [dic setValue:name forKey:@"name"];
            [dic setValue:idCardNo forKey:@"id"];
            
        }
        callback(result.error, dic);
    }];
}


- (void)getLivefour:(void (^)(NSInteger error, NSString* number))callback {
    NSDictionary *dict = @{@"app_id":AppID};
    NSMutableURLRequest *request = [self createPostHttpRequest:@"/youtu/openliveapi/livegetfour"];
    request.timeoutInterval = 10.0f;
    [self sendRequest:request withData:dict callback:^(HttpResult *result) {
        NSString *number = @"";
        if (result.error == 0) {
            number = [result.json valueForKey:@"validate_data"];
            
        }
        callback(result.error, number);
    }];
    
}

- (void)idcardLivedetectFour:(NSData *)video withCardId:(NSString*)cardId withCardName:(NSString*)name withValidateId:(NSString*)validate callback:(void (^)(NSInteger error, NSInteger liveStatus, NSInteger compareStatus, NSInteger sim))callback{
    
    NSDictionary *dict = @{@"app_id":AppID, @"video":[video base64String], @"idcard_number":cardId, @"idcard_name":name, @"validate_data":validate};
    NSMutableURLRequest *request = [self createPostHttpRequest:@"/youtu/openliveapi/idcardlivedetectfour"];
    request.timeoutInterval = 20.0f;
    [self sendRequest:request withData:dict callback:^(HttpResult *result) {
        NSInteger liveStatus;
        NSInteger compareStatus;
        NSInteger sim;
        if (result.error == 0) {
            liveStatus = [[result.json valueForKey:@"live_status"] intValue];
            compareStatus = [[result.json valueForKey:@"compare_status"] intValue];
            sim = [[result.json valueForKey:@"sim"] intValue];
        }
        callback(result.error, liveStatus, compareStatus, sim);
    }];
    
}

////////////////////////////////////////////////////////////////////////////////////////
- (HttpResult *)parseResponse:(NSURLResponse * )resp andData:(NSData *) data
{
    HttpResult * result = [[HttpResult alloc] init];
    NSHTTPURLResponse * httpResp = (NSHTTPURLResponse*) resp;
    int status = (int)httpResp.statusCode;
    result.httpCode = status;
    
    if(status == 200 || status == 201 || status == 204) {
        result.error = 0;
    } else {
        result.error = -1;
    }
    
    if(data != nil) {
        NSString* aStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        aStr = [[aStr gtm_stringByUnescapingFromHTML] gtm_stringByUnescapingFromHTML];
        NSLog(@"httpcode=%d, resp:%@", status, aStr);
        
        NSData *nsData = [aStr dataUsingEncoding:NSUTF8StringEncoding];
        
        NSError *err = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:nsData options:kNilOptions error:&err];
        
        result.json = json;
        
        if([json objectForKey:@"errorcode"] != nil) {
            result.error = [[json objectForKey:@"errorcode"] intValue];
        }
    }
    
    return result;
}

@end
