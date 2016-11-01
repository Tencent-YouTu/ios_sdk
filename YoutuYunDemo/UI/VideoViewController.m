//
//  VideoViewController.m
//  WeBank
//
//  Created by doufeifei on 14/12/23.
//
//

#import "VideoViewController.h"
#import "WBCaptureService.h"
#import  "JSONKit.h"
#import "WBObjectExtension.h"
#import "YTServerAPI.h"


#define VideoLength  4

#define kalaOkLength  4
#define kwordSize 24

#define VideoUploadTag  3131
#define VideoSecretTag  3133
@interface VideoViewController ()<WBCaptureServiceDelegate,UIAlertViewDelegate>
{
    NSInteger terminaTime;
    NSTimer *timer;
    
    BOOL addedObservers;
    BOOL allowedToUseGPU;
    BOOL isRecording;
    UIBackgroundTaskIdentifier backgroundRecordingID;
    
    NSString *meadiaId;
    NSString *weBankSession;
    NSString *readLips;
    NSString *encryptKey;
    
    NSString *cardId;
    NSString *cardName;
    
    UInt32 validateId;
    
    BOOL needsUpload;
    
    UIView *redBgView;
}
@property (weak, nonatomic) IBOutlet UILabel *wordLabel;
@property (weak, nonatomic) IBOutlet UIButton *beginBtn;

@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewView;
@property(nonatomic, strong) WBCaptureService *captureService;

@property (weak, nonatomic) IBOutlet UIView *preView;

@property (weak, nonatomic) IBOutlet UILabel *redLabel;

@property (nonatomic, strong) UIImageView *guideView;

- (IBAction)beginClicked:(id)sender;
@end

@implementation VideoViewController

- (instancetype) init{
    NSString *nibName = @"VideoViewController";
    self = [super initWithNibName:nibName bundle:nil];
    return self;
}

-(void)setCardId:(NSString *)c
{
    cardId = c;
}
-(void)setCardName:(NSString *)c
{
    cardName = c;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initVideoCapture];
    isRecording = NO;
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"0",@"needActive", nil];
//    [[WBNetMethods sharedInstance] getSecretKeyWithString:WBGetSecretKey value:dict delegate:self tag:VideoSecretTag];
//    [self addGuideView];
}
//- (void)addGuideView
//{
//    self.guideView = [[UIImageView alloc] initWithFrame:self.view.frame];
//    [self.guideView setImage:[UIImage imageNamed:@"face_guide.png"]];
//    [self.view addSubview:self.guideView];
//    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(guideViewTaped:)];
//    self.guideView.userInteractionEnabled = YES;
//    [self.guideView addGestureRecognizer:tap];
//    [self.view bringSubviewToFront:self.guideView];
//}
- (void)guideViewTaped:(UITapGestureRecognizer *)guesture
{
    self.guideView.hidden = YES;
    [self.guideView removeFromSuperview];
    
    [self beginClicked:nil];
}
- (void)cleanCurrentStats
{
    allowedToUseGPU = NO;
    self.captureService.renderingEnabled = NO;
    
    //    [self.captureService stopRecording]; // no-op if we aren't recording
    [self abortVideo];
    [self stopKalaOk];
    
    
    if (self.captureService) {
        [self.captureService stopRunning];
    }
}
- (void)viewWillDisappear:(BOOL)animated
{
    
    [super viewWillDisappear:animated];
}
- (void)viewDidDisappear:(BOOL)animated
{
    [self cleanCurrentStats];
//    [[WBNetMethods sharedInstance] cleanRequest];
    [super viewDidDisappear:animated];
}

-(void)setReadLips:(NSString *)r
{
    readLips = r;
}

