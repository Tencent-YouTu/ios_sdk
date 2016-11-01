//
//  WBCaptureService.m
//  CaptrueServiceDemo
//
//  Created by Sampanweng on 14/12/24.
//  Copyright (c) 2014年 webank. All rights reserved.
//

#import "WBCaptureService.h"
#import "WBVideoRecorder.h"
#include <mach/mach_time.h>
#import <AssetsLibrary/AssetsLibrary.h>
//cn.mumble.video
#define RETAINED_BUFFER_COUNT 6

#define RECORD_AUDIO 0

#define LOG_STATUS_TRANSITIONS 0

typedef NS_ENUM( NSInteger, WBRecordingStatus )
{
    WBRecordingStatusIdle = 0,
    WBRecordingStatusStartingRecording,
    WBRecordingStatusRecording,
    WBRecordingStatusStoppingRecording,
}; // internal state machine

@interface WBCaptureService () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, WBVideoRecorderDelegate>
{
    __weak id <WBCaptureServiceDelegate> _delegate; // __weak doesn't actually do anything under non-ARC
    dispatch_queue_t _delegateCallbackQueue;
    
    NSMutableArray *_previousSecondTimestamps;
    
	AVCaptureSession *_captureSession;
    AVCaptureDevice *_videoDevice;
    AVCaptureConnection *_audioConnection;
    AVCaptureConnection *_videoConnection;
    AVCaptureStillImageOutput *_stillImageOutput;
    BOOL _running;
    BOOL _startCaptureSessionOnEnteringForeground;
    id _applicationWillEnterForegroundNotificationObserver;
    NSDictionary *_videoCompressionSettings;
    NSDictionary *_audioCompressionSettings;
    
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _videoDataOutputQueue;
    
    WBRecordingStatus _recordingStatus;
    
    UIBackgroundTaskIdentifier _pipelineRunningTask;
    CMTime _nextPTS;
}

@property(nonatomic, retain) __attribute__((NSObject)) CVPixelBufferRef currentPreviewPixelBuffer;

@property(readwrite) CMVideoDimensions videoDimensions;
@property(nonatomic, readwrite) AVCaptureVideoOrientation videoOrientation;
@property(nonatomic, assign) FourCharCode inputPixelFormat;
@property(nonatomic, retain) __attribute__((NSObject)) CMFormatDescriptionRef outputVideoFormatDescription;
@property(nonatomic, retain) __attribute__((NSObject)) CMFormatDescriptionRef outputAudioFormatDescription;
@property(nonatomic, strong) WBVideoRecorder *recorder;
@property(nonatomic, copy) WBOneShotCallback oneShotCallback;
@property(nonatomic, assign) NSInteger preferedBitRate;
@property(nonatomic, assign) NSInteger previewFrameRate;

@end

@implementation WBCaptureService

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        _previousSecondTimestamps = [[NSMutableArray alloc] init];
        _recordingOrientation = (AVCaptureVideoOrientation)UIDeviceOrientationPortrait;
        
        NSString *fileName = [NSString stringWithFormat:@"Record-%llu.mp4", mach_absolute_time()];
        _recordingURL = [[NSURL alloc] initFileURLWithPath:[NSString pathWithComponents:@[NSTemporaryDirectory(), fileName]]];
        
        _sessionQueue = dispatch_queue_create( "com.webank.CaptureService.session", DISPATCH_QUEUE_SERIAL );
        
        // In a multi-threaded producer consumer system it's generally a good idea to make sure that producers do not get starved of CPU time by their consumers.
        // In this app we start with VideoDataOutput frames on a high priority queue, and downstream consumers use default priority queues.
        // Audio uses a default priority queue because we aren't monitoring it live and just want to get it into the movie.
        // AudioDataOutput can tolerate more latency than VideoDataOutput as its buffers aren't allocated out of a fixed size pool.
        _videoDataOutputQueue = dispatch_queue_create( "com.webank.CaptureService.video", DISPATCH_QUEUE_SERIAL );
        dispatch_set_target_queue( _videoDataOutputQueue, dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ) );
        
        _pipelineRunningTask = UIBackgroundTaskInvalid;
        _inputPixelFormat = kCVPixelFormatType_32BGRA;
        self.videoFrameRate = 30;
        _previewFrameRate = 30;
        _shouldRecordAudio = NO;
        _shouldSaveToAlbum = NO;
        _preferedDevicePosition = AVCaptureDevicePositionFront;
        _nextPTS = kCMTimeZero;
        _captureType = WBCaptureType_Video;
    }
    return self;
}

