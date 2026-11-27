# frozen_string_literal: true

require "abstract_unit"

class StrictLocalsParserTest < ActiveSupport::TestCase
  Parser = ActionView::Template::StrictLocalsParser

  def test_extract_removes_the_declaration_from_the_source
    source = +"<%# locals: (message: 'Hello'  ) -%>\n<%= message %>"

    assert_equal "message: 'Hello'", Parser.extract!(source)
    assert_equal "<% -%>\n<%= message %>", source
  end

  def test_extract_leaves_source_without_a_declaration_unchanged
    source = +"<%= message %>"

    assert_nil Parser.extract!(source)
    assert_equal "<%= message %>", source
  end

  def test_extract_treats_an_empty_declaration_as_no_keywords
    assert_equal "**nil", Parser.extract!(+"<%# locals: () -%>")
  end

  def test_extract_uses_the_default_external_encoding_for_binary_source
    source = "<%# locals: (message:) -%>".b

    assert_equal Encoding.default_external, Parser.extract!(source).encoding
  end

  def test_extract_preserves_parentheses_in_defaults
    ["(Hello)", "(Hello", "Hello)"].each do |value|
      arguments = "message: '#{value}'"

      assert_equal arguments, Parser.extract!("<%# locals: (#{arguments}) -%>")
    end
  end

  def test_extract_accepts_a_multiline_declaration
    arguments = "arg_1:,\n             arg_2: nil,\n             arg_3: []"

    assert_equal arguments, Parser.extract!("<%# locals: (#{arguments}) -%>")
  end

  def test_extract_accepts_a_closing_parenthesis_on_a_separate_line
    arguments = "\n  arg_1:,\n  arg_2: nil,\n  arg_3: []"

    assert_equal arguments, Parser.extract!("<%# locals: (#{arguments}\n) -%>")
  end

  def test_block_parameter_is_absent_without_an_ampersand
    assert_not Parser.block_parameter?("message: nil")
  end

  def test_block_parameter_ignores_safe_navigation_in_a_default
    assert_not Parser.block_parameter?("name: nil, message: name&.upcase")
  end

  def test_block_parameter_detects_an_explicit_block_parameter
    assert Parser.block_parameter?("name: nil, message: name&.upcase, &_")
  end

  def test_block_parameter_respects_the_encoding_of_a_default
    arguments = "label: '\u{30bd}', &_".encode(Encoding::Windows_31J)

    assert Parser.block_parameter?(arguments)
  end
end
