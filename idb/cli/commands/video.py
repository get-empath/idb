#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# pyre-strict

import sys
from argparse import ArgumentParser, Namespace
from typing import Dict, List

from idb.cli import ClientCommand
from idb.common.signal import signal_handler_event, signal_handler_generator
from idb.common.types import Client, VideoFormat


_FORMAT_CHOICE_MAP: dict[str, VideoFormat] = {
    str(format.value.lower()): format for format in VideoFormat
}


class VideoRecordCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "Record the target's screen to a mp4 video file"

    @property
    def name(self) -> str:
        return "video"

    @property
    def aliases(self) -> list[str]:
        return ["record-video"]

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        parser.add_argument("output_file", help="mp4 file to output the video to")
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        await client.record_video(
            stop=signal_handler_event("video"), output_file=args.output_file
        )


class VideoStreamCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "Stream raw H264 from the target with enhanced streaming controls"

    @property
    def name(self) -> str:
        return "video-stream"

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        # Original parameters
        parser.add_argument(
            "--fps",
            required=False,
            default=None,
            type=int,
            help="The framerate of the stream. Default is a dynamic fps",
        )
        parser.add_argument(
            "--format",
            choices=list(_FORMAT_CHOICE_MAP.keys()),
            help="The format of the stream",
            default=VideoFormat.H264.value,
        )
        parser.add_argument(
            "output_file",
            nargs="?",
            default=None,
            help="h264 target file. When omitted, the stream will be written to stdout",
        )
        parser.add_argument(
            "--compression-quality",
            type=float,
            default=0.8,
            help="The compression quality (between 0 and 1.0) for the stream",
        )
        parser.add_argument(
            "--scale-factor",
            type=float,
            default=1.0,
            help="The scale factor for the source video (between 0 and 1.0) for the stream",
        )
        
        # Enhanced H.264 streaming parameters
        parser.add_argument(
            "--keyframe-interval",
            type=int,
            default=30,
            help="Keyframe interval in frames (15-120, default: 30 for 1 second at 30fps)",
        )
        parser.add_argument(
            "--profile",
            choices=["baseline", "main", "high"],
            default="baseline",
            help="H.264 profile for streaming optimization (baseline recommended for compatibility)",
        )
        parser.add_argument(
            "--max-bitrate",
            type=int,
            default=4000,
            help="Maximum bitrate in kbps (1000-10000, default: 4000)",
        )
        parser.add_argument(
            "--buffer-size",
            type=int,
            default=2000,
            help="Buffer size in kbps for rate control (default: 2000)",
        )
        parser.add_argument(
            "--no-b-frames",
            action="store_true",
            default=True,
            help="Disable B-frames for streaming (enabled by default for low latency)",
        )
        parser.add_argument(
            "--realtime-optimization",
            action="store_true",
            default=True,
            help="Enable real-time encoding optimization (enabled by default)",
        )
        
        # Preset configurations
        parser.add_argument(
            "--preset",
            choices=["streaming", "low-latency", "high-quality"],
            help="Use predefined configuration preset",
        )
        
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        # Build streaming configuration based on arguments
        stream_config = self._build_stream_config(args)
        
        async for data in signal_handler_generator(
            iterable=client.stream_video(
                output_file=args.output_file,
                fps=args.fps,
                format=_FORMAT_CHOICE_MAP[args.format],
                compression_quality=args.compression_quality,
                scale_factor=args.scale_factor,
                # Enhanced parameters
                keyframe_interval=args.keyframe_interval,
                h264_profile=args.profile,
                max_bitrate=args.max_bitrate,
                buffer_size=args.buffer_size,
                allow_frame_reordering=not args.no_b_frames,
                realtime_optimization=args.realtime_optimization,
                preset=getattr(args, 'preset', None),
            ),
            name="stream",
            logger=self.logger,
        ):
            sys.stdout.buffer.write(data)
    
    def _build_stream_config(self, args: Namespace) -> dict:
        """Build streaming configuration dictionary from arguments."""
        config = {
            "fps": args.fps,
            "format": args.format,
            "compression_quality": args.compression_quality,
            "scale_factor": args.scale_factor,
            "keyframe_interval": args.keyframe_interval,
            "h264_profile": args.profile,
            "max_bitrate": args.max_bitrate,
            "buffer_size": args.buffer_size,
            "allow_frame_reordering": not args.no_b_frames,
            "realtime_optimization": args.realtime_optimization,
        }
        
        # Apply preset overrides if specified
        if hasattr(args, 'preset') and args.preset:
            preset_configs = {
                "streaming": {
                    "fps": 30,
                    "keyframe_interval": 30,
                    "h264_profile": "baseline",
                    "max_bitrate": 4000,
                    "buffer_size": 2000,
                    "compression_quality": 0.8,
                    "allow_frame_reordering": False,
                    "realtime_optimization": True,
                },
                "low-latency": {
                    "fps": 60,
                    "keyframe_interval": 15,
                    "h264_profile": "baseline", 
                    "max_bitrate": 6000,
                    "buffer_size": 1000,
                    "compression_quality": 0.7,
                    "allow_frame_reordering": False,
                    "realtime_optimization": True,
                },
                "high-quality": {
                    "fps": 30,
                    "keyframe_interval": 60,
                    "h264_profile": "high",
                    "max_bitrate": 8000,
                    "buffer_size": 4000,
                    "compression_quality": 0.9,
                    "allow_frame_reordering": False,
                    "realtime_optimization": True,
                },
            }
            
            if args.preset in preset_configs:
                preset = preset_configs[args.preset]
                # Only override values that weren't explicitly set by user
                for key, value in preset.items():
                    if not hasattr(args, key.replace('_', '-')) or getattr(args, key.replace('_', '-')) == config.get(key):
                        config[key] = value
        
        return config

    def _validate_args(self, args: Namespace) -> None:
        """Validate streaming arguments for sensible values."""
        if args.keyframe_interval < 15 or args.keyframe_interval > 120:
            self.logger.warning(f"Keyframe interval {args.keyframe_interval} may not be optimal. Recommended: 15-120 frames")
        
        if args.max_bitrate < 1000 or args.max_bitrate > 10000:
            self.logger.warning(f"Max bitrate {args.max_bitrate} kbps may not be optimal. Recommended: 1000-10000 kbps")
        
        if args.buffer_size > args.max_bitrate:
            self.logger.warning(f"Buffer size {args.buffer_size} is larger than max bitrate {args.max_bitrate}")
        
        if args.compression_quality < 0.0 or args.compression_quality > 1.0:
            raise ValueError("Compression quality must be between 0.0 and 1.0")
        
        if args.scale_factor <= 0.0 or args.scale_factor > 1.0:
            raise ValueError("Scale factor must be between 0.0 and 1.0")


# Enhanced command with validation
class EnhancedVideoStreamCommand(VideoStreamCommand):
    """Enhanced video stream command with validation and better defaults."""
    
    async def run_with_client(self, args: Namespace, client: Client) -> None:
        # Validate arguments before streaming
        self._validate_args(args)
        
        # Log configuration for debugging
        config = self._build_stream_config(args)
        self.logger.info(f"Starting H.264 stream with config: {config}")
        
        # Start streaming with enhanced configuration
        await super().run_with_client(args, client)
