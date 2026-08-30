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
        coder = JSON.new(decode_options: { symbolize_names: true })
        assert_equal({ foo: "bar" }, coder.load('{"foo":"bar"}'))
      end

      def test_dump_does_not_html_escape
        coder = JSON.new
        assert_equal '{"k":"<>&"}', coder.dump({ "k" => "<>&" })
      end

      def test_dump_with_encode_options
        coder = JSON.new(encode_options: { escape: true })
        assert_equal '{"k":"\\u003c\\u003e\\u0026"}', coder.dump({ "k" => "<>&" })
      end
    end
  end
end
