# frozen_string_literal: true

class ActionView::PatternMatchingTestCases < ActionView::TestCase
  test "document_root_element integrates with pattern matching" do
    developer = DeveloperStruct.new("Eloy")

    render "developers/developer_with_h1", developer: developer

    # rubocop:disable Lint/Syntax
    assert_pattern { document_root_element.at("h1") => { content: "Eloy", attributes: [{ name: "id", value: "name" }] } }
    refute_pattern { document_root_element.at("h1") => { content: "Not Eloy" } }
  end

  test "rendered.html integrates with pattern matching" do
    developer = DeveloperStruct.new("Eloy")

    render "developers/developer", developer: developer

    # rubocop:disable Lint/Syntax
    assert_pattern { rendered.html => { content: "Eloy" } }
    refute_pattern { rendered.html => { content: "Not Eloy" } }
    # rubocop:enable Lint/Syntax
  end

  test "rendered.json integrates with pattern matching" do
    developer = DeveloperStruct.new("Eloy")

    render formats: :json, partial: "developers/developer", locals: { developer: developer }

    # rubocop:disable Lint/Syntax
    assert_pattern { rendered.json => { name: "Eloy" } }
    refute_pattern { rendered.json => { name: "Not Eloy" } }
    # rubocop:enable Lint/Syntax
  end
end
