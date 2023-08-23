# frozen_string_literal: true

module TestResponseTest::PatternMatchingTestCases
  extend ActiveSupport::Concern

  included do
    test "JSON response Hash pattern matching" do
      response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "application/json" }, '{ "foo": "fighters" }')

      # rubocop:disable Lint/Syntax
      assert_pattern { response.parsed_body => { foo: /fighter/ } }
      # rubocop:enable Lint/Syntax
    end

    test "JSON response Array pattern matching" do
      response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "application/json" }, '[{ "foo": "fighters" }, { "nir": "vana" }]')
      # rubocop:disable Lint/Syntax
      assert_pattern { response.parsed_body => [{ foo: /fighter/ }, { nir: /vana/ }] }
      # rubocop:enable Lint/Syntax
    end

    test "HTML response pattern matching" do
      response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "text/html" }, <<~HTML)
        <html>
          <head></head>
          <body>
            <main><h1>Some main content</h1></main>
          </body>
        </html>
      HTML
      html = response.parsed_body

      # rubocop:disable Lint/Syntax
      html.at("main") => {name:, content:}
      # rubocop:enable Lint/Syntax

      assert_equal "main", name
      assert_equal "Some main content", content

      # rubocop:disable Lint/Syntax
      assert_pattern { html.at("main") => { content: "Some main content" } }
      assert_pattern { html.at("main") => { content: /content/ } }
      assert_pattern { html.at("main") => { children: [{ name: "h1", content: /content/ }] } }
      # rubocop:enable Lint/Syntax
    end
  end
end
