/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBVideoStreamConfiguration.h"

FBVideoStreamEncoding const FBVideoStreamEncodingH264 = @"h264";
FBVideoStreamEncoding const FBVideoStreamEncodingBGRA = @"bgra";
FBVideoStreamEncoding const FBVideoStreamEncodingMJPEG = @"mjpeg";
FBVideoStreamEncoding const FBVideoStreamEncodingMinicap = @"minicap";

@implementation FBVideoStreamConfiguration

#pragma mark Initializers

- (instancetype)initWithEncoding:(FBVideoStreamEncoding)encoding 
                   framesPerSecond:(nullable NSNumber *)framesPerSecond 
               compressionQuality:(double)compressionQuality 
                      scaleFactor:(double)scaleFactor
                  keyFrameInterval:(nullable NSNumber *)keyFrameInterval
                       h264Profile:(nullable NSString *)h264Profile
                        maxBitrate:(nullable NSNumber *)maxBitrate
                        bufferSize:(nullable NSNumber *)bufferSize
               allowFrameReordering:(BOOL)allowFrameReordering
             realTimeOptimization:(BOOL)realTimeOptimization
{
  self = [super init];
  if (!self) {
    return nil;
  }

  _encoding = encoding;
  _framesPerSecond = framesPerSecond;
  _compressionQuality = compressionQuality;
  _scaleFactor = scaleFactor;
  _keyFrameInterval = keyFrameInterval;
  _h264Profile = h264Profile;
  _maxBitrate = maxBitrate;
  _bufferSize = bufferSize;
  _allowFrameReordering = allowFrameReordering;
  _realTimeOptimization = realTimeOptimization;

  return self;
}

#pragma mark Factory Methods

+ (instancetype)streamingConfiguration
{
  return [[self alloc] 
    initWithEncoding:FBVideoStreamEncodingH264
     framesPerSecond:@30
   compressionQuality:0.8
         scaleFactor:1.0
     keyFrameInterval:@30  // 1 second at 30fps
          h264Profile:@"baseline"
           maxBitrate:@4000  // 4Mbps
           bufferSize:@2000  // 2MB buffer
    allowFrameReordering:NO   // No B-frames for streaming
  realTimeOptimization:YES];
}

+ (instancetype)lowLatencyConfiguration
{
  return [[self alloc] 
    initWithEncoding:FBVideoStreamEncodingH264
     framesPerSecond:@60
   compressionQuality:0.7
         scaleFactor:1.0
     keyFrameInterval:@15  // More frequent keyframes for faster recovery
          h264Profile:@"baseline"
           maxBitrate:@6000  // Higher bitrate for quality
           bufferSize:@1000  // Smaller buffer for lower latency
    allowFrameReordering:NO   // No B-frames
  realTimeOptimization:YES];
}

+ (instancetype)highQualityConfiguration
{
  return [[self alloc] 
    initWithEncoding:FBVideoStreamEncodingH264
     framesPerSecond:@30
   compressionQuality:0.9
         scaleFactor:1.0
     keyFrameInterval:@60  // Less frequent keyframes for efficiency
          h264Profile:@"high"
           maxBitrate:@8000  // Higher bitrate for quality
           bufferSize:@4000  // Larger buffer
    allowFrameReordering:NO   // Still no B-frames for streaming
  realTimeOptimization:YES];
}

+ (instancetype)h264ConfigurationWithKeyFrameInterval:(NSNumber *)keyFrameInterval
                                              profile:(NSString *)profile
                                           maxBitrate:(NSNumber *)maxBitrate
                                                  fps:(NSNumber *)fps
{
  return [[self alloc] 
    initWithEncoding:FBVideoStreamEncodingH264
     framesPerSecond:fps
   compressionQuality:0.8
         scaleFactor:1.0
     keyFrameInterval:keyFrameInterval
          h264Profile:profile
           maxBitrate:maxBitrate
           bufferSize:@(maxBitrate.integerValue / 2)  // Buffer size = half max bitrate
    allowFrameReordering:NO
  realTimeOptimization:YES];
}

+ (instancetype)defaultConfiguration
{
  return [[self alloc] 
    initWithEncoding:FBVideoStreamEncodingH264
     framesPerSecond:nil
   compressionQuality:0.2
         scaleFactor:1.0
     keyFrameInterval:nil
          h264Profile:nil
           maxBitrate:nil
           bufferSize:nil
    allowFrameReordering:YES  // Default behavior
  realTimeOptimization:NO];
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
  return [[self.class alloc] 
    initWithEncoding:self.encoding
     framesPerSecond:self.framesPerSecond
   compressionQuality:self.compressionQuality
         scaleFactor:self.scaleFactor
     keyFrameInterval:self.keyFrameInterval
          h264Profile:self.h264Profile
           maxBitrate:self.maxBitrate
           bufferSize:self.bufferSize
    allowFrameReordering:self.allowFrameReordering
  realTimeOptimization:self.realTimeOptimization];
}

#pragma mark NSObject

- (BOOL)isEqual:(FBVideoStreamConfiguration *)configuration
{
  if (![configuration isKindOfClass:self.class]) {
    return NO;
  }
  return [self.encoding isEqualToString:configuration.encoding] &&
         (self.framesPerSecond == configuration.framesPerSecond || [self.framesPerSecond isEqualToNumber:configuration.framesPerSecond]) &&
         self.compressionQuality == configuration.compressionQuality &&
         self.scaleFactor == configuration.scaleFactor &&
         (self.keyFrameInterval == configuration.keyFrameInterval || [self.keyFrameInterval isEqualToNumber:configuration.keyFrameInterval]) &&
         (self.h264Profile == configuration.h264Profile || [self.h264Profile isEqualToString:configuration.h264Profile]) &&
         (self.maxBitrate == configuration.maxBitrate || [self.maxBitrate isEqualToNumber:configuration.maxBitrate]) &&
         (self.bufferSize == configuration.bufferSize || [self.bufferSize isEqualToNumber:configuration.bufferSize]) &&
         self.allowFrameReordering == configuration.allowFrameReordering &&
         self.realTimeOptimization == configuration.realTimeOptimization;
}

- (NSUInteger)hash
{
  return self.encoding.hash ^ 
         self.framesPerSecond.hash ^ 
         @(self.compressionQuality).hash ^ 
         @(self.scaleFactor).hash ^
         self.keyFrameInterval.hash ^
         self.h264Profile.hash ^
         self.maxBitrate.hash ^
         self.bufferSize.hash ^
         @(self.allowFrameReordering).hash ^
         @(self.realTimeOptimization).hash;
}

- (NSString *)description
{
  return [NSString stringWithFormat:
    @"Encoding %@ | FPS %@ | Quality %f | Scale %f | KeyFrame %@ | Profile %@ | Bitrate %@ | Buffer %@ | NoReorder %@ | RealTime %@",
    self.encoding,
    self.framesPerSecond,
    self.compressionQuality,
    self.scaleFactor,
    self.keyFrameInterval,
    self.h264Profile,
    self.maxBitrate,
    self.bufferSize,
    @(self.allowFrameReordering),
    @(self.realTimeOptimization)];
}

@end
