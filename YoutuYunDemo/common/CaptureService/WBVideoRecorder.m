//
//  WBVideoRecorder.m
//  CaptrueServiceDemo
//
//  Created by Sampanweng on 14/12/25.
//  Copyright (c) 2014年 webank. All rights reserved.
//

#import "WBVideoRecorder.h"
#import <AVFoundation/AVFoundation.h>

#define LOG_STATUS_TRANSITIONS 0

typedef NS_ENUM( NSInteger, WBRecorderStatus ) {
    WBRecorderStatusIdle = 0,
    WBRecorderStatusPreparingToRecord,
    WBRecorderStatusRecording,
    WBRecorderStatusFinishingRecordingPart1, // waiting for inflight buffers to be appended
    WBRecorderStatusFinishingRecordingPart2, // calling finish writing on the asset writer
    WBRecorderStatusFinished,	// terminal state
    WBRecorderStatusFailed		// terminal state
}; // internal state machine

@interface WBVideoRecorder ()
{
    WBRecorderStatus _status;
    
    __weak id <WBVideoRecorderDelegate> _delegate; // __weak doesn't actually do anything under non-ARC
    dispatch_queue_t _delegateCallbackQueue;
    
    dispatch_queue_t _writingQueue;
    
    NSURL *_URL;
    
    AVAssetWriter *_assetWriter;
    BOOL _haveStartedSession;
    
    CMFormatDescriptionRef _audioTrackSourceFormatDescription;
    NSDictionary *_audioTrackSettings;
    AVAssetWriterInput *_audioInput;
    
    CMFormatDescriptionRef _videoTrackSourceFormatDescription;
    CGAffineTransform _videoTrackTransform;
    NSDictionary *_videoTrackSettings;
    AVAssetWriterInput *_videoInput;
}

@end

@implementation WBVideoRecorder

- (instancetype)initWithURL:(NSURL *)URL
{
    if ( ! URL ) {
        return nil;
    }
    
    self = [super init];
    if ( self ) {
        _writingQueue = dispatch_queue_create( "com.webank.wbrecorder.writing", DISPATCH_QUEUE_SERIAL );
        _videoTrackTransform = CGAffineTransformIdentity;
        _URL = URL;
    }
    return self;
}

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings
{
    if ( formatDescription == NULL ) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"NULL format description" userInfo:nil];
        return;
    }
    
    @synchronized( self )
    {
        if ( _status != WBRecorderStatusIdle ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot add tracks while not idle" userInfo:nil];
            return;
        }
        
        if ( _videoTrackSourceFormatDescription ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot add more than one video track" userInfo:nil];
            return;
        }
        
        _videoTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain( formatDescription );
        _videoTrackTransform = transform;
        _videoTrackSettings = [videoSettings copy];
    }
}

- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings
{
    if ( formatDescription == NULL ) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"NULL format description" userInfo:nil];
        return;
    }
    
    @synchronized( self )
    {
        if ( _status != WBRecorderStatusIdle ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot add tracks while not idle" userInfo:nil];
            return;
        }
        
        if ( _audioTrackSourceFormatDescription ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot add more than one audio track" userInfo:nil];
            return;
        }
        
        _audioTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain( formatDescription );
        _audioTrackSettings = [audioSettings copy];
    }
}

- (id<WBVideoRecorderDelegate>)delegate
{
    id <WBVideoRecorderDelegate> delegate = nil;
    @synchronized( self ) {
        delegate = _delegate;
    }
    return delegate;
}

- (void)setDelegate:(id<WBVideoRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)delegateCallbackQueue; // delegate is weak referenced
{
    if ( delegate && ( delegateCallbackQueue == NULL ) ) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Caller must provide a delegateCallbackQueue" userInfo:nil];
    }
    
    @synchronized( self )
    {
        _delegate = delegate;
        if ( delegateCallbackQueue != _delegateCallbackQueue  ) {
            _delegateCallbackQueue = delegateCallbackQueue;
        }
    }
}

