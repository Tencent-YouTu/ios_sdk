//
//  ViewController.m
//  YoutuYunDemo
//
//  Created by Patrick Yang on 15/9/15.
//  Copyright (c) 2015年 Tencent. All rights reserved.
//
//
//
//请在Conf.m里设置自己申请的 APP_ID, SECRET_ID, SECRET_KEY,否则网络请求签名验证会出错。
//
//人脸核身相关接口，需要申请权限接入，具体参考http://open.youtu.qq.com/welcome/service#/solution-facecheck
//人脸核身接口包括：
//- (void)idcardOcrFaceIn:(id)image cardType:(NSInteger)cardType successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
//- (void)idcardNameFaceIn:(NSString*)id_num cardName:(NSString*)id_name successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
//- (void)faceCompareFaceIn:(id)imageA imageB:(id)imageB successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
//- (void)idcardfacecompare:(NSString*)idCardNumber withName:(NSString*)idCardName image:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
//- (void)livegetfour:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
//- (void)livedetectfour:(NSData*)video image:(id)image validateId:(NSString*) validateData isCompare:(BOOL)isCompare successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
//- (void)idcardlivedetectfour:(NSData*)video withId:(NSString*)idCardNumber withName:(NSString*)idCardName validateId:(NSString*) validateData successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
//
//

#import "DemoViewController.h"
#import "Conf.h"
#import "Auth.h"
#import "TXQcloudFrSDK.h"
#import "CardVideoViewController.h"
#import "CardResultViewController.h"


@interface DemoViewController ()
@property (strong, nonatomic) IBOutlet UIButton *faceInEnterButton;

@end

@implementation DemoViewController
- (instancetype) init{
    NSString *nibName = @"DemoViewController";
    self = [super initWithNibName:nibName bundle:nil];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIImage *buttongBgImg = [[UIImage imageNamed:@"bt_blue"] resizableImageWithCapInsets:UIEdgeInsetsMake(6, 6, 6, 6)];
    [self.faceInEnterButton setBackgroundImage:buttongBgImg forState:UIControlStateNormal];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processCallBack:) name:@"nativeViewCallBack" object:nil];
    
    self.title = @"优图";
    
    [self testFacein];
    
    NSString *auth = [Auth appSign:1000000 userId:nil];
    TXQcloudFrSDK *sdk = [[TXQcloudFrSDK alloc] initWithName:[Conf instance].appId authorization:auth endPoint:[Conf instance].API_END_POINT];
    
//    UIImage *local = [UIImage imageNamed:@"id.jpg"];
    UIImage *local = [UIImage imageNamed:@"id3.jpg"];
    NSString *remote = @"http://a.hiphotos.baidu.com/image/pic/item/42166d224f4a20a4be2c49a992529822720ed0aa.jpg";
    id image = local;

//    [sdk detectFace:image successBlock:^(id responseObject) {
//        NSLog(@"responseObject: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        NSLog(@"error");
//    }];

//    [sdk idcardOcr:image cardType:0 sessionId:nil successBlock:^(id responseObject) {
//        NSLog(@"idcardOcr: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        
//    }];

//    [sdk namecardOcr:image sessionId:nil successBlock:^(id responseObject) {
//        NSLog(@"namecardOcr: %@", responseObject);
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
//    [sdk fuzzyDetect:image cookie:nil seq:nil successBlock:^(id responseObject) {
//        NSLog(@"responseObject: %@", responseObject);
//    } failureBlock:^(NSError *error) {
//        
//    }];
}

//人脸核身相关接口调用
- (void)testFacein{
    NSString *auth = [Auth appSign:1000000 userId:nil];
    TXQcloudFrSDK *sdk = [[TXQcloudFrSDK alloc] initWithName:[Conf instance].appId authorization:auth endPoint:[Conf instance].API_VIP_END_POINT];
    
    
    //    UIImage *local = [UIImage imageNamed:@"id.jpg"];
    UIImage *local = [UIImage imageNamed:@"id.jpg"];
    NSString *remote = @"http://a.hiphotos.baidu.com/image/pic/item/42166d224f4a20a4be2c49a992529822720ed0aa.jpg";
    id image = local;
    
    [sdk idcardOcrFaceIn:image cardType:0 successBlock:^(id responseObject) {
        NSLog(@"idcardOcrFaceIn: %@", responseObject);
    }failureBlock:^(NSError *error) {
        NSLog(@"error");
    }];
    
    NSString *idNumber = @"12345678901234567";
    NSString *idName = @"李磊";
    [sdk idcardNameFaceIn:idNumber cardName:idName successBlock:^(id responseObject) {
        NSLog(@"idcardNameFaceIn: %@", responseObject);
    } failureBlock:^(NSError *error) {
        NSLog(@"error");
    }];
    
    

    //
    //    [sdk faceCompareFaceIn:image imageB:remote successBlock:^(id responseObject) {
    //        NSLog(@"faceCompareFaceIn: %@", responseObject);
    //    }failureBlock:^(NSError *error) {
    //        NSLog(@"error");
    //    }];
    //
    //    [sdk idcardfacecompare: @"1123456789987654321" withName:@"王小明" image:image successBlock:^(id responseObject){
    //        NSLog(@"idcardfacecompare: %@", responseObject);
    //    }failureBlock:^(NSError *error) {
    //        NSLog(@"error");
    //    }];
    
    
    //    [sdk livegetfour:^(id responseObject){
    //        NSLog(@"livegetfour: %@", responseObject);
    //    }failureBlock:^(NSError *error) {
    //        NSLog(@"error");
    //    }];
    
    //    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"video" ofType:@"mp4"];
    //    NSData *video = [NSData dataWithContentsOfFile:filePath];
    //    [sdk livedetectfour:video image:image validateId:@"3388" isCompare:YES successBlock: ^(id responseObject){
    //        NSLog(@"livedetectfour: %@", responseObject);
    //    }failureBlock:^(NSError *error) {
    //        NSLog(@"error");
    //    }];
    
    //    [sdk idcardlivedetectfour:video withId:@"1123456789987654321" withName:@"王小明" validateId:@"3388" successBlock: ^(id responseObject){
    //        NSLog(@"idcardlivedetectfour: %@", responseObject);
    //    }failureBlock:^(NSError *error) {
    //        NSLog(@"error");
    //    }];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)clickFacein:(id)sender {
    CardVideoViewController *controller = [[CardVideoViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
    
//    CardResultViewController *controller = [[CardResultViewController alloc]init];
//    [self.navigationController pushViewController:controller animated:YES];
}

- (void)processCallBack:(NSNotification *)notify
{
    NSString *message = (NSString *)notify.object;
    
    NSString *callbackString = nil;
    if ([message isEqualToString:@"id_card_verify_success"]) {
//        NSString *name = [[NSUserDefaults standardUserDefaults] objectForKey:@"idCardName"];
//        NSString *number = [[NSUserDefaults standardUserDefaults] objectForKey:@"idCardNo"];
//        
//        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"idCardName"];
//        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"idCardNo"];
//        [[NSUserDefaults standardUserDefaults] synchronize];
        
        CardResultViewController *controller = [[CardResultViewController alloc]init];
        [self.navigationController pushViewController:controller animated:YES];

    }
    
}
@end
