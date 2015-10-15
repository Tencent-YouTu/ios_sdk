//
//  TXQcloudFrSDK.m
//  SimpleURLConnections
//
//  Created by kenxjgao on 15/9/9.
//
//

#import <Foundation/Foundation.h>
#import "TXQcloudFrSDK.h" 
#import "NSData+Base64.h"

@implementation TXQcloudFrSDK
@synthesize API_END_POINT      = _API_END_POINT;
@synthesize appid      = _appid;
@synthesize authorization      = _authorization;


- (id)initWithName:(NSString *)appId authorization:(NSString *)_authCode{
    if(self = [super init]){
        self.API_END_POINT = @"https://youtu.api.qcloud.com/youtu";
        self.appid = appId;
        self.authorization = _authCode;
    }
    return self;
}

- (void)sendRequest:(NSMutableDictionary *) postData mothod:(NSString *) mothod successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSString *urlString = [self.API_END_POINT stringByAppendingString:mothod];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    
    NSString *contentType = @"text/json";
    [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
    [request addValue:self.authorization forHTTPHeaderField:@"Authorization"];
    
    [postData setValue:self.appid forKey:@"app_id"];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:postData options:NSJSONWritingPrettyPrinted error:nil];
    request.HTTPBody = data;
    
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    path = [path stringByAppendingPathComponent:@"body.dat"];
    [data writeToFile:path atomically:YES];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *dataResult, NSError *connectionError) {
        
        if (!connectionError) {
            if (successBlock) {
                NSString* str = [[NSString alloc] initWithData:dataResult encoding:NSUTF8StringEncoding];
                NSLog(@"response data: %@", str);
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:dataResult options:kNilOptions error:nil];
                successBlock(json);
            }
        } else {
            if (failureBlock) {
                failureBlock(connectionError);
            }
        }
    }];
}


- (void)detectFace:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
    }
    [self sendRequest:json mothod:@"/api/detectface" successBlock:successBlock failureBlock:failureBlock];
}


- (void)faceShape:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
    }
    [self sendRequest:json mothod:@"/api/faceshape" successBlock:successBlock failureBlock:failureBlock];
}

- (void)faceCompare:(id)imageA imageB:(id)imageB successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    if ([imageA isKindOfClass:[UIImage class]]) {
        json[@"imageA"] = [self imageBase64String:imageA];
    } else if ([imageA isKindOfClass:[NSString class]]) {
        json[@"urlA"] = imageA;
    }
    if ([imageB isKindOfClass:[UIImage class]]) {
        json[@"imageB"] = [self imageBase64String:imageB];
    } else if ([imageB isKindOfClass:[NSString class]]) {
        json[@"urlB"] = imageB;
    }
    [self sendRequest:json mothod:@"/api/facecompare" successBlock:successBlock failureBlock:failureBlock];
}

- (void)faceVerify:(id)image personId:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:personId forKey:@"person_id"];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
    }
    [self sendRequest:json mothod:@"/api/faceverify" successBlock:successBlock failureBlock:failureBlock];
}

- (void)faceIdentify:(id)image groupId:(NSString *)groupId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:groupId forKey:@"group_id"];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
    }
    [self sendRequest:json mothod:@"/api/faceidentify" successBlock:successBlock failureBlock:failureBlock];
}

- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *) groupIds personName:(NSString*) personName successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    [self newPerson:image personId:personId groupIds:groupIds personName:personName personTag:nil successBlock:successBlock failureBlock:failureBlock];
}

- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *) groupIds successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    [self newPerson:image personId:personId groupIds:groupIds personName:nil personTag:nil successBlock:successBlock failureBlock:failureBlock];
}

- (void)addFace:(NSString *)personId imageArray:(NSArray *)imageArray successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    if ([imageArray.firstObject isKindOfClass:[UIImage class]]) {
        NSMutableArray *images = [NSMutableArray arrayWithCapacity:10];
        for(UIImage *image in imageArray){
            [images addObject:[self imageBase64String:image]];
        }
        [json setValue:images forKey:@"images"];
    } else if ([imageArray.firstObject isKindOfClass:[NSString class]]) {
        NSMutableArray *urls = [NSMutableArray arrayWithCapacity:10];
        for(NSString *url in imageArray){
            [urls addObject:url];
        }
        [json setValue:urls forKey:@"urls"];
    }
    [json setValue:personId forKey:@"person_id"];
    [self sendRequest:json mothod:@"/api/addface" successBlock:successBlock failureBlock:failureBlock];
}

