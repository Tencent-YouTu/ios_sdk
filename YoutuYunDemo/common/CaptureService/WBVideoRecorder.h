//
//  WBVideoRecorder.h
//  CaptrueServiceDemo
//
//  Created by Sampanweng on 14/12/25.
//  Copyright (c) 2014年 webank. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMFormatDescription.h>
#import <CoreMedia/CMSampleBuffer.h>

@protocol WBVideoRecorderDelegate;

@interface WBVideoRecorder : NSObject

- (instancetype)initWithURL:(NSURL *)URL;

// Only one audio and video track each are allowed.
- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings; // see AVVideoSettings.h for settings keys/values
- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings; // see AVAudioSettings.h for settings keys/values

- (void)setDelegate:(id<WBVideoRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)delegateCallbackQueue; // delegate is weak referenced

- (void)prepareToRecord; // Asynchronous, might take several hundred milliseconds. When finished the delegate's recorderDidFinishPreparing: or recorder:didFailWithError: method will be called.

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)finishRecording; // Asynchronous, might take several hundred milliseconds. When finished the delegate's recorderDidFinishRecording: or recorder:didFailWithError: method will be called.

@end

@protocol WBVideoRecorderDelegate <NSObject>

@required
- (void)recorderDidFinishPreparing:(WBVideoRecorder *)recorder;
- (void)recorder:(WBVideoRecorder *)recorder didFailWithError:(NSError *)error;
- (void)recorderDidFinishRecording:(WBVideoRecorder *)recorder;

@end
