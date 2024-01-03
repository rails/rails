# frozen_string_literal: true

require "abstract_unit"

class TestResponseTest < ActiveSupport::TestCase
  def assert_response_code_range(range, predicate)
    response = ActionDispatch::TestResponse.new
    (0..599).each do |status|
      response.status = status
      assert_equal range.include?(status), response.send(predicate),
                   "ActionDispatch::TestResponse.new(#{status}).#{predicate}"
    end
  end

  test "helpers" do
    assert_response_code_range 200..299, :successful?
    assert_response_code_range [404],    :not_found?
    assert_response_code_range 300..399, :redirection?
    assert_response_code_range 500..599, :server_error?
    assert_response_code_range 400..499, :client_error?
  end

  test "response parsing" do
    response = ActionDispatch::TestResponse.create(200, {}, "")
    assert_equal response.body, response.parsed_body

    response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "application/json" }, '{ "foo": "fighters" }')
    assert_kind_of ActiveSupport::HashWithIndifferentAccess, response.parsed_body
    assert_equal({ "foo" => "fighters" }, response.parsed_body)

    response = ActionDispatch::TestResponse.create(200, { "Content-Type" => "text/html" }, <<~HTML)
      <html>
        <head></head>
        <body>
          <div>Content</div>
        </body>
      </html>
    HTML
    assert_kind_of(Nokogiri::XML::Document, response.parsed_body)
    assert_equal("Content", response.parsed_body.at_xpath("/html/body/div").text)
  end

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
