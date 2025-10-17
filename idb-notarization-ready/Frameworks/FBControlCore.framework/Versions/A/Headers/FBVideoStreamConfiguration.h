/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Video Stream Encoding Options
 */
typedef NSString *FBVideoStreamEncoding NS_STRING_ENUM;
extern FBVideoStreamEncoding const FBVideoStreamEncodingH264;
extern FBVideoStreamEncoding const FBVideoStreamEncodingBGRA;
extern FBVideoStreamEncoding const FBVideoStreamEncodingMJPEG;
extern FBVideoStreamEncoding const FBVideoStreamEncodingMinicap;

/**
 A configuration for Video Streaming.
 */
@interface FBVideoStreamConfiguration : NSObject <NSCopying>

#pragma mark Initializers

/**
 The Designated Initializer
 
 @param encoding the encoding to use.
 @param framesPerSecond frames per second, or nil to not to apply a filter.
 @param compressionQuality compression quality between 0.0 and 1.0
 @param scaleFactor scale factor between 0.0 and 1.0
 @param keyFrameInterval keyframe interval in frames
 @param h264Profile H.264 profile string
 @param maxBitrate maximum bitrate in kbps
 @param bufferSize buffer size in kbps
 @param allowFrameReordering whether to allow B-frames
 @param realTimeOptimization whether to enable real-time optimization
 @return a new Video Stream Configuration.
 */
- (instancetype)initWithEncoding:(FBVideoStreamEncoding)encoding 
                   framesPerSecond:(nullable NSNumber *)framesPerSecond 
               compressionQuality:(double)compressionQuality 
                      scaleFactor:(double)scaleFactor
                  keyFrameInterval:(nullable NSNumber *)keyFrameInterval
                       h264Profile:(nullable NSString *)h264Profile
                        maxBitrate:(nullable NSNumber *)maxBitrate
                        bufferSize:(nullable NSNumber *)bufferSize
               allowFrameReordering:(BOOL)allowFrameReordering
             realTimeOptimization:(BOOL)realTimeOptimization;

#pragma mark Properties

/**
 The Encoding to use.
 */
@property (nonatomic, copy, readonly) FBVideoStreamEncoding encoding;

/**
 Frames per second, null means no limit will be applied.
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *framesPerSecond;

/**
 Compression quality.
 */
@property (nonatomic, assign, readonly) double compressionQuality;

/**
 Scale factor.
 */
@property (nonatomic, assign, readonly) double scaleFactor;

/**
 Keyframe interval in frames for H.264 encoding.
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *keyFrameInterval;

/**
 H.264 profile level (baseline, main, high).
 */
@property (nonatomic, strong, nullable, readonly) NSString *h264Profile;

/**
 Maximum bitrate in kbps for rate control.
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *maxBitrate;

/**
 Buffer size in kbps for rate control.
 */
@property (nonatomic, strong, nullable, readonly) NSNumber *bufferSize;

/**
 Whether to allow frame reordering (B-frames). NO for streaming optimization.
 */
@property (nonatomic, assign, readonly) BOOL allowFrameReordering;

/**
 Whether to enable real-time encoding optimizations.
 */
@property (nonatomic, assign, readonly) BOOL realTimeOptimization;

#pragma mark Factory Methods

/**
 Creates a default streaming configuration optimized for low latency.
 */
+ (instancetype)streamingConfiguration;

/**
 Creates a configuration optimized for lowest possible latency.
 */
+ (instancetype)lowLatencyConfiguration;

/**
 Creates a configuration optimized for highest quality streaming.
 */
+ (instancetype)highQualityConfiguration;

/**
 Creates a configuration with custom H.264 parameters.
 
 @param keyFrameInterval keyframe interval in frames
 @param profile H.264 profile (baseline/main/high)
 @param maxBitrate maximum bitrate in kbps
 @param fps target frame rate
 @return configured instance
 */
+ (instancetype)h264ConfigurationWithKeyFrameInterval:(NSNumber *)keyFrameInterval
                                              profile:(NSString *)profile
                                           maxBitrate:(NSNumber *)maxBitrate
                                                  fps:(NSNumber *)fps;

/**
 The Default Configuration.
 */
+ (instancetype)defaultConfiguration;

@end

NS_ASSUME_NONNULL_END