- (void)dealloc
{
    _delegate = nil;
    _delegateCallbackQueue = nil;
    
    if ( _currentPreviewPixelBuffer ) {
        CFRelease( _currentPreviewPixelBuffer );
    }
    
    _previousSecondTimestamps = nil;
    
    [self teardownCaptureSession];
    
    _sessionQueue = nil;
    _videoDataOutputQueue = nil;
    
    if ( _outputVideoFormatDescription ) {
        CFRelease( _outputVideoFormatDescription );
    }
    
    if ( _outputAudioFormatDescription ) {
        CFRelease( _outputAudioFormatDescription );
    }
    
    _recorder = nil;
    _recordingURL = nil;
}

#pragma mark Delegate

- (void)setDelegate:(id<WBCaptureServiceDelegate>)delegate callbackQueue:(dispatch_queue_t)delegateCallbackQueue // delegate is weak referenced
{
    if ( delegate && ( delegateCallbackQueue == NULL ) ) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Caller must provide a delegateCallbackQueue" userInfo:nil];
    }
    
    @synchronized( self )
    {
        _delegate = delegate;
        if ( delegateCallbackQueue != _delegateCallbackQueue ) {
            _delegateCallbackQueue = delegateCallbackQueue;
        }
    }
}

- (id<WBCaptureServiceDelegate>)delegate
{
    id <WBCaptureServiceDelegate> delegate = nil;
    @synchronized( self ) {
        delegate = _delegate;
    }
    return delegate;
}

#pragma mark Capture Session

- (void)startRunning
{
    dispatch_sync( _sessionQueue, ^{
        [self setupCaptureSession];
        
        [_captureSession startRunning];
        _running = YES;
    } );
}

- (void)stopRunning
{
    dispatch_sync( _sessionQueue, ^{
        _running = NO;
        
        // the captureSessionDidStopRunning method will stop recording if necessary as well, but we do it here so that the last video and audio samples are better aligned
        [self stopRecording]; // does nothing if we aren't currently recording
        
        [_captureSession stopRunning];
        
        [self captureSessionDidStopRunning];
        
        [self teardownCaptureSession];
    } );
}

