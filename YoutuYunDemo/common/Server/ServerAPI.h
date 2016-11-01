//
//  ServerAPI.h
//  MeetingCheck
//
//  Created by Patrick Yang on 15/7/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "YTEntity.h"

@interface HttpResult : NSObject

@property int httpCode;
@property int error;
@property NSDictionary *json;

@end

@interface ServerAPI : NSObject

@property (nonatomic, strong) NSString *HOST;

- (NSOperationQueue *)networkQueue;
- (void)setAPIKeyHeader:(NSMutableURLRequest *)request;
- (void)setAPIReqBody:(NSMutableURLRequest *)request withData:(id)data; // NSArray & NSDictionary
- (NSMutableURLRequest *)createHttpRequest:(NSString *)strurl andMethod:(NSString *)method;
- (NSMutableURLRequest *)createPostHttpRequest:(NSString *)strurl;
- (NSMutableURLRequest *)createGetHttpRequest:(NSString *)strurl;
- (void)sendRequest:(NSMutableURLRequest *)request withData:(id)data callback:(void (^)(HttpResult *))callback;
- (void)sendRequestForTimeout:(NSMutableURLRequest *)request withData:(id)data callback:(void (^)(HttpResult *))callback;

- (id)parseDictonary:(NSDictionary *)dict withEntity:(Class)clazz;
- (NSArray *)parseArray:(NSArray *)array withEntity:(Class)clazz;

////////////////////////////////////////////////////////////////////////////////////////////////
//Base CURL operation
- (void)createResource:(NSString *)url withEntity:(Class) clazz withData:(id)data  andCallback:(void (^)(NSInteger error, id  newResource)) callback;
- (void)putResource:(NSString *) url withEntity:(Class) clazz withData:(NSObject *)dict  andCallback:(void (^)(NSInteger error, id  newResource))callback;
- (void)deleteResourse:(NSString *) url andCallback:(void (^)(NSInteger error)) callback;
- (void)getResourse:(NSString *) url withEntity:(Class) clazz andCallback:(void (^)(NSInteger error, id resouse)) callback;
- (void)listResourse:(NSString *) url data:(NSDictionary *)data entity:(Class) clazz andCallback:(void (^)(NSInteger error, NSArray *resouses)) callback;

@end
