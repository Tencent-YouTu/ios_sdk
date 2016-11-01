//
//  ServerAPI.m
//  MeetingCheck
//
//  Created by Patrick Yang on 15/7/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import "ServerAPI.h"
//#import "LogUtil.h"
//#import "GTMNSString+HTML.h"

@implementation HttpResult

@end



@interface ServerAPI ()
{
    NSMutableDictionary *errorCodeMap;
    NSOperationQueue *_networkQueue;
}

@end

@implementation ServerAPI

- (id)init
{
    self = [super init];
    if (self) {
        _networkQueue = [[NSOperationQueue alloc] init];
        _networkQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

- (NSOperationQueue *)networkQueue
{
    return _networkQueue;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
//        aStr = [[aStr gtm_stringByUnescapingFromHTML] gtm_stringByUnescapingFromHTML];
        NSLog(@"httpcode=%d, resp:%@", status, aStr);

        NSData *nsData = [aStr dataUsingEncoding:NSUTF8StringEncoding];
        NSError * err;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:nsData options:kNilOptions error:&err];

        result.json = json;

        if([json objectForKey:@"code"] != nil) {
            result.error = [[json objectForKey:@"code"] intValue];
        }
    }

    return result;
}

- (HttpResult *)parseResponseForTimeout:(NSURLResponse * )resp andData:(NSData *) data andError:(NSError*) error
{
    HttpResult * result = [[HttpResult alloc] init];
    NSHTTPURLResponse * httpResp = (NSHTTPURLResponse*) resp;
    int status = (int)httpResp.statusCode;
    result.httpCode = status;
    
    if(status == 200 || status == 201 || status == 204) {
        result.error = 0;
    }else {
        if (error.code == -1001) {
            result.error = -10;
        }else{
            result.error = -1;
        }
    }
    
    if(data != nil) {
        NSString* aStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        //        aStr = [[aStr gtm_stringByUnescapingFromHTML] gtm_stringByUnescapingFromHTML];
        NSLog(@"httpcode=%d, resp:%@", status, aStr);
        
        NSData *nsData = [aStr dataUsingEncoding:NSUTF8StringEncoding];
        NSError * err;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:nsData options:kNilOptions error:&err];
        
        result.json = json;
        
        if([json objectForKey:@"code"] != nil) {
            result.error = [[json objectForKey:@"code"] intValue];
        }
    }
    
    return result;
}

- (void)setAPIKeyHeader:(NSMutableURLRequest *)request
{
}
- (void)setAPIReqBody:(NSMutableURLRequest *)request withData:(id)data
{
    if(data != nil) {
        if([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            NSString *postContent = [self dictionary2String:dict];
            NSData *postData = [postContent dataUsingEncoding:NSUTF8StringEncoding];
            NSLog(@"postContent:%@", postContent);
            [request setHTTPBody:postData];
        } else if([data isKindOfClass:[NSString class]]) {
            NSString *array = (NSString *)data;
            NSData *postData = [array dataUsingEncoding:NSUTF8StringEncoding];
            [request setHTTPBody:postData];
        } else if ([data isKindOfClass:[NSData class]]) {
            [request setHTTPBody:data];
        }
    }
}
- (NSMutableURLRequest *)createHttpRequest:(NSString *)strurl andMethod:(NSString *)method
{
    NSURL * url = [NSURL URLWithString:[strurl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:30];
    [request setHTTPMethod:method];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    return request;
}

- (NSMutableURLRequest *)createPostHttpRequest:(NSString *)strurl
{
    NSString *url = [NSString stringWithFormat:@"%@%@", self.HOST, strurl];
    NSLog(@"Create Http request for : %@", url);
    NSMutableURLRequest *request = [self createHttpRequest:url andMethod:@"POST"];
    [self setAPIKeyHeader:request];

    return request;
}

- (NSMutableURLRequest *)createGetHttpRequest:(NSString *)strurl
{
    NSString * url = [NSString stringWithFormat:@"%@%@", self.HOST, strurl];
    NSMutableURLRequest *request = [self createHttpRequest:url andMethod:@"GET"];
    [self setAPIKeyHeader:request];
    return request;
}
- (void)sendRequest:(NSMutableURLRequest *)request withData:(id)data callback:(void (^)(HttpResult *result))callback
{
    [self setAPIReqBody:request withData:data];
    [NSURLConnection sendAsynchronousRequest:request queue:[self networkQueue] completionHandler:^(NSURLResponse * resp, NSData * data, NSError * error) {
        if(callback == nil) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            HttpResult *result = [self parseResponse:resp andData:data];
            callback(result);
        });
    }];
}

