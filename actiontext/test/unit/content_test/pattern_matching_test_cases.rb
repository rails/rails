# frozen_string_literal: true

class ActionText::PatternMatchingTestCases < ActiveSupport::TestCase
  test "delegates pattern matching to Nokogiri" do
    content = ActionText::Content.new <<~HTML
      <h1 id="hello-world">Hello, world</h1>

      <div>The body</div>
    HTML

    # rubocop:disable Lint/Syntax
    content => [h1, div]

    assert_pattern { h1 => { name: "h1", content: "Hello, world", attributes: [{ name: "id", value: "hello-world" }] } }
    refute_pattern { h1 => { name: "h1", content: "Goodbye, world" } }
    assert_pattern { div => { content: "The body" } }
    # rubocop:enable Lint/Syntax
  end
end
