//
//  ViewController.m
//  YoutuYunDemo
//
//  Created by Patrick Yang on 15/9/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//

#import "DemoViewController.h"
#import "Conf.h"
#import "Auth.h"
#import "TXQcloudFrSDK.h"


@interface DemoViewController ()

@end

@implementation DemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [Conf instance].appId = @"1000031";
    [Conf instance].secretId = @"AKIDUIDlPDt5mZutfr46NT0GisFcQh1nMOox";
    [Conf instance].secretKey = @"ind5yAd55ZspBc7MCANcxEjuXi8YU8RL";
    
    NSString *auth = [Auth appSign:1000000 userId:nil];
    TXQcloudFrSDK *sdk = [[TXQcloudFrSDK alloc] initWithName:[Conf instance].appId authorization:auth];
    
    sdk.API_END_POINT = @"http://api.youtu.qq.com/youtu";
    
    UIImage *local = [UIImage imageNamed:@"face.jpg"];
    NSString *remote = @"http://a.hiphotos.baidu.com/image/pic/item/42166d224f4a20a4be2c49a992529822720ed0aa.jpg";
    id image = remote;
    
//    [sdk detectFace:image successBlock:^(id responseObject) {
//        NSLog(@"responseObject: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        NSLog(@"error");
//    }];
//    
//    [sdk idcardOcr:image cardType:1 sessionId:nil successBlock:^(id responseObject) {
//        NSLog(@"responseObject: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        
//    }];
//    [sdk imageTag:image cookie:nil seq:nil successBlock:^(id responseObject) {
//        NSLog(@"responseObject: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        
//    }];
//
//    [sdk imagePorn:image cookie:nil seq:nil successBlock:^(id responseObject) {
//        NSLog(@"responseObject: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        
//    }];
//
//    [sdk foodDetect:image cookie:nil seq:nil successBlock:^(id responseObject) {
//        NSLog(@"responseObject: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        
//    }];
    [sdk fuzzyDetect:image cookie:nil seq:nil successBlock:^(id responseObject) {
        NSLog(@"responseObject: %@", responseObject);
    } failureBlock:^(NSError *error) {
        
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