- (void)sendRequestForTimeout:(NSMutableURLRequest *)request withData:(id)data callback:(void (^)(HttpResult *result))callback
{
    [self setAPIReqBody:request withData:data];
    [NSURLConnection sendAsynchronousRequest:request queue:[self networkQueue] completionHandler:^(NSURLResponse * resp, NSData * data, NSError * error) {
        if(callback == nil) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            HttpResult *result = [self parseResponseForTimeout:resp andData:data andError:error];
            callback(result);
        });
    }];
}

//- (id)parseDictonary:(NSDictionary *)dict withEntity:(Class)clazz
//{
//    id obj = dict;
//    if(dict && clazz != nil){
//        YTEntity *entity = [clazz new];
//        obj = [entity parse:dict];
//    }
//    return obj;
//}
//- (NSArray *)parseArray:(NSArray *)array withEntity:(Class)clazz
//{
//    NSMutableArray *resources = [NSMutableArray array];
//    if (array) {
//        YTEntity *entity = [clazz new];
//        for(int i=0; i<array.count; i++) {
//            NSDictionary *data = [array objectAtIndex:i];
//            NSLog(@"%@", data);
//            id  resouse = [entity parse:data];
//            [resources addObject:resouse];
//        }
//    }
//    return resources;
//}

////////////////////////////////////////////////////////////////////////////////////////////////
//Base CURL operation
- (void)createResource:(NSString *) url withEntity:(Class) clazz withData:(id)data  andCallback:(void (^)(NSInteger error, id  newResource)) callback
{
    NSMutableURLRequest *request = [self createPostHttpRequest:url];
    NSLog(@"createResource:%@", request.URL);
    
    [self sendRequest:request withData:data callback:^(HttpResult *result) {
        id obj = [self parseDictonary:result.json[@"object"] withEntity:clazz] ;
        callback(result.error, obj);
    }];
}

- (void)putResource:(NSString *) url withEntity:(Class) clazz withData:(NSObject *)dict  andCallback:(void (^)(NSInteger error, id  newResource)) callback
{
    NSString * strurl = [NSString stringWithFormat:@"%@%@", self.HOST, url];
    NSURL * nsurl = [NSURL URLWithString:[strurl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsurl];
    [request setTimeoutInterval:30];
    [request setHTTPMethod:@"PUT"];
    [self setAPIKeyHeader:request];
    
    NSLog(@"putResource:%@", request.URL);
    [self sendRequest:request withData:dict callback:^(HttpResult *result) {
        id obj = [self parseDictonary:result.json[@"object"] withEntity:clazz];
        callback(result.error, obj);
    }];
    
    [self setAPIReqBody:request withData:dict];
}



- (void)deleteResourse:(NSString *)url andCallback:(void (^)(NSInteger error)) callback
{
    NSMutableURLRequest *request = [self createHttpRequest:url andMethod:@"DELETE"];
    
    NSLog(@"deleteResourse:%@", request.URL);
    [self sendRequest:request withData:nil callback:^(HttpResult *result) {
        callback(result.error);
    }];
}

- (void)getResourse:(NSString *)url withEntity:(Class)clazz andCallback:(void (^)(NSInteger error, id resouse)) callback
{
    NSMutableURLRequest *request = [self createGetHttpRequest:url];
    NSLog(@"listResourse:%@", request.URL);
    
    [self sendRequest:request withData:nil callback:^(HttpResult *result) {
        id obj = [self parseDictonary:result.json[@"object"] withEntity:clazz];
        callback(result.error, obj);
    }];
}

-(void)listResourse:(NSString *) url data:(NSDictionary *)data entity:(Class) clazz andCallback:(void (^)(NSInteger error, NSArray *resouses)) callback
{
    NSMutableURLRequest *request = data ? [self createPostHttpRequest:url] : [self createGetHttpRequest:url];
    NSLog(@"listResourse:%@", request.URL);
    [self sendRequest:request withData:data callback:^(HttpResult *result) {
        NSArray *array = [self parseArray:(NSArray *)result.json[@"object"] withEntity:clazz];
        callback(result.error, array);
    }];
}

#pragma mark - Internal
-(NSString *) code2Msg:(int) errorCode;
{
    if(errorCodeMap == nil)
    {
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"errorcode" ofType:@"plist"];
        errorCodeMap = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    }
    
    NSString * key = [NSString stringWithFormat:@"%d", errorCode];
    return [errorCodeMap objectForKey:key];
}
- (NSString *)dictionary2String:(NSDictionary *) dict
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *json =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return json;
}

@end