- (void)setupCaptureSession
{
    if ( _captureSession ) {
        return;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionNotification:) name:nil object:_captureSession];
    _applicationWillEnterForegroundNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication] queue:nil usingBlock:^(NSNotification *note) {
        // Retain self while the capture session is alive by referencing it in this observer block which is tied to the session lifetime
        // Client must stop us running before we can be deallocated
        [self applicationWillEnterForeground];
    }];
    
    AVCaptureAudioDataOutput *audioOut;
    if (self.shouldRecordAudio) {
        /* Audio */
        AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:nil];
        if ( [_captureSession canAddInput:audioIn] ) {
            [_captureSession addInput:audioIn];
        }
        
        audioOut = [[AVCaptureAudioDataOutput alloc] init];
        // Put audio on its own queue to ensure that our video processing doesn't cause us to drop audio
        dispatch_queue_t audioCaptureQueue = dispatch_queue_create( "com.webank.CaptureService.audio", DISPATCH_QUEUE_SERIAL );
        [audioOut setSampleBufferDelegate:self queue:audioCaptureQueue];
        
        if ( [_captureSession canAddOutput:audioOut] ) {
            [_captureSession addOutput:audioOut];
        }
        _audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
    }
    
    /* Video */
    //	AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *videoDevice = nil;
    for (AVCaptureDevice *aDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (aDevice.position == self.preferedDevicePosition) {
            videoDevice = aDevice;
            break;
        }
    }
    _videoDevice = videoDevice;
    AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:nil];
    if ( [_captureSession canAddInput:videoIn] ) {
        [_captureSession addInput:videoIn];
    }
    
    //We can config this later.
    if (self.sessionPresent.length > 0) {
        _captureSession.sessionPreset = self.sessionPresent;
    } else {
        NSString *sessionPreset = AVCaptureSessionPresetHigh;
        NSString *preset = AVCaptureSessionPreset640x480;
        if (self.preferedDevicePosition == AVCaptureDevicePositionBack) {
            if (self.captureType == WBCaptureType_Image) {
                preset = AVCaptureSessionPreset1920x1080;
            } else {
                preset = AVCaptureSessionPreset1280x720;
            }
        }
        if ( [_captureSession canSetSessionPreset:preset] ) {
            sessionPreset = preset;
        }
        _captureSession.sessionPreset = sessionPreset;
    }
    
    int frameRate;
    CMTime frameDuration = kCMTimeInvalid;
    
    if (self.captureType != WBCaptureType_Image) {
        //设置帧率和比特率
        self.preferedBitRate = 640 * 480 * 2.1;
        if (self.preferedDevicePosition == AVCaptureDevicePositionBack) {
            self.preferedBitRate = 1280 * 720;
        }
        frameRate = (int)MAX(self.previewFrameRate, self.videoFrameRate);
        frameDuration = CMTimeMake( 1, frameRate );
    }
    
    NSError *error = nil;
    if ( [videoDevice lockForConfiguration:&error] ) {
        if (self.captureType != WBCaptureType_Image) {
            videoDevice.activeVideoMaxFrameDuration = frameDuration;
            videoDevice.activeVideoMinFrameDuration = frameDuration;
        }
        if ([videoDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            videoDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        [videoDevice unlockForConfiguration];
    }
    else {
        NSLog( @"videoDevice lockForConfiguration returned error %@", error );
    }
    
    /* Set Capture output */
    if (self.captureType == WBCaptureType_Image) {
        
        // Make a still image output
        _stillImageOutput = [AVCaptureStillImageOutput new];
        NSDictionary *outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG, AVVideoQualityKey: @(0.7)};
        _stillImageOutput.outputSettings = outputSettings;
        if ([_captureSession canAddOutput:_stillImageOutput]) {
            [_captureSession addOutput:_stillImageOutput];
        }
    } else {
        // Make video output
        AVCaptureVideoDataOutput *videoOut = [[AVCaptureVideoDataOutput alloc] init];
        videoOut.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(_inputPixelFormat) };
        [videoOut setSampleBufferDelegate:self queue:_videoDataOutputQueue];
        
        // WB records videos and we prefer not to have any dropped frames in the video recording.
        // By setting alwaysDiscardsLateVideoFrames to NO we ensure that minor fluctuations in system load or in our processing time for a given frame won't cause framedrops.
        // We do however need to ensure that on average we can process frames in realtime.
        // If we were doing preview only we would probably want to set alwaysDiscardsLateVideoFrames to YES.
        videoOut.alwaysDiscardsLateVideoFrames = NO;
        
        if ( [_captureSession canAddOutput:videoOut] ) {
            [_captureSession addOutput:videoOut];
        }
        _videoConnection = [videoOut connectionWithMediaType:AVMediaTypeVideo];
        
        // Get the recommended compression settings after configuring the session/device.
        if (self.shouldRecordAudio) {
            _audioCompressionSettings = [[audioOut recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] copy];
        }
        
        NSMutableDictionary *videoSettings = [[videoOut recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4] mutableCopy];
        NSMutableDictionary *videoCompressionProperties = [[videoSettings objectForKey:AVVideoCompressionPropertiesKey] mutableCopy];
        videoCompressionProperties[AVVideoAverageBitRateKey] = @(self.preferedBitRate);
        if (([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending)) {
            videoCompressionProperties[AVVideoExpectedSourceFrameRateKey] = @(self.videoFrameRate);
        }
        videoCompressionProperties[AVVideoMaxKeyFrameIntervalKey] = @(self.videoFrameRate);
        videoCompressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264Main41;
        videoSettings[AVVideoCompressionPropertiesKey] = videoCompressionProperties;
        _videoCompressionSettings = [videoSettings copy];
        
        self.videoOrientation = _videoConnection.videoOrientation;
    }
    
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    return;
}

- (void)teardownCaptureSession
{
    if ( _captureSession )
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_captureSession];
        
        [[NSNotificationCenter defaultCenter] removeObserver:_applicationWillEnterForegroundNotificationObserver];
        _applicationWillEnterForegroundNotificationObserver = nil;
        
        _captureSession = nil;
        
        _videoCompressionSettings = nil;
        _audioCompressionSettings = nil;
    }
}