-(void)setValidateId:(UInt32)i
{
    validateId = i;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] init];
    barButton.title = @"返回";
    self.navigationController.navigationBar.topItem.backBarButtonItem = barButton;
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self.navigationItem setTitle:@"人脸识别"];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage imageNamed:@"nav_back64.png"] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar
     setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    [self adjustWordSize:readLips];
    
    [self.captureService startRunning];
    [self setupPreviewView];
    
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
    self.captureService.shouldRecordAudio = YES;
    //    self.captureService.videoFrameRate = 1;
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
- (void)startTimer
{
    if (nil == timer) {
        timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updageState) userInfo:nil repeats:YES];
    }
}
- (void)stopTimer
{
    if (nil != timer) {
        [timer invalidate];
        timer = nil;
    }
}
- (void)updageState
{
    if (terminaTime > 3) {
        NSString *string = [NSString stringWithFormat:@"%zd", terminaTime];
        [self.beginBtn setTitle:string forState:UIControlStateNormal];
//        [self.beginBtn setTitleColor:[UIColor colorWithHexString:@"959595"] forState:UIControlStateNormal];
    }else if (terminaTime > 0){
        NSString *string = [NSString stringWithFormat:@"%zd", terminaTime];
        [self.beginBtn setTitle:string forState:UIControlStateNormal];
//        [self.beginBtn setTitleColor:[UIColor colorWithHexString:@"ff0000"] forState:UIControlStateNormal];
    }else{
        [self stopRecording];
        [self.beginBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        return;
    }
//    [WBComMediaMethods btnClickedVoice];
    terminaTime --;
    
}
- (IBAction)beginClicked:(id)sender {
    //    hadPreview = YES;
    if (!isRecording) {
        [self beginCaptureVideo];
    }else{
        [self stopRecording];;
    }
}


- (void)nextClicked{
//    [[NSNotificationCenter defaultCenter] postNotificationName:@"nativeViewCallBack" object:@"face_verify_success"];
//    
//    CATransition* transition = [CATransition animation];
//    transition.duration = 0.375;
//    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//    transition.type = kCATransitionPush; //kCATransitionMoveIn; //, kCATransitionPush, kCATransitionReveal, kCATransitionFade
//    
//    transition.subtype = kCATransitionFromRight; //kCATransitionFromLeft, kCATransitionFromRight, kCATransitionFromTop, kCATransitionFromBottom
//    [self.navigationController.view.layer addAnimation:transition forKey:nil];
    //[[self navigationController] popToRootViewControllerAnimated:YES];
    
    [[self navigationController] popViewControllerAnimated:YES];
}
- (void)abortVideo
{
    needsUpload = NO;
    isRecording = NO;
    self.beginBtn.enabled = YES;
    
    [self stopTimer];
    [self.captureService stopRecording];
}
- (void)beginCaptureVideo
{
    self.captureService.videoFrameRate = 30;
    terminaTime = VideoLength;
    [self startKalaOk];
    [self startTimer];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    if ( [[UIDevice currentDevice] isMultitaskingSupported] ) {
        backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];
    }
    
    [self.captureService startRecording];
    
    isRecording = YES;
    self.beginBtn.enabled = NO;
    needsUpload = YES;
}
- (void)stopRecording
{
    [self.captureService stopRecording];
    [self stopTimer];
}
- (void)uploadVideo
{
    [self showLoading:@"视频上传中"];
    NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!!!!url = %@", [self.captureService.recordingURL absoluteString]);
    NSData *data = [NSData dataWithContentsOfURL:self.captureService.recordingURL];
//    data = @"aaa";
    
    [[YTServerAPI instance] idcardLivedetectFour:data withCardId:cardId withCardName:cardName withValidateId:readLips callback:^(NSInteger error, NSInteger liveStatus, NSInteger compareStatus, NSInteger sim){
        [self hideLoading];
        UIAlertView *resultAlert=nil;
        if (error == 0) {
            NSString *message = @"";
            NSString *copmareResult = @"";
            NSString *liveDetectStatus = @"";
            if(compareStatus == 0)//face comparison succeeded
            {
                copmareResult = @"通过";
//                [self finishRecordingVideo:YES];
            }else{
                copmareResult = @"不通过";
                
            }
            message = [message stringByAppendingFormat:@"人脸识别:%@%@%ld%@", liveDetectStatus, @"(", (long)sim, @")"];
            
            liveDetectStatus = [NSString stringWithFormat:@"通过"];
            switch (liveStatus) {
                case -5001:
                    liveDetectStatus = [NSString stringWithFormat:@"视频文件异常，请重新录制。"];
                    break;
                case -5002:
                    liveDetectStatus = [NSString stringWithFormat:@"活体检测失败，请重新录制。"];
                    break;
                case -5007:
                    liveDetectStatus = [NSString stringWithFormat:@"视频文件异常，请重新录制。"];
                    break;
                case -5008:
                    liveDetectStatus = [NSString stringWithFormat:@"活体检测失败，请重新录制。"];
                    break;
                case -5009:
                    liveDetectStatus = [NSString stringWithFormat:@"活体检测失败，请重新录制。"];
                    break;
                case -5010:
                    liveDetectStatus = [NSString stringWithFormat:@"活体检测失败，请重新录制。"];
                    break;
                case -5011:
                    liveDetectStatus = [NSString stringWithFormat:@"活体检测失败，请重新录制。"];
                    break;
                case -5012:
                    liveDetectStatus = [NSString stringWithFormat:@"活体检测失败，请选择安静的环境朗读。"];
                    break;
                case -5013:
                    liveDetectStatus = [NSString stringWithFormat:@"活体检测失败，请选择安静的环境朗读。"];
                    break;
                    
                    
                default:
                    break;
            }
            
            message = [message stringByAppendingFormat:@"\n"];
            message = [message stringByAppendingFormat:@"活体检测:%@", liveDetectStatus];
            
            resultAlert = [[UIAlertView alloc] initWithTitle:@"对比结果" message:message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            resultAlert.tag = 9999;
            [resultAlert show];
            
        }
        else{
            
            resultAlert = [[UIAlertView alloc] initWithTitle:@"对比结果" message:@"活体检测失败，请重新录制。" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            resultAlert.tag = 9999;
            [resultAlert show];
            
        }
        
    }];
}
- (void)finishRecordingVideo:(BOOL)success
{
    NSString *btnString = @"重试";
    [self stopKalaOk];
    if (success) {
//        [self adjustWordSize:@"识别成功"];
        btnString = @"开始";
    }
    [self.beginBtn setTitle:btnString forState:UIControlStateNormal];
    self.beginBtn.hidden = NO;
    self.beginBtn.enabled = YES;
    isRecording = NO;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
    backgroundRecordingID = UIBackgroundTaskInvalid;
    
}
- (void)prepareRetryVideo
{
    
}
- (void)removeVideo:(NSString *)filePath
{
    NSLog(@"!!!!!!!!!!!!!!!!!!!!!!!!filePath = %@", filePath);
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
            if (nil != error) {
                NSLog(@"%@", error);
                error = nil;
            }
        });
    }
}
#pragma mark - Notifcation

