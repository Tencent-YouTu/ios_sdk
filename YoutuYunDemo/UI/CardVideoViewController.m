//
//  CardVideoViewController.m
//  WeBank
//
//  Created by doufeifei on 15/1/21.
//
//

#import "CardVideoViewController.h"

#import "YTServerAPI.h"
#import "WBCaptureService.h"
#import  "JSONKit.h"
#import "WBObjectExtension.h"
#import "Auth.h"
#import "Conf.h"
#import "CardResultViewController.h"

#define FrontCardVideoTag  0
#define BackCardVideoTag   1

#define kVideoWidth  720
#define kVideoHeight 1280

@interface CardVideoViewController ()<UIAlertViewDelegate>
{
    NSInteger currentType;//1正
    
    NSInteger terminaTime;
    NSTimer *timer;
    UIBackgroundTaskIdentifier backgroundRecordingID;
    BOOL isRecording;
    BOOL addedObservers;
    BOOL allowedToUseGPU;
    
    BOOL isVertical;
    float scale;
    float x;
    float y;
    float w;
    float h;
    CGRect idPosHintRect;
    CGRect idPosRealRect;
    
    NSString *weBankSession;
    NSString *encryptKey;
    BOOL needsUpload;
}
@property (weak, nonatomic) IBOutlet UIImageView *backGround;

@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewView;
@property(nonatomic, strong) WBCaptureService *captureService;
@property (weak, nonatomic) IBOutlet UIView *preView;

@property (weak, nonatomic) IBOutlet UILabel *tipsLabel;
@property (weak, nonatomic) IBOutlet UILabel *errMsgLabel;
@property (weak, nonatomic) IBOutlet UIButton *beginBtn;
@property (weak, nonatomic) IBOutlet UIImageView *indicatorLeft;
@property (weak, nonatomic) IBOutlet UIImageView *indicatorRight;
@property (weak, nonatomic) IBOutlet UIImageView *idcardFirst;
@property (weak, nonatomic) IBOutlet UIImageView *idcardSecode;
@property (nonatomic, assign) NSString * cardId;
@property (nonatomic, assign) NSString * cardName;


@end

@implementation CardVideoViewController

- (instancetype) init{
    NSString *nibName = @"CardVideoViewController";
    self = [super initWithNibName:nibName bundle:nil];
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] init];
    barButton.title = @"返回";
    self.navigationController.navigationBar.topItem.backBarButtonItem = barButton;
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self.navigationItem setTitle:@"身份证识别"];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"nav_back64.png"] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar
     setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    [self.captureService startRunning];
    [self setupPreviewView];
    needsUpload = YES;
    [self initUI];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.preView.frame = self.view.frame;
    
    [self initVideoCapture];
    
    x = 16;
    y = 150;
    w = 300;
    h = 192;
    // TODO: idPosHintRect的值应该根据view去获取
    idPosHintRect = CGRectMake(16, 151, 288, 183);
    idPosRealRect = CGRectNull;
    currentType = 1;

    // Do any additional setup after loading the view.
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (self.captureService) {
        [self.captureService stopRunning];
    }
//    [[WBNetMethods sharedInstance] cleanRequest];
    [super viewDidDisappear:animated];
}

- (void)initUI
{
    
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}
- (void)initVideoCapture
{
    self.captureService = [[WBCaptureService alloc] init];
    [self.captureService setDelegate:self callbackQueue:dispatch_get_main_queue()];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:[UIDevice currentDevice]];
    
    // Keep track of changes to the device orientation so we can update the capture Service
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    // the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
    allowedToUseGPU = ( [UIApplication sharedApplication].applicationState != UIApplicationStateBackground );
    self.captureService.renderingEnabled = allowedToUseGPU;
    self.captureService.shouldSaveToAlbum = NO;
    self.captureService.shouldRecordAudio = NO;
    self.captureService.preferedDevicePosition = AVCaptureDevicePositionBack;
    self.captureService.captureType = WBCaptureType_Image;
}
- (void)setupPreviewView
{
    AVCaptureVideoPreviewLayer *previewLayer = self.captureService.previewLayer;
    [previewLayer setFrame:[self.preView bounds]];
    
    CALayer *rootLayer = [self.preView layer];
    [rootLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [rootLayer addSublayer:previewLayer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)ClickBeginCamera:(id)sender {
    //拍摄照片
    self.errMsgLabel.hidden = YES;
    
    if (self.captureService) {
        [self.captureService takeOneShotPicture:^(int result, UIImage *image) {
            if (result == 0 && image) {
                [self uploadImage:image];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                });
            }
        }];
    }
}

- (void)uploadImage:(UIImage *)image
{
    if (image) {
        NSInteger requestTag = currentType == 1 ? FrontCardVideoTag: BackCardVideoTag;
        
        [self showLoading:@"身份证识别中"];
        self.beginBtn.enabled = NO;
//        YTServerAPI *api = [YTServerAPI instance];
        [[YTServerAPI instance] idcardOCR:image withCardType:requestTag callback:^(NSInteger error, NSDictionary *dic){
            [self hideLoading];
            self.beginBtn.enabled = YES;
            if(requestTag == FrontCardVideoTag) {
                if (error == 0) {
                    [self frontSucc:dic];
                }else{
                    NSString *message = @"OCR识别失败, 请重试";
                    [self frontFail:message];
                }
            }else if(requestTag == BackCardVideoTag) {
                if (error == 0) {
                    [self backSucc];
                }else{
                    NSString *message = @"OCR识别失败, 请重试";
                    [self backFail:message];
                }
            }
            
        }];
        
    }
}

