#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# pyre-strict

import asyncio
import json
import sys
from argparse import ArgumentParser, Namespace
from typing import AsyncIterator, Dict, Any

from idb.cli import ClientCommand
from idb.common.types import Client, HIDButtonType, HIDEvent, HIDPress, HIDTouch, HIDDirection, Point


class TapCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "Tap On the Screen"

    @property
    def name(self) -> str:
        return "tap"

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        parser.add_argument("x", help="The x-coordinate", type=int)
        parser.add_argument("y", help="The y-coordinate", type=int)
        parser.add_argument("--duration", help="Press duration", type=float)
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        await client.tap(x=args.x, y=args.y, duration=args.duration)


class ButtonCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "A single press of a button"

    @property
    def name(self) -> str:
        return "button"

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        parser.add_argument(
            "button",
            help="The button name",
            choices=[button.name for button in HIDButtonType],
            type=str,
        )
        parser.add_argument("--duration", help="Press duration", type=float)
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        await client.button(
            button_type=HIDButtonType[args.button], duration=args.duration
        )


class KeyCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "A short press of a keycode"

    @property
    def name(self) -> str:
        return "key"

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        parser.add_argument("key", help="The key code", type=int)
        parser.add_argument("--duration", help="Press duration", type=float)
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        await client.key(keycode=args.key, duration=args.duration)


class KeySequenceCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "A sequence of short presses of a keycode"

    @property
    def name(self) -> str:
        return "key-sequence"

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        parser.add_argument(
            "key_sequence",
            help="list of space separated key codes string (i.e. 1 2 3))",
            nargs="*",
        )
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        await client.key_sequence(key_sequence=list(map(int, args.key_sequence)))


class TextCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "Input text"

    @property
    def name(self) -> str:
        return "text"

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        parser.add_argument("text", help="Text to input", type=str)
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        await client.text(text=args.text)


class SwipeCommand(ClientCommand):
    @property
    def description(self) -> str:
        return "Swipe from one point to another point"

    @property
    def name(self) -> str:
        return "swipe"

    def add_parser_arguments(self, parser: ArgumentParser) -> None:
        parser.add_argument(
            "x_start", help="The x-coordinate of the swipe start point", type=int
        )
        parser.add_argument(
            "y_start", help="The y-coordinate of the swipe start point", type=int
        )
        parser.add_argument(
            "x_end", help="The x-coordinate of the swipe end point", type=int
        )
        parser.add_argument(
            "y_end", help="The y-coordinate of the swipe end point", type=int
        )

        parser.add_argument("--duration", help="Swipe duration", type=float)

        parser.add_argument(
            "--delta",
            dest="delta",
            help="delta in pixels between every touch point on the line "
            "between start and end points",
            type=int,
            required=False,
        )
        super().add_parser_arguments(parser)

    async def run_with_client(self, args: Namespace, client: Client) -> None:
        await client.swipe(
            p_start=(args.x_start, args.y_start),
            p_end=(args.x_end, args.y_end),
            duration=args.duration,
            delta=args.delta,
        )


class StreamTouchCommand(ClientCommand):
    @property
    def name(self) -> str:
        return "stream-touch"
    
    @property 
    def description(self) -> str:
        return "Stream touch events from stdin to simulator"
        
    async def run_with_client(self, args: Namespace, client: Client) -> None:
        """Run the streaming touch command."""
        try:
            await client.hid(self.read_touch_events_from_stdin())
        except KeyboardInterrupt:
            self.logger.info("Stream interrupted by user")
        except Exception as e:
            self.logger.error(f"Streaming error: {e}")
            raise
    
    async def read_touch_events_from_stdin(self) -> AsyncIterator[HIDEvent]:
        """Read JSON touch events from stdin and convert to HIDEvent stream."""
        loop = asyncio.get_event_loop()
        
        self.logger.info("Starting touch event stream from stdin...")
        
        while True:
            try:
                # Read line from stdin asynchronously
                line = await loop.run_in_executor(None, sys.stdin.readline)
                if not line:  # EOF
                    self.logger.info("Received EOF, ending stream")
                    break
                    
                line = line.strip()
                if not line:
                    continue
                    
                # Parse JSON event
                try:
                    event_dict = json.loads(line)
                except json.JSONDecodeError as e:
                    self.logger.warning(f"Invalid JSON: {e}")
                    continue
                
                # Convert and yield HID event
                try:
                    hid_event = self.convert_touch_event_to_hid(event_dict)
                    yield hid_event
                except Exception as e:
                    self.logger.warning(f"Failed to convert event: {e}")
                    continue
                    
            except Exception as e:
                self.logger.error(f"Error reading stdin: {e}")
                break
    
    def convert_touch_event_to_hid(self, event: Dict[str, Any]) -> HIDEvent:
        """Convert JSON touch event to HIDEvent."""
        # Validate required fields
        if not all(key in event for key in ['type', 'x', 'y']):
            raise ValueError(f"Missing required fields in event: {event}")
        
        # Create touch point
        point = Point(x=float(event["x"]), y=float(event["y"]))
        touch = HIDTouch(point=point)
        
        # Map event types to HID directions
        direction_map = {
            "touch_start": HIDDirection.DOWN,
            "touch_move": HIDDirection.DOWN,  # Continuous press while moving
            "touch_end": HIDDirection.UP
        }
        
        event_type = event["type"]
        if event_type not in direction_map:
            raise ValueError(f"Unknown touch event type: {event_type}")
        
        direction = direction_map[event_type]
        
        return HIDPress(action=touch, direction=direction)