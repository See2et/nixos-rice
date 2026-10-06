"""Native Pi browser/CLI regression smoke; isolated config, local page, no inference."""
import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="pi-browser-smoke-") as temporary:
    base = Path(temporary)
    agent = base / "agent"
    agent.mkdir()
    (agent / "settings.json").write_text(json.dumps({"defaultTools": ["+codemode", "+web_enable"], "retry": {"enabled": False}}))
    env = dict(os.environ, HOME=str(base), PI_CODING_AGENT_DIR=str(agent), PI_OFFLINE="1")
    # Subcommands must be recognized before injected -e session flags.
    subprocess.run([binary, "mcp", "add", "fixture", "--url", "http://127.0.0.1:1/mcp"], env=env, check=True, capture_output=True)
    assert json.loads((agent / "mcp.json").read_text())["mcpServers"]["fixture"]["url"] == "http://127.0.0.1:1/mcp"
    subprocess.run([binary, "mcp", "remove", "fixture"], env=env, check=True, capture_output=True)

    class Page(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            body = b"<!doctype html><title>Pi browser smoke</title><main><h1>LOCAL_BROWSER_MARKER</h1><button>Smoke button</button></main>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Page)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_port}/"
    fixture = base / "fixture.ts"
    fixture.write_text('''
import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
export default function(pi) {
  let turn = 0;
  pi.on("agent_settled", (_event, ctx) => ctx.shutdown());
  pi.on("before_agent_start", () => {
    const names = pi.getAllTools().map(t => t.name);
    for (const n of ["browser_session", "browser", "browser_web_search", "web_fetch", "web_enable", "astraeus_workflow"]) {
      if (names.filter(x => x === n).length !== 1) throw new Error("Missing/duplicate tool " + n);
    }
    // web-access exposes its enable tool indirectly by default. This fixture
    // explicitly activates it to test coexistence without making a web request.
    pi.setActiveTools([...new Set([...pi.getActiveTools(), "web_enable"])]);
  });
  pi.registerProvider("browser-smoke", {
    api: "fixture-api", apiKey: "local-fixture", baseUrl: "http://invalid.local",
    models: [{id:"stub",name:"Fixture",reasoning:false,input:["text"],cost:{input:0,output:0,cacheRead:0,cacheWrite:0},contextWindow:32000,maxTokens:4000}],
    streamSimple(model, context) {
      const stream = createAssistantMessageEventStream();
      let content, stopReason;
      const steps = [
        ["browser_session", {action:"open",url:URL}],
        ["browser", {action:"snapshot"}],
        ["browser", {action:"screenshot"}],
        ["browser_session", {action:"close"}],
        ["web_enable", {}],
      ];
      const results = context.messages.filter(m=>m.role==="toolResult");
      if (results.some(m=>m.isError)) throw new Error("Browser tool failed: " + JSON.stringify(results).slice(-5000));
      if (turn === 2 && !JSON.stringify(results.at(-1)).includes("LOCAL_BROWSER_MARKER")) throw new Error("Local snapshot marker missing");
      if (turn === 3 && !results.at(-1)?.content.some(c=>c.type==="image")) throw new Error("JPEG attachment missing");
      if (turn < steps.length) {
        const [name, arguments_] = steps[turn++];
        content=[{type:"toolCall",id:"browser-smoke-"+turn,name,arguments:arguments_}]; stopReason="toolUse";
      } else {
        if (!pi.getAllTools().some(t=>t.name==="web_search" && t.parameters.properties.queries)) throw new Error("web-access search replaced");
        content=[{type:"text",text:"PI_BROWSER_SMOKE_OK"}]; stopReason="stop";
      }
      const message={role:"assistant",provider:model.provider,api:model.api,model:model.id,content,stopReason,timestamp:Date.now(),usage:{input:1,output:1,cacheRead:0,cacheWrite:0,totalTokens:2,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}}};
      queueMicrotask(()=>{stream.push({type:"done",reason:stopReason,message});stream.end(message);}); return stream;
    }
  });
}
'''.replace("url:URL", "url:" + json.dumps(url)))
    try:
        result = subprocess.run([binary, "--mode", "json", "--offline", "--no-session", "--no-mcp", "--no-context-files", "--no-skills", "--no-prompt-templates", "--no-themes", "--no-approve", "-e", str(fixture), "--provider", "browser-smoke", "--model", "stub", "--thinking", "off", "-p", "Local browser regression"], cwd=base, env=env, capture_output=True, text=True, timeout=150)
        if result.returncode or result.stderr or "PI_BROWSER_SMOKE_OK" not in result.stdout:
            raise RuntimeError(f"Browser smoke failed ({result.returncode}): {result.stderr}\n{result.stdout[-12000:]}")
        print("PASS: wrapper MCP subcommands, native Pi browser launch/snapshot/JPEG/close and web-access coexistence; local deterministic provider only")
    finally:
        server.shutdown()
        server.server_close()