- (void)prepareToRecord
{
    @synchronized( self )
    {
        if ( _status != WBRecorderStatusIdle ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Already prepared, cannot prepare again" userInfo:nil];
            return;
        }
        
        [self transitionToStatus:WBRecorderStatusPreparingToRecord error:nil];
    }
    
    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0 ), ^{
        
        @autoreleasepool
        {
            NSError *error = nil;
            // AVAssetWriter will not write over an existing file.
            [[NSFileManager defaultManager] removeItemAtURL:_URL error:NULL];
            
            _assetWriter = [[AVAssetWriter alloc] initWithURL:_URL fileType:AVFileTypeQuickTimeMovie error:&error];
            
            // Create and add inputs
            if ( ! error && _videoTrackSourceFormatDescription ) {
                [self setupAssetWriterVideoInputWithSourceFormatDescription:_videoTrackSourceFormatDescription transform:_videoTrackTransform settings:_videoTrackSettings error:&error];
            }
            
            if ( ! error && _audioTrackSourceFormatDescription ) {
                [self setupAssetWriterAudioInputWithSourceFormatDescription:_audioTrackSourceFormatDescription settings:_audioTrackSettings error:&error];
            }
            
            if ( ! error ) {
                BOOL success = [_assetWriter startWriting];
                if ( ! success ) {
                    error = _assetWriter.error;
                }
            }
            
            @synchronized( self )
            {
                if ( error ) {
                    [self transitionToStatus:WBRecorderStatusFailed error:error];
                }
                else {
                    [self transitionToStatus:WBRecorderStatusRecording error:nil];
                }
            }
        }
    } );
}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
}

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime
{
    CMSampleBufferRef sampleBuffer = NULL;
    
    CMSampleTimingInfo timingInfo = {0,};
    timingInfo.duration = kCMTimeInvalid;
    timingInfo.decodeTimeStamp = kCMTimeInvalid;
    timingInfo.presentationTimeStamp = presentationTime;
    
    OSStatus err = CMSampleBufferCreateForImageBuffer( kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, _videoTrackSourceFormatDescription, &timingInfo, &sampleBuffer );
    if ( sampleBuffer ) {
        [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
        CFRelease( sampleBuffer );
    }
    else {
        NSString *exceptionReason = [NSString stringWithFormat:@"sample buffer create failed (%i)", (int)err];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:exceptionReason userInfo:nil];
        return;
    }
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeAudio];
}

- (void)finishRecording
{
    @synchronized( self )
    {
        BOOL shouldFinishRecording = NO;
        switch ( _status )
        {
            case WBRecorderStatusIdle:
            case WBRecorderStatusPreparingToRecord:
            case WBRecorderStatusFinishingRecordingPart1:
            case WBRecorderStatusFinishingRecordingPart2:
            case WBRecorderStatusFinished:
                @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Not recording" userInfo:nil];
                break;
            case WBRecorderStatusFailed:
                // From the client's perspective the movie recorder can asynchronously transition to an error state as the result of an append.
                // Because of this we are lenient when finishRecording is called and we are in an error state.
                NSLog( @"Recording has failed, nothing to do" );
                break;
            case WBRecorderStatusRecording:
                shouldFinishRecording = YES;
                break;
        }
        
        if ( shouldFinishRecording ) {
            [self transitionToStatus:WBRecorderStatusFinishingRecordingPart1 error:nil];
        }
        else {
            return;
        }
    }
    
    dispatch_async( _writingQueue, ^{
        
        @autoreleasepool
        {
            @synchronized( self )
            {
                // We may have transitioned to an error state as we appended inflight buffers. In that case there is nothing to do now.
                if ( _status != WBRecorderStatusFinishingRecordingPart1 ) {
                    return;
                }
                
                // It is not safe to call -[AVAssetWriter finishWriting*] concurrently with -[AVAssetWriterInput appendSampleBuffer:]
                // We transition to WBRecorderStatusFinishingRecordingPart2 while on _writingQueue, which guarantees that no more buffers will be appended.
                [self transitionToStatus:WBRecorderStatusFinishingRecordingPart2 error:nil];
            }
            
            [_assetWriter finishWritingWithCompletionHandler:^{
                @synchronized( self )
                {
                    NSError *error = _assetWriter.error;
                    if ( error ) {
                        [self transitionToStatus:WBRecorderStatusFailed error:error];
                    }
                    else {
                        [self transitionToStatus:WBRecorderStatusFinished error:nil];
                    }
                }
            }];
        }
    } );
}

