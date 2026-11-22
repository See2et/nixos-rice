{ pkgs }:
let
  emojibaseData = pkgs.fetchzip {
    url = "https://registry.npmjs.org/emojibase-data/-/emojibase-data-18.0.0.tgz";
    hash = "sha256-1TAaNEpUMXRMyGfcndI3paPP2kGlHA8XUEnLGG0pVz4=";
  };
in
pkgs.runCommand "dms-emoji-launcher"
  {
    nativeBuildInputs = [ pkgs.nodejs ];
  }
  ''
    mkdir -p "$out"
    cp ${./plugins/emoji-launcher}/{EmojiLauncher.qml,plugin.json} "$out/"
    cp ${emojibaseData}/LICENSE "$out/LICENSE-emojibase"
    node ${./generate-emoji-data.mjs} ${emojibaseData} > "$out/EmojiData.js"
    cat ${./plugins/emoji-launcher/EmojiData.js} >> "$out/EmojiData.js"
    node ${../../../tests/dms-emoji-launcher.mjs} "$out"
  ''
