/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import CompanionLib
import FBSimulatorControl
import GRPC
import IDBCompanionUtilities
import IDBGRPCSwift

struct VideoStreamMethodHandler {

  let target: FBiOSTarget
  let targetLogger: FBControlCoreLogger
  let commandExecutor: FBIDBCommandExecutor

  func handle(requestStream: GRPCAsyncRequestStream<Idb_VideoStreamRequest>, responseStream: GRPCAsyncResponseStreamWriter<Idb_VideoStreamResponse>, context: GRPCAsyncServerCallContext) async throws {
    @Atomic var finished = false

    guard case let .start(start) = try await requestStream.requiredNext.control
    else { throw GRPCStatus(code: .failedPrecondition, message: "Expected start control") }

    let videoStream = try await startVideoStream(
      request: start,
      responseStream: responseStream,
      finished: _finished)

    let observeClientCancelStreaming = Task<Void, Error> {
      for try await request in requestStream {
        switch request.control {
        case .start:
          throw GRPCStatus(code: .failedPrecondition, message: "Video streaming already started")
        case .stop:
          return
        case .none:
          throw GRPCStatus(code: .invalidArgument, message: "Client should not close request stream explicitly, send `stop` frame first")
        }
      }
    }

    let observeVideoStreamStop = Task<Void, Error> {
      try await BridgeFuture.await(videoStream.completed)
    }

    try await Task.select(observeClientCancelStreaming, observeVideoStreamStop).value

    try await BridgeFuture.await(videoStream.stopStreaming())
    targetLogger.log("The video stream is terminated")
  }

  private func startVideoStream(request start: Idb_VideoStreamRequest.Start, responseStream: GRPCAsyncResponseStreamWriter<Idb_VideoStreamResponse>, finished: Atomic<Bool>) async throws -> FBVideoStream {
    let consumer: FBDataConsumer

    if start.filePath.isEmpty {
      let responseWriter = FIFOStreamWriter(stream: responseStream)

      consumer = FBBlockDataConsumer.asynchronousDataConsumer { data in
        guard !finished.wrappedValue else { return }
        let response = Idb_VideoStreamResponse.with {
          $0.payload.data = data
        }
        do {
          try responseWriter.send(response)
        } catch {
          finished.set(true)
        }
      }
    } else {
      consumer = try FBFileWriter.syncWriter(forFilePath: start.filePath)
    }

    // Parse enhanced streaming parameters from protobuf
    let config = try buildStreamConfiguration(from: start)
    
    // Log the enhanced configuration for debugging
    targetLogger.log("Enhanced H.264 streaming configuration:")
    targetLogger.log("  Keyframe interval: \(config.keyFrameInterval?.intValue ?? 30)")
    targetLogger.log("  H.264 profile: \(config.h264Profile ?? "baseline")")
    targetLogger.log("  Max bitrate: \(config.maxBitrate?.intValue ?? 4000000) bps")
    targetLogger.log("  Buffer size: \(config.bufferSize?.intValue ?? 2000000) bps")
    targetLogger.log("  Frame reordering: \(config.allowFrameReordering)")
    targetLogger.log("  Real-time optimization: \(config.realTimeOptimization)")

    let videoStream = try await BridgeFuture.value(target.createStream(with: config))

    try await BridgeFuture.await(videoStream.startStreaming(consumer))

    return videoStream
  }