- (void)captureSessionNotification:(NSNotification *)notification
{
    dispatch_async( _sessionQueue, ^{
        
        if ( [notification.name isEqualToString:AVCaptureSessionWasInterruptedNotification] )
        {
            NSLog( @"session interrupted" );
            
            [self captureSessionDidStopRunning];
        }
        else if ( [notification.name isEqualToString:AVCaptureSessionInterruptionEndedNotification] )
        {
            NSLog( @"session interruption ended" );
        }
        else if ( [notification.name isEqualToString:AVCaptureSessionRuntimeErrorNotification] )
        {
            [self captureSessionDidStopRunning];
            
            NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
            if ( error.code == AVErrorDeviceIsNotAvailableInBackground )
            {
                NSLog( @"device not available in background" );
                
                // Since we can't resume running while in the background we need to remember this for next time we come to the foreground
                if ( _running ) {
                    _startCaptureSessionOnEnteringForeground = YES;
                }
            }
            else if ( error.code == AVErrorMediaServicesWereReset )
            {
                NSLog( @"media services were reset" );
                [self handleRecoverableCaptureSessionRuntimeError:error];
            }
            else
            {
                [self handleNonRecoverableCaptureSessionRuntimeError:error];
            }
        }
        else if ( [notification.name isEqualToString:AVCaptureSessionDidStartRunningNotification] )
        {
            NSLog( @"session started running" );
        }
        else if ( [notification.name isEqualToString:AVCaptureSessionDidStopRunningNotification] )
        {
            NSLog( @"session stopped running" );
        }
    } );
}

- (void)handleRecoverableCaptureSessionRuntimeError:(NSError *)error
{
    if ( _running ) {
        [_captureSession startRunning];
    }
}

- (void)handleNonRecoverableCaptureSessionRuntimeError:(NSError *)error
{
    NSLog( @"fatal runtime error %@, code %i", error, (int)error.code );
    
    _running = NO;
    [self teardownCaptureSession];
    
    @synchronized( self )
    {
        if ( [self.delegate respondsToSelector:@selector(captureService:didStopRunningWithError:)] ) {
            dispatch_async( _delegateCallbackQueue, ^{
                @autoreleasepool {
                    [self.delegate captureService:self didStopRunningWithError:error];
                }
            });
        }
    }
}

- (void)captureSessionDidStopRunning
{
    [self stopRecording]; // does nothing if we aren't currently recording
    [self teardownVideoPipeline];
}

- (void)applicationWillEnterForeground
{
    NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
    
    dispatch_sync( _sessionQueue, ^{
        if ( _startCaptureSessionOnEnteringForeground ) {
            NSLog( @"-[%@ %@] manually restarting session", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
            
            _startCaptureSessionOnEnteringForeground = NO;
            if ( _running ) {
                [_captureSession startRunning];
            }
        }
    } );
}

#pragma mark Capture Pipeline

- (void)setupVideoPipelineWithInputFormatDescription:(CMFormatDescriptionRef)inputFormatDescription
{
    NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
    
    [self videoPipelineWillStartRunning];
    
    self.videoDimensions = CMVideoFormatDescriptionGetDimensions( inputFormatDescription );
//    [_renderer prepareForInputWithFormatDescription:inputFormatDescription outputRetainedBufferCountHint:RETAINED_BUFFER_COUNT];
//    
//    if ( ! _renderer.operatesInPlace && [_renderer respondsToSelector:@selector(outputFormatDescription)] ) {
//        self.outputVideoFormatDescription = _renderer.outputFormatDescription;
//    }
//    else {
        self.outputVideoFormatDescription = inputFormatDescription;
//    }
}

// synchronous, blocks until the pipeline is drained, don't call from within the pipeline
- (void)teardownVideoPipeline
{
    // The session is stopped so we are guaranteed that no new buffers are coming through the video data output.
    // There may be inflight buffers on _videoDataOutputQueue however.
    // Synchronize with that queue to guarantee no more buffers are in flight.
    // Once the pipeline is drained we can tear it down safely.
    
    NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
    
    dispatch_sync( _videoDataOutputQueue, ^{
        if ( ! self.outputVideoFormatDescription ) {
            return;
        }
        
        self.outputVideoFormatDescription = nil;
        self.currentPreviewPixelBuffer = NULL;
        
        NSLog( @"-[%@ %@] finished teardown", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
        
        [self videoPipelineDidFinishRunning];
    } );
}

- (void)videoPipelineWillStartRunning
{
    NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
    
    NSAssert( _pipelineRunningTask == UIBackgroundTaskInvalid, @"should not have a background task active before the video pipeline starts running" );
    
    _pipelineRunningTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        NSLog( @"video capture pipeline background task expired" );
    }];
}