- (void)frontSucc:(NSDictionary *)dict
{
    currentType = 2;
    [self.tipsLabel setText:@"请翻转到身份证另一面"];
    
    [[NSUserDefaults standardUserDefaults] setValue:[dict  stringValueForKey:@"name" defaultValue:@" " operation:NSStringOperationTypeNone] forKey:@"idCardName"];
    [[NSUserDefaults standardUserDefaults] setValue:[dict stringValueForKey:@"id" defaultValue:@" " operation:NSStringOperationTypeNone] forKey:@"idCardNo"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.indicatorLeft setImage:[UIImage imageNamed:@"indicator_correct.png"]];
    
    __weak CardVideoViewController *weakSelf = self;
    
    [UIView animateWithDuration:1.5f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        weakSelf.idcardFirst.transform = CGAffineTransformMakeScale(0.001, 1);
    } completion:^(BOOL finished) {
        weakSelf.idcardFirst.hidden = YES;
        weakSelf.idcardSecode.hidden = NO;
        [UIView animateWithDuration:1.5f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            CGAffineTransform t3 = CGAffineTransformMakeTranslation(0, 0);
            CGAffineTransform t_Scale = CGAffineTransformMakeScale(284, 1);
            CGAffineTransform t1 = CGAffineTransformConcat(t_Scale, t3);
            weakSelf.idcardSecode.transform = t1;
        } completion:^(BOOL finished) {
            [weakSelf.tipsLabel setText:@"请拍摄身份证国徽面"];
        }];
    }];
}

- (void)frontFail:(NSString *)message
{
    [self.indicatorLeft setImage:[UIImage imageNamed:@"indicator_wrong.png"]];
    [self.errMsgLabel setText:message];
    self.errMsgLabel.hidden = NO;
}
- (void)backFail:(NSString *)message
{
    [self.indicatorRight setImage:[UIImage imageNamed:@"indicator_wrong.png"]];
    [self.errMsgLabel setText:message];
    self.errMsgLabel.hidden = NO;
}
- (void)backSucc
{
    currentType = 1;
    
    [self.indicatorRight setImage:[UIImage imageNamed:@"indicator_correct.png"]];
    
    CATransition* transition = [CATransition animation];
    transition.duration = 0.375;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    transition.type = kCATransitionPush; //kCATransitionMoveIn; //, kCATransitionPush, kCATransitionReveal, kCATransitionFade
    
    transition.subtype = kCATransitionFromRight; //kCATransitionFromLeft, kCATransitionFromRight, kCATransitionFromTop, kCATransitionFromBottom
    [self.navigationController.view.layer addAnimation:transition forKey:nil];
    [[self navigationController] popViewControllerAnimated:NO];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"nativeViewCallBack" object:@"id_card_verify_success"];
    
//    CardResultViewController *controller = [[CardResultViewController alloc]init];
//    [self.navigationController pushViewController:controller animated:YES];
}
- (void)sessionError:(NSString *)message
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"获取session失败" message:message delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
    alertView.tag = 9528;
    [alertView show];
}

#pragma mark - Notifcation

- (void)applicationDidEnterBackground
{
    // Avoid using the GPU in the background
    allowedToUseGPU = NO;
    self.captureService.renderingEnabled = NO;
    
}
- (void)applicationWillEnterForeground
{
    allowedToUseGPU = YES;
    self.captureService.renderingEnabled = YES;
    
    NSString *string = currentType == 1 ? @"身份证正面放入框内" : @"请翻转到身份证反面";
    [self.tipsLabel setText:string];
    //    [self.beginBtn setTitle:@"开始" forState:UIControlStateNormal];
    needsUpload = YES;
}

- (void)deviceOrientationDidChange
{
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    // Update recording orientation if device changes to portrait or landscape orientation (but not face up/down)
    if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) ) {
        [self.captureService setRecordingOrientation:(AVCaptureVideoOrientation)deviceOrientation];
    }
}

#pragma mark - WBCaptureServiceDelegate

- (void)captureService:(WBCaptureService *)captureService didStopRunningWithError:(NSError *)error
{
}

// Preview
- (void)captureService:(WBCaptureService *)captureService previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer
{
}

- (void)captureServiceDidRunOutOfPreviewBuffers:(WBCaptureService *)captureService
{
}

// Recording
- (void)captureServiceRecordingDidStart:(WBCaptureService *)captureService
{
    
}

- (void)captureServiceRecordingWillStop:(WBCaptureService *)captureService
{
    // Disable record button until we are ready to start another recording
}

- (void)captureServiceRecordingDidStop:(WBCaptureService *)captureService
{
    
}
- (void)captureService:(WBCaptureService *)captureService recordingDidFailWithError:(NSError *)error
{
    NSLog(@"error  == %@", [error description]);
    
}
- (void)getScale
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    float rate = [[UIScreen mainScreen] scale];
    float width = size.width * rate;
    float height = size.height * rate;
    
    if (height/width > kVideoHeight/kVideoWidth) {
        isVertical = YES;
        scale = kVideoWidth/width;
        w =ceilf(w * scale * rate);
        x = floorf(x * scale * rate);
        y = y * rate;
        h = h * rate;
    }else{
        isVertical = NO;
        scale = kVideoHeight/height;
        y = floorf(y * scale * rate);
        h = ceilf(h * scale * rate);
        x = x * rate;
        w = w * rate;
    }
}
@end