- (void)dealloc
{
    _delegate = nil;
    _delegateCallbackQueue = nil;
    _writingQueue = nil;
    
    
    [self teardownAssetWriterAndInputs];
    
    if ( _audioTrackSourceFormatDescription ) {
        CFRelease( _audioTrackSourceFormatDescription );
    }
    _audioTrackSettings = nil;
    
    if ( _videoTrackSourceFormatDescription ) {
        CFRelease( _videoTrackSourceFormatDescription );
    }
    _videoTrackSettings = nil;
    _URL = nil;
    
}

#pragma mark -
#pragma mark Internal

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(NSString *)mediaType
{
    if ( sampleBuffer == NULL ) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"NULL sample buffer" userInfo:nil];
        return;
    }
    
    @synchronized( self ) {
        if ( _status < WBRecorderStatusRecording ) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Not ready to record yet" userInfo:nil];
            return;
        }
    }
    
    CFRetain( sampleBuffer );
    dispatch_async( _writingQueue, ^{
        
        @autoreleasepool
        {
            @synchronized( self )
            {
                // From the client's perspective the movie recorder can asynchronously transition to an error state as the result of an append.
                // Because of this we are lenient when samples are appended and we are no longer recording.
                // Instead of throwing an exception we just release the sample buffers and return.
                if ( _status > WBRecorderStatusFinishingRecordingPart1 ) {
                    CFRelease( sampleBuffer );
                    return;
                }
            }
            
            if ( ! _haveStartedSession ) {
                [_assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                _haveStartedSession = YES;
            }
            
            AVAssetWriterInput *input = ( mediaType == AVMediaTypeVideo ) ? _videoInput : _audioInput;
            
            if ( input.readyForMoreMediaData )
            {
                BOOL success = [input appendSampleBuffer:sampleBuffer];
                if ( ! success ) {
                    NSError *error = _assetWriter.error;
                    @synchronized( self ) {
                        [self transitionToStatus:WBRecorderStatusFailed error:error];
                    }
                }
            }
            else
            {
                NSLog( @"%@ input not ready for more media data, dropping buffer", mediaType );
            }
            CFRelease( sampleBuffer );
        }
    } );
}

// call under @synchonized( self )
- (void)transitionToStatus:(WBRecorderStatus)newStatus error:(NSError *)error
{
    BOOL shouldNotifyDelegate = NO;
    
#if LOG_STATUS_TRANSITIONS
    NSLog( @"WBRecorder state transition: %@->%@", [self stringForStatus:_status], [self stringForStatus:newStatus] );
#endif
    
    if ( newStatus != _status )
    {
        // terminal states
        if ( ( newStatus == WBRecorderStatusFinished ) || ( newStatus == WBRecorderStatusFailed ) )
        {
            shouldNotifyDelegate = YES;
            // make sure there are no more sample buffers in flight before we tear down the asset writer and inputs
            
            dispatch_async( _writingQueue, ^{
                [self teardownAssetWriterAndInputs];
                if ( newStatus == WBRecorderStatusFailed ) {
                    [[NSFileManager defaultManager] removeItemAtURL:_URL error:NULL];
                }
            } );
            
#if LOG_STATUS_TRANSITIONS
            if ( error ) {
                NSLog( @"WBRecorder error: %@, code: %i", error, (int)error.code );
            }
#endif
        }
        else if ( newStatus == WBRecorderStatusRecording )
        {
            shouldNotifyDelegate = YES;
        }
        
        _status = newStatus;
    }
    
    if ( shouldNotifyDelegate && self.delegate )
    {
        dispatch_async( _delegateCallbackQueue, ^{
            
            @autoreleasepool
            {
                switch ( newStatus )
                {
                    case WBRecorderStatusRecording:
                        [self.delegate recorderDidFinishPreparing:self];
                        break;
                    case WBRecorderStatusFinished:
                        [self.delegate recorderDidFinishRecording:self];
                        break;
                    case WBRecorderStatusFailed:
                        [self.delegate recorder:self didFailWithError:error];
                        break;
                    default:
                        break;
                }
            }
        } );
    }
}

