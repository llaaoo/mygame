"""Protocol/failure tests for the Godot bridge client; no running editor required."""
import importlib.util
import json
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import threading
import unittest

SPEC = importlib.util.spec_from_file_location("godot_mcp", Path(__file__).with_name("godot_mcp.py"))
mcp = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mcp)


class ClientContractTests(unittest.TestCase):
    def setUp(self):
        self.messages = []
        self.tool_results = []
        self.mismatch_id = False
        self.protocol_error = False
        self.stream = False
        fixture = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_POST(self):
                message = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                fixture.messages.append((message, self.headers.get("Mcp-Session-Id")))
                if "id" not in message:
                    self.send_response(204)
                    self.end_headers()
                    return
                if message["method"] == "initialize":
                    result = {"serverInfo": {"name": "fixture"}}
                elif message["method"] == "tools/list":
                    result = {"tools": [{"name": "snapshot", "inputSchema": {"properties": {"timeout_ms": {"type": "integer"}}}}]}
                else:
                    result = fixture.tool_results.pop(0) if fixture.tool_results else {"structuredContent": {"status": "success"}}
                reply = {"jsonrpc": "2.0", "id": -1 if fixture.mismatch_id else message["id"], "result": result}
                if fixture.protocol_error:
                    reply = {"jsonrpc": "2.0", "id": message["id"], "error": {"code": -32601, "message": "unsupported"}}
                raw = json.dumps(reply).encode()
                if fixture.stream:
                    raw = b'data: {"method":"notice"}\n\n' + b"data: " + raw + b"\n\n"
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream" if fixture.stream else "application/json")
                self.send_header("Mcp-Session-Id", "fixture-session")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.close)
        self.client = mcp.Client(f"http://127.0.0.1:{self.server.server_port}/mcp", timeout=2)

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)

    def test_initialization_negotiates_and_preserves_session(self):
        self.assertEqual(self.client.initialize()["serverInfo"]["name"], "fixture")
        self.client.rpc("tools/list", {})
        self.assertEqual(self.messages[1][0]["method"], "notifications/initialized")
        self.assertEqual(self.messages[-1][1], "fixture-session")

    def test_only_advertised_tools_can_be_called(self):
        with self.assertRaisesRegex(RuntimeError, "not advertised"):
            self.client.call("invented_tool", {})
        self.assertFalse(any(m[0]["method"] == "tools/call" for m in self.messages))

    def test_wait_returns_only_fresh_result_and_keeps_one_server_deadline(self):
        self.tool_results = [{"structuredContent": {"status": state}} for state in ["pending", "stale", "success"]]
        result = self.client.call("snapshot", {}, wait=True)
        self.assertEqual(mcp.payload(result)["status"], "success")
        calls = [m[0] for m in self.messages if m[0]["method"] == "tools/call"]
        self.assertEqual(len(calls), 3)
        self.assertTrue(all(m["params"]["arguments"]["timeout_ms"] >= 3000 for m in calls))

    def test_unawaited_pending_is_preserved(self):
        self.tool_results = [{"structuredContent": {"status": "pending"}}]
        self.assertEqual(mcp.payload(self.client.call("snapshot", {}))["status"], "pending")

    def test_failure_payloads_are_recognized_even_without_protocol_error(self):
        for result in [{"isError": True}, {"structuredContent": {"success": False}},
                       {"structuredContent": {"valid": False}}, {"structuredContent": {"status": "failing"}},
                       {"content": [{"type": "text", "text": '{"error":"runtime error"}'}]}]:
            self.assertTrue(mcp.failed(result))
        self.assertFalse(mcp.failed({"structuredContent": {"success": True}}))

    def test_reply_id_mismatch_and_rpc_error_fail(self):
        self.mismatch_id = True
        with self.assertRaisesRegex(RuntimeError, "id does not match"):
            self.client.rpc("tools/list", {})
        self.mismatch_id = False
        self.protocol_error = True
        with self.assertRaisesRegex(RuntimeError, "unsupported"):
            self.client.rpc("tools/list", {})

    def test_event_stream_ignores_notifications_and_matches_reply(self):
        self.stream = True
        self.assertIn("tools", self.client.rpc("tools/list", {}))

    def test_pending_deadline_expires_without_replaying_after_timeout(self):
        self.client.timeout = 0.05
        self.tool_results = [{"structuredContent": {"status": "pending"}}] * 10
        with self.assertRaises(TimeoutError):
            self.client.call("snapshot", {}, wait=True)
        self.assertEqual(sum(m[0]["method"] == "tools/call" for m in self.messages), 1)


if __name__ == "__main__":
    unittest.main()
