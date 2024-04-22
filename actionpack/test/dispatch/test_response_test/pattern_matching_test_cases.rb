# frozen_string_literal: true

module TestResponseTest::PatternMatchingTestCases
  extend ActiveSupport::Concern

  included do
    test "JSON response Hash pattern matching" do
      response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "application/json" }, '{ "foo": "fighters" }')

      assert_pattern { response.parsed_body => { foo: /fighter/ } }
    end

    test "JSON response Array pattern matching" do
      response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "application/json" }, '[{ "foo": "fighters" }, { "nir": "vana" }]')
      assert_pattern { response.parsed_body => [{ foo: /fighter/ }, { nir: /vana/ }] }
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

      html.at("main") => {name:, content:}

      assert_equal "main", name
      assert_equal "Some main content", content

      assert_pattern { html.at("main") => { content: "Some main content" } }
      assert_pattern { html.at("main") => { content: /content/ } }
      assert_pattern { html.at("main") => { children: [{ name: "h1", content: /content/ }] } }
    end
  end
end
