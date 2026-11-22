import fs from "node:fs";
import path from "node:path";

const root = process.argv[2];
const read = (file) => JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
const flatten = (entries) => entries.flatMap((entry) => [entry, ...flatten(entry.skins || [])]);
const english = flatten(read("en/data.json"));
const japanese = new Map(flatten(read("ja/data.json")).map((entry) => [entry.hexcode, entry]));
const presets = [read("en/shortcodes/github.json"), read("en/shortcodes/emojibase.json")];
const unique = (values) => [...new Set(values.filter(Boolean))];

const entries = english.map((entry) => {
    const ja = japanese.get(entry.hexcode);
    const aliases = unique(presets.flatMap((preset) => preset[entry.hexcode] || []));
    const labels = unique([entry.label, ja?.label]);
    const keywords = unique([...(entry.tags || []), ...(ja?.tags || [])]);
    return {
        emoji: entry.emoji,
        name: ja ? `${ja.label} / ${entry.label}` : entry.label,
        aliases,
        labels: labels.map((label) => label.toLowerCase()),
        search: [...labels, ...aliases, ...keywords].join(" ").toLowerCase(),
        comment: [...aliases.map((alias) => `:${alias}:`), ...keywords].join(" "),
    };
});
process.stdout.write(`// Generated from emojibase-data; see emoji-launcher.nix for the pinned source.\nvar EMOJIS = ${JSON.stringify(entries)};\n\n`);