- (void)videoPipelineDidFinishRunning
{
    NSLog( @"-[%@ %@] called", NSStringFromClass([self class]), NSStringFromSelector(_cmd) );
    
    NSAssert( _pipelineRunningTask != UIBackgroundTaskInvalid, @"should have a background task active when the video pipeline finishes running" );
    
    [[UIApplication sharedApplication] endBackgroundTask:_pipelineRunningTask];
    _pipelineRunningTask = UIBackgroundTaskInvalid;
}

// call under @synchronized( self )
- (void)videoPipelineDidRunOutOfBuffers
{
    // We have run out of buffers.
    // Tell the delegate so that it can flush any cached buffers.
    if ( [self.delegate respondsToSelector:@selector(captureServiceDidRunOutOfPreviewBuffers:)] ) {
        dispatch_async( _delegateCallbackQueue, ^{
            @autoreleasepool {
                [self.delegate captureServiceDidRunOutOfPreviewBuffers:self];
            }
        } );
    }
}

// call under @synchronized( self )
- (void)outputPreviewPixelBuffer:(CVPixelBufferRef)previewPixelBuffer
{
    if ( self.delegate )
    {
        // Keep preview latency low by dropping stale frames that have not been picked up by the delegate yet
        self.currentPreviewPixelBuffer = previewPixelBuffer;
        
        dispatch_async( _delegateCallbackQueue, ^{
            @autoreleasepool
            {
                CVPixelBufferRef currentPreviewPixelBuffer = NULL;
                @synchronized( self )
                {
                    currentPreviewPixelBuffer = self.currentPreviewPixelBuffer;
                    if ( currentPreviewPixelBuffer ) {
                        CFRetain( currentPreviewPixelBuffer );
                        self.currentPreviewPixelBuffer = NULL;
                    }
                }
                
                if ( currentPreviewPixelBuffer ) {
                    [self.delegate captureService:self previewPixelBufferReadyForDisplay:currentPreviewPixelBuffer];
                    CFRelease( currentPreviewPixelBuffer );
                }
            }
        } );
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription( sampleBuffer );
    
    if ( connection == _videoConnection )
    {
        if ( self.outputVideoFormatDescription == nil ) {
            // Don't render the first sample buffer.
            // This gives us one frame interval (33ms at 30fps) for setupVideoPipelineWithInputFormatDescription: to complete.
            // Ideally this would be done asynchronously to ensure frames don't back up on slower devices.
            [self setupVideoPipelineWithInputFormatDescription:formatDescription];
        }
        else {
            [self renderVideoSampleBuffer:sampleBuffer];
        }
    }
    else if ( connection == _audioConnection )
    {
        self.outputAudioFormatDescription = formatDescription;
        
        @synchronized( self ) {
            if ( _recordingStatus == WBRecordingStatusRecording ) {
                [self.recorder appendAudioSampleBuffer:sampleBuffer];
            }
        }
    }
}

- (void)renderVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVPixelBufferRef renderedPixelBuffer = NULL;
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp( sampleBuffer );
    
//    [self calculateFramerateAtTimestamp:timestamp];
    
    // We must not use the GPU while running in the background.
    // setRenderingEnabled: takes the same lock so the caller can guarantee no GPU usage once the setter returns.
//    @synchronized( _renderer )
//    {
//        if ( _renderingEnabled ) {
//            CVPixelBufferRef sourcePixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
//            renderedPixelBuffer = (CVPixelBufferRef)CFRetain(sourcePixelBuffer);//[_renderer copyRenderedPixelBuffer:sourcePixelBuffer];
//        }
//        else {
//            return;
//        }
//    }
    if (!self.renderingEnabled) {
        return;
    }
    
    @synchronized( self )
    {
        CVPixelBufferRef sourcePixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
        renderedPixelBuffer = (CVPixelBufferRef)CFRetain(sourcePixelBuffer);
        if ( renderedPixelBuffer )
        {
            [self outputPreviewPixelBuffer:renderedPixelBuffer];
            
            if ( _recordingStatus == WBRecordingStatusRecording ) {
                
                if (CMTimeCompare(_nextPTS, kCMTimeZero) == 0) {
                    //首次进入
                    _nextPTS = CMTimeAdd(timestamp, CMTimeMake(1 * 1000, self.videoFrameRate * 1000));
                } else {
                    //判断时间
                    if (CMTIME_COMPARE_INLINE(timestamp, <, _nextPTS)) {
                        CFRelease( renderedPixelBuffer );
                        return;
                    }
                    _nextPTS = CMTimeAdd(_nextPTS, CMTimeMake(1 * 1000, self.videoFrameRate * 1000));
                }
                
                [self.recorder appendVideoPixelBuffer:renderedPixelBuffer withPresentationTime:timestamp];
            }
            
            CFRelease( renderedPixelBuffer );
        }
        else
        {
            [self videoPipelineDidRunOutOfBuffers];
        }
    }
}

