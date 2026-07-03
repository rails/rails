# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module Coders
    class JSONTest < ActiveRecord::TestCase
      def test_returns_nil_if_empty_string_given
        coder = JSON.new
        assert_nil coder.load("")
      end

      def test_returns_nil_if_nil_given
        coder = JSON.new
        assert_nil coder.load(nil)
      end

      def test_coder_with_symbolize_names
        coder = JSON.new(symbolize_names: true)
        assert_equal({ foo: "bar" }, coder.load('{"foo":"bar"}'))
      end

      def test_dump_does_not_html_escape_by_default
        coder = JSON.new
        assert_equal({ "html" => "<b>a & b</b>" }, coder.load(coder.dump("html" => "<b>a & b</b>")))
        assert_equal '{"html":"<b>a & b</b>"}', coder.dump("html" => "<b>a & b</b>")
      end

      def test_dump_escapes_when_escape_option_is_true
        coder = JSON.new(escape: true)
        assert_equal '{"html":"\u003cb\u003ea \u0026 b\u003c/b\u003e"}', coder.dump("html" => "<b>a & b</b>")
      end
    end
  end
end