  private func buildStreamConfiguration(from start: Idb_VideoStreamRequest.Start) throws -> FBVideoStreamConfiguration {
    let framesPerSecond = start.fps > 0 ? NSNumber(value: start.fps) : nil
    let encoding = try streamEncoding(from: start.format)
    
    // Enhanced H.264 parameters from protobuf
    let keyFrameInterval: NSNumber = {
      if start.keyframeInterval > 0 {
        return NSNumber(value: start.keyframeInterval)
      } else if start.keyFrameRate > 0 {
        // Fallback to legacy field if new field not set
        return NSNumber(value: start.keyFrameRate)
      } else {
        return NSNumber(value: 30) // Default: 30 frames
      }
    }()
    
    // H.264 profile mapping
    let h264Profile: String = {
      switch start.h264Profile {
      case .baseline:
        return "baseline"
      case .main:
        return "main"
      case .high:
        return "high"
      case .UNRECOGNIZED(_):
        return "baseline" // Safe default
      }
    }()
    
    // Bitrate configuration
    let maxBitrate: NSNumber = {
      if start.maxBitrate > 0 {
        return NSNumber(value: start.maxBitrate * 1000) // Convert kbps to bps
      } else if start.avgBitrate > 0 {
        // Fallback to legacy avgBitrate field
        return NSNumber(value: start.avgBitrate)
      } else {
        return NSNumber(value: 4_000_000) // Default: 4 Mbps
      }
    }()
    
    let bufferSize: NSNumber = {
      if start.bufferSize > 0 {
        return NSNumber(value: start.bufferSize * 1000) // Convert kbps to bps
      } else {
        // Default buffer size: half of max bitrate for good balance
        return NSNumber(value: maxBitrate.intValue / 2)
      }
    }()
    
    // Apply preset configurations if specified
    let finalConfig = applyPresetIfNeeded(
      preset: start.preset,
      keyFrameInterval: keyFrameInterval,
      h264Profile: h264Profile,
      maxBitrate: maxBitrate,
      bufferSize: bufferSize,
      allowFrameReordering: start.allowFrameReordering,
      realTimeOptimization: start.realtimeOptimization
    )
    
    // Create the enhanced configuration
    let config = FBVideoStreamConfiguration(
      encoding: encoding,
      framesPerSecond: framesPerSecond,
      compressionQuality: Double(start.compressionQuality),
      scaleFactor: Double(start.scaleFactor),
      keyFrameInterval: finalConfig.keyFrameInterval,
      h264Profile: finalConfig.h264Profile,
      maxBitrate: finalConfig.maxBitrate,
      bufferSize: finalConfig.bufferSize,
      allowFrameReordering: finalConfig.allowFrameReordering,
      realTimeOptimization: finalConfig.realTimeOptimization
    )

    return config
  }
  
  private struct StreamConfigValues {
    let keyFrameInterval: NSNumber
    let h264Profile: String
    let maxBitrate: NSNumber
    let bufferSize: NSNumber
    let allowFrameReordering: Bool
    let realTimeOptimization: Bool
  }
  
  private func applyPresetIfNeeded(
    preset: Idb_VideoStreamRequest.StreamingPreset,
    keyFrameInterval: NSNumber,
    h264Profile: String,
    maxBitrate: NSNumber,
    bufferSize: NSNumber,
    allowFrameReordering: Bool,
    realTimeOptimization: Bool
  ) -> StreamConfigValues {
    
    switch preset {
    case .streaming:
      return StreamConfigValues(
        keyFrameInterval: NSNumber(value: 30),
        h264Profile: "baseline",
        maxBitrate: NSNumber(value: 4_000_000), // 4 Mbps
        bufferSize: NSNumber(value: 2_000_000),  // 2 Mbps buffer
        allowFrameReordering: false,             // No B-frames for streaming
        realTimeOptimization: true
      )
    
    case .lowLatency:
      return StreamConfigValues(
        keyFrameInterval: NSNumber(value: 15),
        h264Profile: "baseline",
        maxBitrate: NSNumber(value: 6_000_000), // 6 Mbps
        bufferSize: NSNumber(value: 1_000_000),  // 1 Mbps buffer
        allowFrameReordering: false,             // No B-frames for low latency
        realTimeOptimization: true
      )
    
    case .highQuality:
      return StreamConfigValues(
        keyFrameInterval: NSNumber(value: 60),
        h264Profile: "high",
        maxBitrate: NSNumber(value: 8_000_000), // 8 Mbps
        bufferSize: NSNumber(value: 4_000_000),  // 4 Mbps buffer
        allowFrameReordering: false,             // Still no B-frames for streaming use case
        realTimeOptimization: true
      )
    
    case .custom, .UNRECOGNIZED(_):
      // Use the individual parameters provided
      return StreamConfigValues(
        keyFrameInterval: keyFrameInterval,
        h264Profile: h264Profile,
        maxBitrate: maxBitrate,
        bufferSize: bufferSize,
        allowFrameReordering: allowFrameReordering,
        realTimeOptimization: realTimeOptimization
      )
    }
  }

  private func streamEncoding(from requestFormat: Idb_VideoStreamRequest.Format) throws -> FBVideoStreamEncoding {
    switch requestFormat {
    case .h264:
      return .H264
    case .rbga:
      return .BGRA
    case .mjpeg:
      return .MJPEG
    case .minicap:
      return .minicap
    case .i420, .UNRECOGNIZED:
      throw GRPCStatus(code: .invalidArgument, message: "Unrecognized video format")
    }
  }
}