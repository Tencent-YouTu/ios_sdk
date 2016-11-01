//
//  WBCaptureService.h
//  CaptrueServiceDemo
//
//  Created by Sampanweng on 14/12/24.
//  Copyright (c) 2014年 webank. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

typedef void (^WBOneShotCallback)(int result, UIImage *image); //result 0 means successed, otherwise we got an error.

typedef NS_ENUM(NSUInteger, WBCaptureType) {
    WBCaptureType_Video,
    WBCaptureType_Image,
    WBCaptureType_Count,
};

@protocol WBCaptureServiceDelegate;

@interface WBCaptureService : NSObject

/**
 *	@brief	Set the callback delegate and callback queue.
 *
 *	@param 	delegate 	 delegate is weak referenced
 *	@param 	delegateCallbackQueue 	callback queue
 *
 */
- (void)setDelegate:(id<WBCaptureServiceDelegate>)delegate callbackQueue:(dispatch_queue_t)delegateCallbackQueue;


/**
 *	@brief	Start capture session. Call this method first when you need a preview or recording.
 *  These methods are synchronous.
 *
 */
- (void)startRunning;

/**
 *	@brief	Stop capture session. These methods are synchronous.
 *
 */
- (void)stopRunning;

/**
 *	@brief	Starting record.
 *  Must be running before starting recording.
 *  These methods are asynchronous, see the recording delegate callbacks.
 *
 */
- (void)startRecording;

/**
 *	@brief	Stop recording.
 *  These methods are asynchronous, see the recording delegate callbacks.
 *
 */
- (void)stopRecording;

/**
 *	@brief	only valid after startRunning has been called
 *
 *	@param 	orientation 	New video orientation for video.
 *	@param 	mirroring 	Should mirror
 *
 *	@return	CGAffineTransform for view or layer.
 */
- (CGAffineTransform)transformFromVideoBufferOrientationToOrientation:(AVCaptureVideoOrientation)orientation withAutoMirroring:(BOOL)mirroring;

/**
 *	@brief	Take picture from current preview session.
 *
 *	@param 	callback 	Callback when take picture done.
 */
- (void)takeOneShotPicture:(WBOneShotCallback)callback;

/**
 *  @brief Cut origin image to desired frame.
 *
 *  @param image    The origin image.
 */
+ (UIImage*)imageWithImage:(UIImage *)image cutToFrame:(CGRect)newFrame;


/**
 *	@brief	Regiter a oneshot image callback.
 *          If successed, result will be set 0 while jpeg from preview pixel buffer.
 */
//- (void)registerOneShotCallback:(WBOneShotCallback)oneShotCallback;

/**
 *	@brief	When set to false the GPU will not be used after the setRenderingEnabled: call returns.
 */
@property (atomic, assign) BOOL renderingEnabled;

/**
 *	@brief	Client can set the orientation for the recorded movie
 */
@property (nonatomic, readwrite) AVCaptureVideoOrientation recordingOrientation;

// Stats
/**
 *	@brief	Set and get FPS(frame rate per seconds). Default 30fps.
 */
@property (nonatomic, assign) float videoFrameRate;

/**
 *	@brief	Get current video dimensions. Default is 640X480.
 */
@property (nonatomic, readonly) CMVideoDimensions videoDimensions;

/**
 *	@brief	Get preview layer after capture session has started.
 */
@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;

/**
 *	@brief	Get the temporary video file path.
 */
@property (nonatomic, strong) NSURL *recordingURL;

/**
 *	@brief	AssetURL of saved video in photo album.
 */
@property (nonatomic, readonly) NSURL *assetURL;

/**
 *	@brief	Set the prefered camera device position. Default is AVCaptureDevicePositionFront.
 */
@property (nonatomic, assign) AVCaptureDevicePosition preferedDevicePosition;

/**
 *	@brief	Should record audio. Default is NO.
 */
@property (nonatomic, assign) BOOL shouldRecordAudio;

/**
 *	@brief	Should save video to local album. Default is NO.
 */
@property (nonatomic, assign) BOOL shouldSaveToAlbum;

/**
 *	@brief	Capture type. Default is WBCaptureType_Video.
 */
@property (nonatomic, assign) WBCaptureType captureType;

/**
 *  @brief  AVCaptureSessionPresent.
 */
@property (nonatomic, strong) NSString *sessionPresent;

@end

@protocol WBCaptureServiceDelegate <NSObject>
@optional

- (void)captureService:(WBCaptureService *)captureService didStopRunningWithError:(NSError *)error;

// Preview
- (void)captureService:(WBCaptureService *)captureService previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer;
- (void)captureServiceDidRunOutOfPreviewBuffers:(WBCaptureService *)captureService;

// Recording
- (void)captureServiceRecordingDidStart:(WBCaptureService *)captureService;
- (void)captureService:(WBCaptureService *)captureService recordingDidFailWithError:(NSError *)error; // Can happen at any point after a startRecording call, for example: startRecording->didFail (without a didStart), willStop->didFail (without a didStop)
- (void)captureServiceRecordingWillStop:(WBCaptureService *)captureService;
- (void)captureServiceRecordingDidStop:(WBCaptureService *)captureService;

@end
