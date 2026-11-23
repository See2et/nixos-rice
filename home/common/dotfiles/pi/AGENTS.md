# Git worktree 運用

- ghq の元 checkout は参照用とし、変更・テスト・依存導入は作業 worktree で行う。既存の変更や稼働セッションを勝手に移動・削除しない。
- 作業先は `~/worktrees/<host>/<owner>/<repo>/<作業名>`。配置・ブランチはパスから推測せず `git worktree list --porcelain` で確認する。`.git/worktrees` は Git の管理領域なので作業ファイルを置かない。
- Pi 内の作成・切替は `/worktree` を使う。作成画面で上記の絶対パスと起点を明示し、確定 commit を確認する（標準候補は repo 名だけの配置・現在ブランチ起点）。起点はプロジェクト規約を優先し、不明なら確認する。Ajiro は `origin/develop`。
- 元 checkout の更新は、ローカル変更・未追跡ファイル・進行中の Git 操作がないことを確認して fetch と fast-forward のみ。分岐・取得失敗なら止め、自動 stash・reset・rebase はしない。確認できた commit を「最新」の根拠とし、作業 worktree は勝手に更新しない。
- 再開・切替後と最初の変更前に、Pi の `ctx.cwd`（利用できる場合）、bash の `pwd`、Git の top-level・common-dir・branch を対象と照合し、作業先を伝える。不一致・削除・別 repo・意図しない branch なら変更せず止める。別の checkout への自動フォールバックは禁止。
- bash の `cd` だけでは Pi の作業先は変わらない。`pi --session` は保存済み cwd を復元する。別 worktree へ会話を引き継ぐときは `/worktree` の切替か、元 Pi を終了して対象ディレクトリから `pi --fork <session>` を使う。切替後はプロジェクト規約・Mentor の対象も確認し、factory の実行権限・所有者は自動移管しない。
- worktree の移動・削除は Git 経由。削除前に別セッション・子プロセス・factory が使っていないことと、未コミット・未追跡・ignored ファイルを確認する。セッションや成果物の自動削除はしない。
- これらは運用規約であり、Extension による書込み隔離・対象監視・排他制御を保証しない。
