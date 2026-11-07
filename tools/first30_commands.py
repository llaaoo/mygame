#!/usr/bin/env python3
"""Send sequential real-input instructions to first30_probe.gd (test tooling only)."""
import argparse
import json
from pathlib import Path
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="GRAYRIVER_FIRST30_OUTPUT of the running probe")
    parser.add_argument("commands", help="JSON object/list, or @path to a JSON file")
    parser.add_argument("--timeout", type=float, default=75)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    raw = Path(args.commands[1:]).read_text() if args.commands.startswith("@") else args.commands
    requests = json.loads(raw)
    if isinstance(requests, dict):
        requests = [requests]
    if not isinstance(requests, list) or not all(isinstance(r, dict) for r in requests):
        parser.error("commands must be an object or list of objects")
    result_path = args.output / "result.json"
    for request in requests:
        previous = json.loads(result_path.read_text()) if result_path.exists() else {}
        request["id"] = int(previous.get("id", 0)) + 1
        temporary = args.output / "request.tmp"
        temporary.write_text(json.dumps(request), encoding="utf-8")
        temporary.replace(args.output / "request.json")
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            try:
                result = json.loads(result_path.read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(0.1)
                continue
            if result.get("id") == request["id"]:
                break
            time.sleep(0.1)
        else:
            raise SystemExit(f"Command timed out: {request}; inspect {args.output / 'runtime.log'}")
        print(json.dumps({"request": request, "error": result["error"],
                          "player": result["player"], "notice": result["notice"]}, ensure_ascii=False))
        if result["error"]:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
