import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const plugin = process.argv[2];
assert(plugin, "Pass the built plugin directory (nix build .#checks.x86_64-linux.dms-emoji-launcher)");
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(plugin, "EmojiData.js"), "utf8"), context);
const search = (query) => context.getItems(query);

for (const [query, emoji] of [
    ["eyes", "👀"],
    [":eyes:", "👀"],
    ["tada", "🎉"],
    [":tada:", "🎉"],
    [" EYES: ", "👀"],
    ["クラッカー", "🎉"],
    ["👀", "👀"],
]) {
    const first = search(query)[0];
    assert.equal(first?.emoji, emoji, `${query} should rank ${emoji} first`);
    assert.equal(first.action, `copy:${emoji}`);
    assert.equal(first.icon, `unicode:${emoji}`);
}
assert(search("party popper").some((item) => item.emoji === "🎉"));
assert(search("お祝い").some((item) => item.emoji === "🎉"));
assert(search("thumbsup").some((item) => item.emoji === "👍"));
assert(search("👍🏽").some((item) => item.emoji === "👍🏽"));
assert.equal(search("no-such-emoji-xyz").length, 0);
const all = search("");
assert(all.length > 3000, "use the full dataset, not the old curated list");
assert.equal(new Set(all.map((item) => item.emoji)).size, all.length);
console.log(`Emoji Launcher: search and copy contracts passed (${all.length} entries)`);
