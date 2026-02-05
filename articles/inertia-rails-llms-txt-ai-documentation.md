---
title: "Tailwindが拒否したllms.txtをInertia Railsは採用した。AI時代のドキュメント戦略の分岐点"
emoji: "🤖"
type: "tech"
topics: ["InertiaJS", "Rails", "llmstxt", "AI", "ドキュメント"]
published: true
---

## はじめに

最近、AI（LLM）を使った開発が当たり前になってきた。CursorやClaude Code、GitHub Copilotなど、AIアシスタントがコードを書く時代。そんな中、**ドキュメントをAIにどう読ませるか**という問題が浮上している。

そこで登場したのが **`llms.txt`** という提案。そして、このファイルをめぐって、OSSコミュニティで大きな分岐が起きた。

**Tailwind CSSは拒否した。Inertia Railsは採用した。**

この記事では、`llms.txt` とは何か、なぜTailwindは拒否し、Inertia Railsは採用したのか、そして実際に使ってみてどれだけ便利なのかを語る。

## llms.txt とは？

2024年9月、Answer.AIの共同創設者であるJeremy Howardが提唱した仕様。

ざっくり言うと、**Webサイトのドキュメントをマークダウン形式でLLMに提供するための標準ファイル**だ。

### 従来の問題

- LLMがWebサイトを読む際、HTMLのナビゲーション、広告、JavaScriptなどのノイズが大量に含まれる
- コンテキストウィンドウは有限なので、ノイズが多いと肝心な情報が入りきらない
- `sitemap.xml` はページ一覧を提供するが、コンテンツの処理は助けてくれない
- `robots.txt` はアクセス制御であって、LLM向けの最適化ではない

### llms.txt の構成

```
/llms.txt       → ドキュメントの概要・ナビゲーション（軽量版）
/llms-full.txt  → 全ドキュメントを1ファイルにまとめたフル版
```

HTMLではなくMarkdownで提供することで、**トークン消費量を90%以上削減**できる。LLMにとっては、整理されたMarkdownの方がはるかに理解しやすい。

## Tailwind CSSの決断：llms.txtを拒否

2025年11月、あるデベロッパーがTailwind CSSのドキュメントサイトに `llms.txt` エンドポイントを追加するPRを出した。185個のドキュメントファイルを1つのテキストファイルに結合し、AIパース用に最適化するという提案だった。

約2ヶ月間、PRは放置された。コメント欄には「なぜマージしないのか」という声が溢れた。

そして、**Tailwind Labsがエンジニアリングチームの75%をレイオフした翌日**、創設者のAdam Wathanがこのように述べてPRをクローズした：

> "And making it easier for LLMs to read our docs just means less traffic to our docs which means less people learning about our paid products and the business being even less sustainable."
>
> （LLMがドキュメントを簡単に読めるようにするということは、ドキュメントへのトラフィックが減り、有料プロダクトを知る人が減り、ビジネスがさらに持続不可能になるということだ）

### Tailwindの苦しい事情

- ドキュメントサイトのトラフィックが、有料プロダクト（Tailwind UI等）への導線
- LLMの普及で開発者がドキュメントサイトを訪問せずにコードを生成するようになった
- 収益が80%減少し、大量レイオフに至った

この決断には賛否両論あった。だが皮肉なことに、**llms.txtがなくてもAIはWebクロールでドキュメントにアクセスできる**。公式のllms.txtを提供しないことが、本当にトラフィック維持につながるのかは疑問が残る。

## Inertia Railsの決断：llms.txtを採用

一方、**Inertia Rails**（https://inertia-rails.dev）は正反対のアプローチをとった。

Inertia Railsは、React・Vue・SvelteのSPAをRailsのサーバーサイドルーティングで開発できるフレームワーク。APIを書かずにモダンなフロントエンドが作れる、Railsデベロッパーにとって非常に魅力的な選択肢だ。

そして、このInertia Railsのドキュメントサイトには、**堂々と`llms.txt`と`llms-full.txt`が用意されている**。

```
https://inertia-rails.dev/llms.txt       → 概要版
https://inertia-rails.dev/llms-full.txt  → フルドキュメント版
```

