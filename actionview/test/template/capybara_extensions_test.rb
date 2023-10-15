# frozen_string_literal: true

require "capybara/minitest"
require "rails/testing/capybara_extensions"
require "abstract_unit"

Rails::Testing::CapybaraExtensions.install :element

class CapybaraExtensionsTest < ActionView::TestCase
  include Capybara::Minitest::Assertions

  test "data: filter handles nested data: keys" do
    render inline: <<~ERB
      <%= tag.div data: { key: "value" } %>
    ERB

    assert_selector :element, "data-key": "value"
    assert_selector :element, data: { key: "value" }
    assert_raises Minitest::Assertion, match: %(attributes[data-key => value]) do
      assert_no_selector :element, data: { key: "value" }
    end
  end

  test "data: filter handles nested data: snake_case keys" do
    render inline: <<~ERB
      <%= tag.div data: { nested_key: "value" } %>
    ERB

    assert_selector :element, "data-nested-key": "value"
    assert_selector :element, data: { nested_key: "value" }
    assert_raises Minitest::Assertion, match: %(attributes[data-nested-key => value]) do
      assert_no_selector :element, data: { nested_key: "value" }
    end
  end

  test "data: filter handles nested data: JSON Hash values" do
    json = { a: true, b: false }

    render inline: <<~ERB, locals: { json: json }
      <%= tag.div data: { json: json } %>
    ERB

    assert_selector :element, "data-json": json.to_json
    assert_selector :element, data: { json: json }
    assert_raises Minitest::Assertion, match: %(attributes[data-json => #{json.to_json}]) do
      assert_no_selector :element, data: { json: json }
    end
  end

  test "data: filter handles nested data: JSON Array values" do
    json = [{ a: true }, { b: false }]

    render inline: <<~ERB, locals: { json: json }
      <%= tag.div data: { json: json } %>
    ERB

    assert_selector :element, "data-json": json.to_json
    assert_selector :element, data: { json: json }
    assert_raises Minitest::Assertion, match: %(attributes[data-json => #{json.to_json}]) do
      assert_no_selector :element, data: { json: json }
    end
  end

  test "aria: filter handles nested aria: keys" do
    render inline: <<~ERB
      <%= tag.div aria: { labelledby: "value" } %>
    ERB

    assert_selector :element, "aria-labelledby": "value"
    assert_selector :element, aria: { labelledby: "value" }
    assert_raises Minitest::Assertion, match: %(attributes[aria-labelledby => value]) do
      assert_no_selector :element, aria: { labelledby: "value" }
    end
  end

  test "aria: filter handles nested aria: Array values" do
    tokens = ["one", "two"]
    token_list = tokens.join(" ")

    render inline: <<~ERB, locals: { tokens: tokens }
      <%= tag.div aria: { labelledby: tokens } %>
    ERB

    assert_selector :element, "aria-labelledby": token_list
    assert_selector :element, aria: { labelledby: tokens }
    assert_raises Minitest::Assertion, match: %(attributes[aria-labelledby => #{token_list}]) do
      assert_no_selector :element, aria: { labelledby: tokens }
    end
  end

  def page
    Capybara.string(document_root_element)
  end
end
