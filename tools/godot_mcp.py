#!/usr/bin/env python3
"""Inspect the local Godot MCP editor bridge using its actual advertised schemas."""
import argparse
import json
import os
from pathlib import Path
import sys
import time
import urllib.request


def payload(result):
    if "structuredContent" in result:
        return result["structuredContent"]
    blocks = [block.get("text", "") for block in result.get("content", []) if block.get("type") == "text"]
    try:
        return json.loads("\n".join(blocks))
    except (ValueError, TypeError):
        return {"output": blocks}


def failed(result):
    value = payload(result)
    return bool(result.get("isError")) or (isinstance(value, dict) and (
        "error" in value or value.get("success") is False or value.get("valid") is False or
        value.get("status") in ["failing", "failed", "error", "no_active_sessions"]))


class Client:
    def __init__(self, url="http://127.0.0.1:9080/mcp", timeout=20):
        self.url, self.timeout = url, timeout
        self.sequence = 0
        self.session = None

    def rpc(self, method, params, notification=False):
        self.sequence += 1
        message = {"jsonrpc": "2.0", "method": method, "params": params}
        if not notification:
            message["id"] = self.sequence
        headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        if os.environ.get("GODOT_MCP_TOKEN"):
            headers["Authorization"] = "Bearer " + os.environ["GODOT_MCP_TOKEN"]
        request = urllib.request.Request(self.url, data=json.dumps(message).encode(), headers=headers)
        with urllib.request.urlopen(request, timeout=self.timeout) as response:
            self.session = response.headers.get("Mcp-Session-Id", self.session)
            if response.status == 204:
                return {}
            if "text/event-stream" in response.headers.get("Content-Type", ""):
                reply = None
                for raw_line in response:
                    line = raw_line.decode("utf-8")
                    if not line.startswith("data:"):
                        continue
                    event = json.loads(line[5:].strip())
                    if event.get("id") == message.get("id"):
                        reply = event
                        break
                if reply is None:
                    raise RuntimeError("MCP stream contained no matching response")
            else:
                body = response.read().decode("utf-8")
                if notification and not body:
                    return {}
                reply = json.loads(body)
        if "error" in reply:
            raise RuntimeError(str(reply["error"]))
        if not notification and reply.get("id") != message["id"]:
            raise RuntimeError("MCP response id does not match the request")
        return reply.get("result", {})

    def initialize(self):
        info = self.rpc("initialize", {"protocolVersion": "2025-11-25", "capabilities": {},
                                       "clientInfo": {"name": "grayriver-inspection", "version": "1"}})
        self.rpc("notifications/initialized", {}, notification=True)
        return info

    def call(self, name, arguments, wait=False):
        tools = self.rpc("tools/list", {}).get("tools", [])
        schema = next((tool for tool in tools if tool["name"] == name), None)
        if not schema:
            raise RuntimeError(f"Tool is not advertised/enabled: {name}")
        arguments = dict(arguments)
        if wait and "timeout_ms" in schema.get("inputSchema", {}).get("properties", {}):
            # Keep one pending request alive throughout polling; never replay a timed-out mutation.
            arguments["timeout_ms"] = max(int(arguments.get("timeout_ms", 0)), int(self.timeout * 1000) + 1000)
        deadline = time.monotonic() + self.timeout
        while True:
            if time.monotonic() >= deadline:
                raise TimeoutError(f"No fresh response from {name}")
            result = self.rpc("tools/call", {"name": name, "arguments": arguments})
            value = payload(result)
            pending = isinstance(value, dict) and value.get("status") in ["pending", "stale"]
            if failed(result) or not pending or not wait:
                return result
            if time.monotonic() >= deadline:
                raise TimeoutError(f"No fresh response from {name}; last status: {value.get('status')}")
            time.sleep(min(0.25, max(0, deadline - time.monotonic())))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=os.environ.get("GODOT_MCP_URL", "http://127.0.0.1:9080/mcp"))
    parser.add_argument("--timeout", type=float, default=20)
    parser.add_argument("--output", type=Path)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("info")
    commands.add_parser("list")
    enable = commands.add_parser("enable")
    enable.add_argument("names", nargs="+")
    call = commands.add_parser("call")
    call.add_argument("name")
    call.add_argument("--arguments", type=json.loads, default={})
    call.add_argument("--wait", action="store_true")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    client = Client(args.url, args.timeout)
    try:
        info = client.initialize()
        if args.command == "info":
            result = {"structuredContent": info}
        elif args.command == "list":
            result = {"structuredContent": client.rpc("tools/list", {})}
        elif args.command == "enable":
            code = 'var core = Engine.get_meta("GodotMCPPlugin")._native_server\n'
            code += 'for name in ' + json.dumps(args.names) + ':\n\tcore.set_tool_enabled(name, true)\n'
            result = client.call("execute_editor_script", {"code": code})
            if not failed(result):
                available = {tool["name"] for tool in client.rpc("tools/list", {}).get("tools", [])}
                missing = [name for name in args.names if name not in available]
                if missing:
                    result = {"isError": True, "structuredContent": {"error": "Tools remain unavailable", "missing": missing}}
        else:
            if not isinstance(args.arguments, dict):
                parser.error("arguments must be a JSON object")
            result = client.call(args.name, args.arguments, args.wait)
    except (OSError, ValueError, RuntimeError, TimeoutError) as error:
        result = {"isError": True, "structuredContent": {"error": str(error)}}
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    sys.stdout.write(output)
    value = payload(result)
    if failed(result):
        return 1
    return 3 if isinstance(value, dict) and value.get("status") in ["pending", "stale"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