#pragma mark Recording

- (void)startRecording
{
    @synchronized( self )
    {
        if ( _recordingStatus != WBRecordingStatusIdle ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Already recording" userInfo:nil];
            return;
        }
        
        _nextPTS = kCMTimeZero;
        [self transitionToRecordingStatus:WBRecordingStatusStartingRecording error:nil];
    }
    
    WBVideoRecorder *recorder = [[WBVideoRecorder alloc] initWithURL:_recordingURL];
    
    if (self.shouldRecordAudio) {
        [recorder addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:_audioCompressionSettings];
    }
    
    CGAffineTransform videoTransform = [self transformFromVideoBufferOrientationToOrientation:self.recordingOrientation withAutoMirroring:NO]; // Front camera recording shouldn't be mirrored
    
    [recorder addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription transform:videoTransform settings:_videoCompressionSettings];
    
    dispatch_queue_t callbackQueue = dispatch_queue_create( "com.webank.CaptureService.recordercallback", DISPATCH_QUEUE_SERIAL ); // guarantee ordering of callbacks with a serial queue
    [recorder setDelegate:self callbackQueue:callbackQueue];
    self.recorder = recorder;
    _assetURL = nil;
    
    [recorder prepareToRecord]; // asynchronous, will call us back with recorderDidFinishPreparing: or recorder:didFailWithError: when done
}

- (void)stopRecording
{
    @synchronized( self )
    {
        if ( _recordingStatus != WBRecordingStatusRecording ) {
            return;
        }
        
        [self transitionToRecordingStatus:WBRecordingStatusStoppingRecording error:nil];
    }
    
    [self.recorder finishRecording]; // asynchronous, will call us back with recorderDidFinishRecording: or recorder:didFailWithError: when done
}

#pragma mark - Image Capture

- (void)takeOneShotPicture:(WBOneShotCallback)callback
{
    if (_stillImageOutput) {
        AVCaptureConnection *stillImageConnection = [_stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        [_stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
              completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *__strong error) {
                  
                  NSData *imgData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                  UIImage *stillImage = [UIImage imageWithData:imgData];
                  UIImage *outImage = [self imageByRotatingImage:stillImage fromImageOrientation:stillImage.imageOrientation];
                  if (self.shouldSaveToAlbum) {
                      UIImageWriteToSavedPhotosAlbum(outImage, self, @selector(_image:didFinishSavingWithError:contextInfo:), nil);
                  }
                  if (callback) {
                      dispatch_async(_delegateCallbackQueue, ^{
                          callback(outImage ? 0 : -1, outImage);
                      });
                  }
                  
              }
         ];
    } else if (callback) {
        dispatch_async(_delegateCallbackQueue, ^{
            callback(-1, nil);
        });
    }
}

- (void)              _image: (UIImage *) image
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo
{
    if (error) {
        NSLog(@"Save image failed: %@", error.localizedDescription);
    }
}

#pragma mark WBVideoRecorder Delegate

- (void)recorderDidFinishPreparing:(WBVideoRecorder *)recorder
{
    @synchronized( self )
    {
        if ( _recordingStatus != WBRecordingStatusStartingRecording ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Expected to be in StartingRecording state" userInfo:nil];
            return;
        }
        
        [self transitionToRecordingStatus:WBRecordingStatusRecording error:nil];
    }
}

- (void)recorder:(WBVideoRecorder *)recorder didFailWithError:(NSError *)error
{
    @synchronized( self ) {
        self.recorder = nil;
        [self transitionToRecordingStatus:WBRecordingStatusIdle error:error];
    }
}

