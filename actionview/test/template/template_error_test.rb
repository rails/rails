# frozen_string_literal: true

require "abstract_unit"

class TemplateErrorTest < ActiveSupport::TestCase
  def test_provides_original_message
    error = begin
      raise Exception.new("original")
    rescue Exception
      raise ActionView::Template::Error.new("test") rescue $!
    end

    assert_equal "original", error.message
  end

  def test_provides_original_backtrace
    error = begin
      original_exception = Exception.new
      original_exception.set_backtrace(%W[ foo bar baz ])
      raise original_exception
    rescue Exception
      raise ActionView::Template::Error.new("test") rescue $!
    end

    assert_equal %W[ foo bar baz ], error.backtrace
  end

  def test_provides_useful_inspect
    error = begin
      raise Exception.new("original")
    rescue Exception
      raise ActionView::Template::Error.new("test") rescue $!
    end

    assert_equal "#<ActionView::Template::Error: original>", error.inspect
  end
end