- (void)applicationDidEnterBackground
{
    // Avoid using the GPU in the background
    allowedToUseGPU = NO;
    self.captureService.renderingEnabled = NO;
    
    //    [self.captureService stopRecording]; // no-op if we aren't recording
    [self abortVideo];
    [self stopKalaOk];
}

- (void)applicationWillEnterForeground
{
    allowedToUseGPU = YES;
    self.captureService.renderingEnabled = YES;
    [self.beginBtn setTitle:@"开始" forState:UIControlStateNormal];
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
    if (needsUpload) {
        self.beginBtn.hidden = YES;
        [self uploadVideo];
    }
}
- (void)captureService:(WBCaptureService *)captureService recordingDidFailWithError:(NSError *)error
{
    NSLog(@"error  == %@", [error description]);
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (9999 == alertView.tag) {
        [self nextClicked];
        return;
    }
    isRecording = NO;
    self.beginBtn.enabled = YES;
    [self.beginBtn setTitle:@"开始" forState:UIControlStateNormal];
    self.beginBtn.hidden = NO;
    
    self.captureService.videoFrameRate = 30;
    [self.captureService startRunning];
    [self setupPreviewView];
}

- (void)startKalaOk
{
    self.wordLabel.hidden = NO;
    [self.wordLabel setTextColor:[UIColor whiteColor]];
    
    NSString *string = self.wordLabel.text;
    [self.redLabel setText:self.wordLabel.text];
    string = self.redLabel.text;
    
    CGRect frame = self.wordLabel.frame;
    frame.size.width = 0.f;
    self.redLabel.frame = frame;
    self.redLabel.hidden = NO;
    self.redLabel.clipsToBounds = YES;
    self.redLabel.transform = CGAffineTransformIdentity;
    
    VideoViewController *weakSelf = self;
    [UIView animateWithDuration:kalaOkLength animations:^{
        weakSelf.redLabel.frame = weakSelf.wordLabel.frame;
    } completion:^(BOOL finished) {
        //        self.redLabel.frame = self.wordLabel.frame;
    }];
}
- (void)stopKalaOk
{
    self.redLabel.hidden = YES;
    [self.redLabel.layer removeAllAnimations];
}
- (void)adjustWordSize:(NSString *)string
{
    CGPoint center = self.wordLabel.center;
    [self.wordLabel setText:string];
    [self.wordLabel sizeToFit];
    self.wordLabel.center = center;
}
@end
