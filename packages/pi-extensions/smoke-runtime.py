"""Exercise the actual built Pi CLI with local tools and no external inference/auth."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = sys.argv[1]
with tempfile.TemporaryDirectory(prefix="pi-tools-smoke-") as temporary:
    base = Path(temporary)
    agent = base / "agent"
    workspace = base / "workspace"
    agent.mkdir()
    workspace.mkdir()
    (agent / "settings.json").write_text(json.dumps({"defaultTools": ["+codemode"], "codemode": {"mode": "on"}, "retry": {"enabled": False}}))
    (workspace / ".pi-lsp.json").write_text(json.dumps({"autoStart": ["typescript"]}))
    (workspace / "fixture.ts").write_text("export const answer: number = 42;\nexport const doubled = answer * 2;\n")
    extension = base / "fixture-extension.ts"
    extension.write_text('''
import {createAssistantMessageEventStream} from "@earendil-works/pi-ai";
export default function(pi) {
  let turn = 0;
  pi.on("agent_settled", (_event,ctx)=>ctx.shutdown());
  pi.on("before_agent_start", () => {
    const tools=pi.getActiveTools();
    for (const name of ["codemode","lsp_hover","lsp_diagnostics","astraeus_workflow"]) {
      if (!tools.includes(name)) throw new Error("Missing active tool: " + name);
    }
    for (const name of ["usage","lsp"]) {
      if (!pi.getCommands().some(command=>command.name===name)) throw new Error("Missing command: " + name);
    }
  });
  pi.registerProvider("local-smoke", {
    api:"local-smoke-api", apiKey:"isolated-local-fixture", baseUrl:"http://invalid.local",
    models:[{id:"stub",name:"Local deterministic fixture",reasoning:false,input:["text"],cost:{input:0,output:0,cacheRead:0,cacheWrite:0},contextWindow:32000,maxTokens:4000}],
    streamSimple:(model, context)=>{
      const stream=createAssistantMessageEventStream();
      let content,stopReason;
      if(turn++===0) {
        content=[{type:"toolCall",id:"local-codemode",name:"codemode",arguments:{code:
          'await tools.read({path:"fixture.ts"}); const d=await tools.lsp_diagnostics({path:"fixture.ts"}); const h=await tools.lsp_hover({path:"fixture.ts",line:2,character:25}); if(!String(h).includes("number") || String(h).includes("tree-sitter")) throw new Error("Actual language-server hover failed: " + h); text(d); text(h); text("LSP_NATIVE_OK");'
        }}]; stopReason="toolUse";
      } else {
        const output=JSON.stringify(context.messages.filter(message=>message.role!=="assistant"));
        if(!output.includes("LSP_NATIVE_OK")) throw new Error("CodeMode/LSP did not complete: " + output.slice(-2000));
        content=[{type:"text",text:"PI_TOOLS_SMOKE_OK"}];stopReason="stop";
      }
      const message={role:"assistant",provider:model.provider,api:model.api,model:model.id,content,stopReason,timestamp:Date.now(),usage:{input:1,output:1,cacheRead:0,cacheWrite:0,totalTokens:2,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}}};
      setTimeout(()=>{stream.push({type:"done",reason:stopReason,message});stream.end(message);},1500);return stream;
    }
  });
}
''')
    env = {"HOME": str(base), "PATH": "/nonexistent", "PI_CODING_AGENT_DIR": str(agent), "PI_OFFLINE": "1"}
    try:
        result = subprocess.run([binary, "--mode", "json", "--offline", "--no-context-files", "--no-session", "-e", str(extension), "--provider", "local-smoke", "--model", "stub", "--thinking", "off", "-p", "Local deterministic tool integration test"], cwd=workspace, env=env, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired as error:
        output=error.stdout.decode() if isinstance(error.stdout,bytes) else error.stdout or ""
        stderr=error.stderr.decode() if isinstance(error.stderr,bytes) else error.stderr or ""
        raise RuntimeError("Pi smoke timed out: " + stderr + "\n" + output[-4500:]) from error

    if result.returncode or result.stderr:
        raise RuntimeError(f"Pi smoke failed ({result.returncode}): {result.stderr}\n{result.stdout[-3000:]}")
    events = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    final = [event["message"] for event in events if event.get("type")=="message_end" and event.get("message",{}).get("role")=="assistant" and event["message"].get("stopReason")=="stop"]
    assert final and any(item.get("text")=="PI_TOOLS_SMOKE_OK" for item in final[-1]["content"]), result.stdout[-3000:]
    print("Actual Pi CodeMode -> TypeScript LSP hover, usage/LSP commands, and Astraeus coexistence: passed")
