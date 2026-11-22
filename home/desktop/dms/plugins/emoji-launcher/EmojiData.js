// emoji-launcher.nix prepends the generated Emojibase catalog at build time.
function getItems(query) {
    const needle = (query || "").trim().toLowerCase().replace(/^:+|:+$/g, "")
    const matches = []
    for (let i = 0; i < EMOJIS.length; i++) {
        const entry = EMOJIS[i]
        let rank = 3
        if (needle) {
            if (entry.emoji === needle || entry.aliases.indexOf(needle) !== -1 || entry.labels.indexOf(needle) !== -1) {
                rank = 0
            } else if (entry.aliases.some(alias => alias.indexOf(needle) === 0)) {
                rank = 1
            } else if (entry.search.indexOf(needle) !== -1) {
                rank = 2
            } else {
                continue
            }
        }
        matches.push({ entry: entry, rank: rank, order: i })
    }
    matches.sort((a, b) => a.rank - b.rank || a.order - b.order)
    return matches.map(match => ({
        emoji: match.entry.emoji,
        name: match.entry.name,
        icon: "unicode:" + match.entry.emoji,
        comment: match.entry.comment,
        action: "copy:" + match.entry.emoji,
        categories: ["EmojiLauncher"]
    }))
}