#if LOG_STATUS_TRANSITIONS

- (NSString *)stringForStatus:(WBRecorderStatus)status
{
    NSString *statusString = nil;
    
    switch ( status )
    {
        case WBRecorderStatusIdle:
            statusString = @"Idle";
            break;
        case WBRecorderStatusPreparingToRecord:
            statusString = @"PreparingToRecord";
            break;
        case WBRecorderStatusRecording:
            statusString = @"Recording";
            break;
        case WBRecorderStatusFinishingRecordingPart1:
            statusString = @"FinishingRecordingPart1";
            break;
        case WBRecorderStatusFinishingRecordingPart2:
            statusString = @"FinishingRecordingPart2";
            break;
        case WBRecorderStatusFinished:
            statusString = @"Finished";
            break;
        case WBRecorderStatusFailed:
            statusString = @"Failed";
            break;
        default:
            statusString = @"Unknown";
            break;
    }
    return statusString;
    
}

#endif // LOG_STATUS_TRANSITIONS

- (BOOL)setupAssetWriterAudioInputWithSourceFormatDescription:(CMFormatDescriptionRef)audioFormatDescription settings:(NSDictionary *)audioSettings error:(NSError **)errorOut
{
    if ( ! audioSettings ) {
        NSLog( @"No audio settings provided, using default settings" );
        audioSettings = @{ AVFormatIDKey : @(kAudioFormatMPEG4AAC) };
    }
    
    if ( [_assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio] )
    {
        _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings sourceFormatHint:audioFormatDescription];
        _audioInput.expectsMediaDataInRealTime = YES;
        
        if ( [_assetWriter canAddInput:_audioInput] )
        {
            [_assetWriter addInput:_audioInput];
        }
        else
        {
            if ( errorOut ) {
                *errorOut = [[self class] cannotSetupInputError];
            }
            return NO;
        }
    }
    else
    {
        if ( errorOut ) {
            *errorOut = [[self class] cannotSetupInputError];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)setupAssetWriterVideoInputWithSourceFormatDescription:(CMFormatDescriptionRef)videoFormatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings error:(NSError **)errorOut
{
    if ( ! videoSettings )
    {
        float bitsPerPixel;
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions( videoFormatDescription );
        int numPixels = dimensions.width * dimensions.height;
        int bitsPerSecond;
        
        NSLog( @"No video settings provided, using default settings" );
        
        // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
        if ( numPixels < ( 640 * 480 ) ) {
            bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
        }
        else {
            bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
        }
        
        bitsPerSecond = numPixels * bitsPerPixel;
        
        NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond), 
                                                 AVVideoExpectedSourceFrameRateKey : @(30),
                                                 AVVideoMaxKeyFrameIntervalKey : @(30) };
        
        videoSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                           AVVideoWidthKey : @(dimensions.width),
                           AVVideoHeightKey : @(dimensions.height),
                           AVVideoCompressionPropertiesKey : compressionProperties };
    }
    
    if ( [_assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo] )
    {
        _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings sourceFormatHint:videoFormatDescription];
        _videoInput.expectsMediaDataInRealTime = YES;
        _videoInput.transform = transform;
        
        if ( [_assetWriter canAddInput:_videoInput] )
        {
            [_assetWriter addInput:_videoInput];
        }
        else
        {
            if ( errorOut ) {
                *errorOut = [[self class] cannotSetupInputError];
            }
            return NO;
        }
    }
    else
    {
        if ( errorOut ) {
            *errorOut = [[self class] cannotSetupInputError];
        }
        return NO;
    }
    
    return YES;
}

+ (NSError *)cannotSetupInputError
{
    NSString *localizedDescription = NSLocalizedString( @"Recording cannot be started", nil );
    NSString *localizedFailureReason = NSLocalizedString( @"Cannot setup asset writer input.", nil );
    NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : localizedDescription,
                                 NSLocalizedFailureReasonErrorKey : localizedFailureReason };
    return [NSError errorWithDomain:@"com.webank.captureservice" code:0 userInfo:errorDict];
}

- (void)teardownAssetWriterAndInputs
{
    _videoInput = nil;
    _audioInput = nil;
    _assetWriter = nil;
}

@end