- (void)recorderDidFinishRecording:(WBVideoRecorder *)recorder
{
    @synchronized( self )
    {
        if ( _recordingStatus != WBRecordingStatusStoppingRecording ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Expected to be in StoppingRecording state" userInfo:nil];
            return;
        }
        
        // No state transition, we are still in the process of stopping.
        // We will be stopped once we save to the assets library.
    }
    
    self.recorder = nil;
    
    //save to photos
    if (self.shouldSaveToAlbum) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:_recordingURL completionBlock:^(NSURL *assetURL, NSError *error) {
            
            _assetURL = assetURL;
            [[NSFileManager defaultManager] removeItemAtURL:_recordingURL error:NULL];
            
            @synchronized( self ) {
                if ( _recordingStatus != WBRecordingStatusStoppingRecording ) {
                    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Expected to be in StoppingRecording state" userInfo:nil];
                    return;
                }
                [self transitionToRecordingStatus:WBRecordingStatusIdle error:error];
            }
        }];
    } else {
        
        [self transitionToRecordingStatus:WBRecordingStatusIdle error:nil];
    }
}

#pragma mark Recording State Machine

// call under @synchonized( self )
- (void)transitionToRecordingStatus:(WBRecordingStatus)newStatus error:(NSError *)error
{
    SEL delegateSelector = NULL;
    WBRecordingStatus oldStatus = _recordingStatus;
    _recordingStatus = newStatus;
    
#if LOG_STATUS_TRANSITIONS
    NSLog( @"WBCaptureService recording state transition: %@->%@", [self stringForRecordingStatus:oldStatus], [self stringForRecordingStatus:newStatus] );
#endif
    
    if ( newStatus != oldStatus )
    {
        if ( error && ( newStatus == WBRecordingStatusIdle ) )
        {
            delegateSelector = @selector(captureService:recordingDidFailWithError:);
        }
        else
        {
            error = nil; // only the above delegate method takes an error
            if ( ( oldStatus == WBRecordingStatusStartingRecording ) && ( newStatus == WBRecordingStatusRecording ) ) {
                delegateSelector = @selector(captureServiceRecordingDidStart:);
            }
            else if ( ( oldStatus == WBRecordingStatusRecording ) && ( newStatus == WBRecordingStatusStoppingRecording ) ) {
                delegateSelector = @selector(captureServiceRecordingWillStop:);
            }
            else if ( ( oldStatus == WBRecordingStatusStoppingRecording ) && ( newStatus == WBRecordingStatusIdle ) ) {
                delegateSelector = @selector(captureServiceRecordingDidStop:);
            }
        }
    }
    
    if ( delegateSelector && self.delegate && [self.delegate respondsToSelector:delegateSelector] )
    {
        dispatch_async( _delegateCallbackQueue, ^{
            @autoreleasepool
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                if ( error ) {
                    [self.delegate performSelector:delegateSelector withObject:self withObject:error];
                }
                else {
                    [self.delegate performSelector:delegateSelector withObject:self];
                }
#pragma clang diagnostic pop
            }
        } );
    }
}

#if LOG_STATUS_TRANSITIONS

- (NSString *)stringForRecordingStatus:(WBRecordingStatus)status
{
    NSString *statusString = nil;
    
    switch ( status )
    {
        case WBRecordingStatusIdle:
            statusString = @"Idle";
            break;
        case WBRecordingStatusStartingRecording:
            statusString = @"StartingRecording";
            break;
        case WBRecordingStatusRecording:
            statusString = @"Recording";
            break;
        case WBRecordingStatusStoppingRecording:
            statusString = @"StoppingRecording";
            break;
        default:
            statusString = @"Unknown";
            break;
    }
    return statusString;
}

#endif // LOG_STATUS_TRANSITIONS

#pragma mark Utilities

// Auto mirroring: Front camera is mirrored; back camera isn't 
- (CGAffineTransform)transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)orientation withAutoMirroring:(BOOL)mirror
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    // Calculate offsets from an arbitrary reference orientation (portrait)
    CGFloat orientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation( orientation );
    CGFloat videoOrientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation( self.videoOrientation );
    
    // Find the difference in angle between the desired orientation and the video orientation
    CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
    transform = CGAffineTransformMakeRotation( angleOffset );
    
    if ( _videoDevice.position == AVCaptureDevicePositionFront )
    {
        if ( mirror ) {
            transform = CGAffineTransformScale( transform, -1, 1 );
        }
        else {
            if ( UIInterfaceOrientationIsPortrait( orientation ) ) {
                transform = CGAffineTransformRotate( transform, M_PI );
            }
        }
    }
    
    return transform;
}