さらに、個別のページにもMarkdown版が用意されている：

```
/guide/the-protocol.md
/guide/server-side-setup.md
/guide/upgrade-guide.md
```

トップページには「Are you an LLM?」と表示され、LLM向けのドキュメントへの導線が明確に示されている。

### v3.10.0で正式対応

Inertia Railsはv3.10.0で `llms-full.txt` の動的生成機能を追加。JSの例も含めるように修正され、**公式機能としてLLM対応が組み込まれた**。

## 実際に使ってみた：これがマジで便利

ここからが本題。**実際にInertia Railsのllms.txtを使ってみると、開発体験が劇的に変わる**。

### Before：llms.txtなしの世界

1. Inertia Railsの使い方を調べたい
2. ドキュメントサイトを開く
3. 該当ページを探す
4. HTMLからコード例を目視で拾う
5. AIに聞いても、古い情報や不正確な回答が返ってくる

### After：llms.txtありの世界

1. AIツール（Cursor、Claude Code等）にllms.txtのURLを渡す
2. AIが最新の公式ドキュメントを正確に理解する
3. 的確なコード例とベストプラクティスが返ってくる
4. **これだけで開発が進む**

例えばClaude Codeなら、こんな感じ：

```
「Inertia Railsでフォーム送信を実装したい。
https://inertia-rails.dev/llms-full.txt を参考にして」
```

これだけで、最新のAPIに基づいた正確な実装が手に入る。ドキュメントサイトを行ったり来たりする必要がない。

### MCPサーバーとの連携

LangChainが開発した `mcpdoc` というMCPサーバーを使えば、CursorやClaude Codeのようなツールから直接llms.txtにアクセスできる。IDEの中で完結する開発フローが実現する。

## OSSドキュメント戦略の分岐点

Tailwindの決断もInertia Railsの決断も、それぞれの事情がある。しかし、大きな流れとして見ると：

| プロジェクト | llms.txt | 方針 |
|---|---|---|
| Tailwind CSS | 拒否 | ドキュメントトラフィック = 収益導線 |
| Inertia Rails | 採用 | AI時代のデベロッパー体験を最優先 |
| Nuxt (Vercel傘下) | 採用 | Nuxt UI Proを無料化し、AI対応を全面推進 |
| LangChain | 採用 | MCP連携でIDEから直接アクセス可能に |
| Mintlify | 自動生成 | ホスティングサービスとして標準対応 |

**AI時代において、ドキュメントは「人が読むもの」から「人とAIが読むもの」に変わった**。その現実に対応するかどうかが、OSSプロジェクトの開発者体験を大きく左右する時代になっている。

## まとめ：llms.txtがあるライブラリは強い

正直に言う。**llms.txtがあるだけで、そのライブラリの採用ハードルがめちゃくちゃ下がる**。

AIに「このドキュメント読んで」とURLを投げるだけで、セットアップから実装まで一気に進められる。ドキュメントを読む時間が減るわけじゃない——**ドキュメントをAIが正確に読んでくれるようになる**のだ。

Inertia Railsを使いたいなら、まずはこのURLをAIに投げてみてほしい：

```
https://inertia-rails.dev/llms.txt
```

**これ読んだらいける。マジでいける。**

Tailwindの判断は、ビジネス的には理解できる。しかし、開発者としては、llms.txtを提供してくれるプロジェクトの方が圧倒的に使いやすい。AI時代のドキュメント戦略として、Inertia Railsの選択は正しいと思う。

ライブラリ選定の新しい基準：**「llms.txt、ある？」**

## 参考リンク

- [llms.txt 仕様](https://llmstxt.org/)
- [Inertia Rails 公式サイト](https://inertia-rails.dev/)
- [Inertia Rails llms.txt](https://inertia-rails.dev/llms.txt)
- [Inertia Rails llms-full.txt](https://inertia-rails.dev/llms-full.txt)
- [Tailwind CSS llms.txt PR (Closed)](https://github.com/tailwindlabs/tailwindcss.com/issues/2424)
- [Inertia Rails GitHub](https://github.com/inertiajs/inertia-rails)
