---
title: "OpenCode Serverで実現するRails LLM統合 - 特定ライブラリに依存しないAI活用術"
emoji: "🤖"
type: "tech"
topics: ["rails", "ruby", "opencode", "llm", "ai"]
published: false
---

## はじめに

RubyやRailsでLLM（大規模言語モデル）を活用したい。でも、PythonやTypeScriptに比べるとAI関連のライブラリが少ない...そんな悩みを持っている方も多いのではないでしょうか。

今回紹介する**OpenCode Server**を使えば、特定のライブラリに依存せずにLLMを活用できます。しかも、Grokなら無料で始められます！

## OpenCode Serverとは

[OpenCode](https://opencode.ai/docs/server/)は、オープンソースのAIコーディングエージェントです。その中の**Server機能**を使うと、HTTP API経由でLLMとやり取りできます。

### 特徴

- **75以上のLLMプロバイダーに対応**：OpenAI、Anthropic、Gemini、Grokなど
- **OpenAI互換API**：既存のOpenAI互換クライアントがそのまま使える
- **OpenAPI仕様**：`/doc`エンドポイントでSwagger UIから確認可能
- **言語非依存**：HTTP経由なのでどの言語からでも利用可能

## なぜRailsでOpenCodeを使うのか

### Rubyの現状

正直なところ、RubyはPythonやTypeScriptに比べてAI/ML関連のエコシステムが弱いです：

- **Python**：LangChain、LlamaIndex、OpenAI SDKなど充実
- **TypeScript**：Vercel AI SDK、LangChain.jsなど活発
- **Ruby**：...公式SDKが少ない、コミュニティライブラリの更新が遅いことも

### OpenCodeで解決できること

OpenCode Serverを中間層として使うことで：

1. **ライブラリ依存からの解放** - HTTP通信だけでLLMが使える
2. **プロバイダー切り替えが容易** - 設定変更だけで別のLLMに乗り換え可能
3. **Rubyの強みを活かせる** - Web開発はRailsで、AI部分はOpenCodeに任せる

```
[Rails App] --HTTP--> [OpenCode Server] ---> [LLM Provider]
                                              (OpenAI, Grok, etc.)
```

## 環境構築

### 1. OpenCodeのインストール

```bash
# Homebrew (macOS/Linux)
brew install opencode

# npm
npm install -g opencode
```

### 2. OpenCode Serverの起動

```bash
# サーバーモードで起動
opencode serve --port 4096

# または TUI と一緒に起動してポート指定
opencode --port 4096
```

起動後、`http://localhost:4096/doc` でOpenAPI仕様を確認できます。

### 3. Grokの設定（無料で使える！）

Grokは[xAI Console](https://console.x.ai/)でAPIキーを取得できます。

**データ共有にオプトインすると、毎月$150分の無料クレジットがもらえます！**

:::message
注意：データ共有に同意すると、やり取りの内容がxAIの分析に使われます。商用利用の場合は別アカウントを検討してください。
:::

OpenCodeの設定ファイル（`~/.opencode/config.json`）に追加：

```json
{
  "providers": {
    "xai": {
      "apiKey": "your-xai-api-key"
    }
  },
  "model": "xai/grok-3"
}
```

## Railsでの実装

### 基本的なLLMクライアント

```ruby
# app/services/llm_client.rb
class LlmClient
  OPENCODE_URL = ENV.fetch('OPENCODE_URL', 'http://localhost:4096')

  def initialize
    @conn = Faraday.new(url: OPENCODE_URL) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def chat(messages:, model: nil)
    response = @conn.post('/chat/completions') do |req|
      req.body = {
        messages: messages,
        model: model
      }.compact
    end

    response.body
  end

  def simple_ask(question)
    chat(messages: [{ role: 'user', content: question }])
  end
end
```

### Controllerでの利用

```ruby
# app/controllers/ai_controller.rb
class AiController < ApplicationController
  def ask
    client = LlmClient.new
    result = client.simple_ask(params[:question])

    render json: {
      answer: result.dig('choices', 0, 'message', 'content')
    }
  end
end
```

### Active Jobでバックグラウンド処理

LLMの応答は時間がかかることがあるので、Active Jobと組み合わせると良いでしょう：

```ruby
# app/jobs/llm_process_job.rb
class LlmProcessJob < ApplicationJob
  queue_as :default

  def perform(prompt:, callback_url:)
    client = LlmClient.new
    result = client.simple_ask(prompt)

    # 結果をコールバック or DBに保存
    LlmResult.create!(
      prompt: prompt,
      response: result.dig('choices', 0, 'message', 'content')
    )
  end
end
```

### ストリーミング対応

リアルタイムで応答を表示したい場合：

```ruby
# app/services/llm_streaming_client.rb
class LlmStreamingClient
  include ActionController::Live

  def stream_chat(messages:, &block)
    uri = URI("#{OPENCODE_URL}/chat/completions")

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        messages: messages,
        stream: true
      }.to_json

      http.request(request) do |response|
        response.read_body do |chunk|
          yield chunk if block_given?
        end
      end
    end
  end
end
```

## 実践的なユースケース

### 1. 商品説明の自動生成

```ruby
# app/services/product_description_generator.rb
class ProductDescriptionGenerator
  def generate(product)
    client = LlmClient.new

    prompt = <<~PROMPT
      以下の商品情報をもとに、魅力的な商品説明を200文字程度で生成してください。

      商品名: #{product.name}
      カテゴリ: #{product.category}
      特徴: #{product.features.join(', ')}
    PROMPT

    result = client.simple_ask(prompt)
    result.dig('choices', 0, 'message', 'content')
  end
end
```

### 2. カスタマーサポートの自動応答

```ruby
# app/services/support_assistant.rb
class SupportAssistant
  SYSTEM_PROMPT = <<~PROMPT
    あなたは親切なカスタマーサポート担当です。
    以下のFAQを参考に回答してください。
    わからない場合は「担当者にお繋ぎします」と回答してください。
  PROMPT

  def respond(user_message, faq_context)
    client = LlmClient.new

    client.chat(messages: [
      { role: 'system', content: "#{SYSTEM_PROMPT}\n\nFAQ:\n#{faq_context}" },
      { role: 'user', content: user_message }
    ])
  end
end
```

### 3. コードレビューアシスタント

```ruby
# app/services/code_reviewer.rb
class CodeReviewer
  def review(code, language: 'ruby')
    client = LlmClient.new

    prompt = <<~PROMPT
      以下の#{language}コードをレビューしてください。
      改善点があれば具体的に指摘してください。

      ```#{language}
      #{code}
      ```
    PROMPT

    client.simple_ask(prompt)
  end
end
```

## プロバイダーの切り替え

OpenCodeの最大の利点は、設定ファイルを変更するだけでLLMプロバイダーを切り替えられることです。

```json
// Grok を使う場合
{ "model": "xai/grok-3" }

// OpenAI を使う場合
{ "model": "openai/gpt-4" }

// Anthropic を使う場合
{ "model": "anthropic/claude-3-5-sonnet" }

// ローカルLLM（LM Studio経由）を使う場合
{
  "providers": {
    "lmstudio": {
      "baseURL": "http://localhost:1234/v1"
    }
  },
  "model": "lmstudio/local-model"
}
```

**Railsアプリのコードは一切変更不要！**

## テスト

```ruby
# spec/services/llm_client_spec.rb
RSpec.describe LlmClient do
  describe '#simple_ask' do
    it 'returns a response from the LLM' do
      # OpenCodeのモックサーバーを使うか、WebMockでスタブ
      stub_request(:post, "http://localhost:4096/chat/completions")
        .to_return(
          status: 200,
          body: {
            choices: [{ message: { content: 'Hello!' } }]
          }.to_json
        )

      client = LlmClient.new
      result = client.simple_ask('Say hello')

      expect(result.dig('choices', 0, 'message', 'content')).to eq('Hello!')
    end
  end
end
```

## まとめ

OpenCode Serverを使うことで：

- **ライブラリに依存しない** - HTTP通信だけでLLMが使える
- **プロバイダーを自由に選べる** - Grok（無料）からOpenAI、Anthropicまで
- **Railsの強みを活かせる** - Web開発はRailsで、AI部分はOpenCodeに委譲

RubyのAIエコシステムが弱いからといって諦める必要はありません。OpenCodeという「翻訳層」を挟むことで、どの言語からでもLLMを活用できます。

特にGrokの無料クレジット（月$150）を活用すれば、コストを抑えながらAI機能を試せます。ぜひ試してみてください！

## 参考リンク

- [OpenCode Server ドキュメント](https://opencode.ai/docs/server/)
- [OpenCode SDK](https://opencode.ai/docs/sdk/)
- [OpenCode プロバイダー設定](https://opencode.ai/docs/providers/)
- [xAI Console（Grok API）](https://console.x.ai/)
- [Grok API 無料クレジットの使い方](https://zenn.dev/sunwood_ai_labs/articles/trying-grok-api-free-credit)