static CGFloat angleOffsetFromPortraitOrientationToOrientation(AVCaptureVideoOrientation orientation)
{
    CGFloat angle = 0.0;
    
    switch ( orientation )
    {
        case AVCaptureVideoOrientationPortrait:
            angle = 0.0;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            angle = -M_PI_2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
        default:
            break;
    }
    
    return angle;
}

- (void)calculateFramerateAtTimestamp:(CMTime)timestamp
{
    [_previousSecondTimestamps addObject:[NSValue valueWithCMTime:timestamp]];
    
    CMTime oneSecond = CMTimeMake( 1, 1 );
    CMTime oneSecondAgo = CMTimeSubtract( timestamp, oneSecond );
    
    while( CMTIME_COMPARE_INLINE( [_previousSecondTimestamps[0] CMTimeValue], <, oneSecondAgo ) ) {
        [_previousSecondTimestamps removeObjectAtIndex:0];
    }
    
    if ( [_previousSecondTimestamps count] > 1 ) {
        const Float64 duration = CMTimeGetSeconds( CMTimeSubtract( [[_previousSecondTimestamps lastObject] CMTimeValue], [_previousSecondTimestamps[0] CMTimeValue] ) );
        const float newRate = (float)( [_previousSecondTimestamps count] - 1 ) / duration;
        self.previewFrameRate = newRate;
    }
}

-(UIImage*)imageByRotatingImage:(UIImage*)initImage fromImageOrientation:(UIImageOrientation)orientation
{
    CGImageRef imgRef = initImage.CGImage;
    
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect bounds = CGRectMake(0, 0, width, height);
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
    CGFloat boundHeight;
    UIImageOrientation orient = orientation;
    switch(orient) {
            
        case UIImageOrientationUp: //EXIF = 1
            return initImage;
            break;
            
        case UIImageOrientationUpMirrored: //EXIF = 2
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
            
        case UIImageOrientationDown: //EXIF = 3
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationDownMirrored: //EXIF = 4
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
            
        case UIImageOrientationLeftMirrored: //EXIF = 5
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationLeft: //EXIF = 6
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationRightMirrored: //EXIF = 7
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        case UIImageOrientationRight: //EXIF = 8
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
            
    }
    // Create the bitmap context
    CGContextRef    context = NULL;
    void *          bitmapData;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    // Declare the number of bytes per row. Each pixel in the bitmap in this
    // example is represented by 4 bytes; 8 bits each of red, green, blue, and
    // alpha.
    bitmapBytesPerRow   = (bounds.size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * bounds.size.height);
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL)
    {
        return nil;
    }
    
    // Create the bitmap context. We want pre-multiplied ARGB, 8-bits
    // per component. Regardless of what the source image format is
    // (CMYK, Grayscale, and so on) it will be converted over to the format
    // specified here by CGBitmapContextCreate.
    CGColorSpaceRef colorspace = CGImageGetColorSpace(imgRef);
    context = CGBitmapContextCreate (bitmapData,bounds.size.width,bounds.size.height,8,bitmapBytesPerRow,
                                     colorspace, kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast);
    
    if (context == NULL)
        // error creating context
        return nil;
    
    CGContextScaleCTM(context, -1.0, -1.0);
    CGContextTranslateCTM(context, -bounds.size.width, -bounds.size.height);
    
    CGContextConcatCTM(context, transform);
    
    // Draw the image to the bitmap context. Once we draw, the memory
    // allocated for the context for rendering will then contain the
    // raw image data in the specified color space.
    CGContextDrawImage(context, CGRectMake(0,0,width, height), imgRef);
    
    CGImageRef imgRef2 = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    free(bitmapData);
    UIImage * image = [UIImage imageWithCGImage:imgRef2 scale:initImage.scale orientation:UIImageOrientationUp];
    CGImageRelease(imgRef2);
    return image;
}

+ (UIImage*)imageWithImage:(UIImage *)image cutToFrame:(CGRect)newFrame
{
    if ([UIImage instancesRespondToSelector:@selector(scale)]) {
        newFrame.origin.x *= image.scale;
        newFrame.origin.y *= image.scale;
        newFrame.size.width *= image.scale;
        newFrame.size.height *= image.scale;
    }
    
    //CGRect newRect = {0,0, newSize.width , newSize.height};
    CGImageRef tmp = CGImageCreateWithImageInRect(image.CGImage, newFrame);
    UIImage* result = [UIImage imageWithCGImage:tmp scale:1.0 orientation:image.imageOrientation];
    CGImageRelease(tmp);
    return result;
}

@end