- (void)delFace:(NSString *)personId faceIdArray:(NSArray *)faceIdArray successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    
    [json setValue:faceIdArray forKey:@"face_ids"];
    [json setValue:personId forKey:@"person_id"];
    [self sendRequest:json mothod:@"/api/delface" successBlock:successBlock failureBlock:failureBlock];
}

- (void)setInfo:(NSString *)personName personId:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:personId forKey:@"person_id"];
    [json setValue:personName forKey:@"person_name"];
    [self sendRequest:json mothod:@"/api/setinfo" successBlock:successBlock failureBlock:failureBlock];
}

- (void)getInfo:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:personId forKey:@"person_id"];
    [self sendRequest:json mothod:@"/api/getinfo" successBlock:successBlock failureBlock:failureBlock];
}

- (void)getGroupIdsWithsuccessBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:4];
    [self sendRequest:json mothod:@"/api/getgroupids" successBlock:successBlock failureBlock:failureBlock];
}

- (void)getPersonIds:(NSString *)groupId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:groupId forKey:@"group_id"];
    [self sendRequest:json mothod:@"/api/getpersonids" successBlock:successBlock failureBlock:failureBlock];
}

- (void)getFaceIds:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:personId forKey:@"person_id"];
    [self sendRequest:json mothod:@"/api/getfaceids" successBlock:successBlock failureBlock:failureBlock];
}

- (void)getFaceInfo:(NSString *)face_id successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:face_id forKey:@"face_id"];
    [self sendRequest:json mothod:@"/api/getfaceinfo" successBlock:successBlock failureBlock:failureBlock];
    
}


- (void)delPerson:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:6];
    [json setValue:personId forKey:@"person_id"];
    [self sendRequest:json mothod:@"/api/delperson" successBlock:successBlock failureBlock:failureBlock];
}

- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *)groupIds personName:(NSString*) personName personTag:(NSString *) personTag successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock {
    
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    [json setValue:groupIds forKey:@"group_ids"];
    [json setValue:personId forKey:@"person_id"];
    if(personTag!=nil && personTag.length>0)
        [json setValue:personTag forKey:@"tag"];
    
    if(personName!=nil && personName.length>0) {
        [json setValue:personName forKey:@"person_name"];
    }
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
    }
    [self sendRequest:json mothod:@"/api/newperson" successBlock:successBlock failureBlock:failureBlock];
}
#pragma mark - ID OCR
- (void)idcardOcr:(id)image cardType:(NSInteger)cardType sessionId:(NSString *)sessionId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"card"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
    }
    
    
    json[@"card_type"] = @(cardType);
    if (sessionId.length > 0) {
        json[@"session_id"] = sessionId;
    }
    [self sendRequest:json mothod:@"/ocrapi/idcardocr" successBlock:successBlock failureBlock:failureBlock];
}

#pragma mark - Image Recognition
- (void)fuzzyDetect:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
        if (cookie != nil) {
            json[@"cookie"] = cookie;
        }
    }
    if (seq.length > 0) {
        json[@"seq"] = seq;
    }
    [self sendRequest:json mothod:@"/imageapi/fuzzydetect" successBlock:successBlock failureBlock:failureBlock];
}

- (void)foodDetect:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
        if (cookie != nil) {
            json[@"cookie"] = cookie;
        }
    }
    if (seq.length > 0) {
        json[@"seq"] = seq;
    }
    [self sendRequest:json mothod:@"/imageapi/fooddetect" successBlock:successBlock failureBlock:failureBlock];
}
- (void)imageTag:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
        if (cookie != nil) {
            json[@"cookie"] = cookie;
        }
    }
    if (seq.length > 0) {
        json[@"seq"] = seq;
    }
    [self sendRequest:json mothod:@"/imageapi/imagetag" successBlock:successBlock failureBlock:failureBlock];
}
- (void)imagePorn:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:10];
    if ([image isKindOfClass:[UIImage class]]) {
        json[@"image"] = [self imageBase64String:image];
    } else if ([image isKindOfClass:[NSString class]]) {
        json[@"url"] = image;
        if (cookie != nil) {
            json[@"cookie"] = cookie;
        }
    }
    if (seq.length > 0) {
        json[@"seq"] = seq;
    }
    [self sendRequest:json mothod:@"/imageapi/imageporn" successBlock:successBlock failureBlock:failureBlock];
}

- (NSString *)imageBase64String:(UIImage *)image
{
    NSData *data = UIImageJPEGRepresentation(image, 1.0f);
    return [data base64String];
}

@end
